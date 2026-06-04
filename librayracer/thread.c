//
//  thread.c
//  librayracer
//
//  Created by Serge Tsyba on 25.4.2026.
//

#include "thread.h"
#include "tia.h"

#include <float.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static void update_field_rate(racer_thread *thread) {
	struct timespec current_time;
	clock_gettime(CLOCK_MONOTONIC, &current_time);

	// adding 1 guards against
	long seconds = current_time.tv_sec - thread->field_start_time.tv_sec;
	long nanoseconds = current_time.tv_nsec - thread->field_start_time.tv_nsec;
	long field_time = seconds * 1000000000 + nanoseconds;

	// fps = (α⋅time) + ((1-α)⋅time)
	// α = 0.1, smoothing factor
	thread->field_time *= 0.9;
	thread->field_time += 0.1 * (double)field_time;
}

static void sync_video(const void *output, racer_video_sync sync) {
	if (!(sync & (VIDEO_VERTICAL_SYNC | VIDEO_BUFFER_SYNC))) {
		// do nothing unless it's a vertical or buffer sync
		return;
	}

	racer_thread *thread = (racer_thread *)output;
	racer_thread_pause(thread);
	// update field rate
	update_field_rate(thread);

	// reset TIA video ooutput buffer
	thread->console->tia->video_buffer = thread->buffer;
	thread->console->tia->video_buffer_end = thread->buffer + thread->buffer_size;
}

static void await_resume(racer_thread *thread) {
	pthread_mutex_lock(&thread->mutex);
	while(atomic_load_explicit(&thread->state, memory_order_relaxed) == RACER_THREAD_PAUSED) {
		pthread_cond_wait(&thread->pause, &thread->mutex);
	}
	pthread_mutex_unlock(&thread->mutex);
}

static void * run_loop(void *data) {
	racer_thread *thread = (racer_thread *)data;
	while(true) {
		racer_thread_state state = atomic_load_explicit(&thread->state, memory_order_relaxed);
		switch (state) {
			case RACER_THREAD_RUNNING:
				racer_atari2600_advance_clock(thread->console);
				break;
			case RACER_THREAD_PAUSED:
				await_resume(thread);
				break;
			case RACER_THREAD_STOPPED:
				return NULL;
				break;
			default:
				break;
		}
	}
	return NULL;
}

racer_thread * racer_thread_create(racer_atari2600 *console, uint8_t *buffer, size_t buffer_size) {
	racer_thread *thread = malloc(sizeof(racer_thread));
	thread->buffer = buffer;
	thread->buffer_size = buffer_size;

	thread->console = console;
	thread->console->tia->video_output = thread;
	thread->console->tia->sync_video = sync_video;
	sync_video(thread, VIDEO_BUFFER_SYNC);

	thread->field_time = DBL_MIN;
	clock_gettime(CLOCK_MONOTONIC, &thread->field_start_time);

	atomic_store_explicit(&thread->state, RACER_THREAD_PAUSED, memory_order_relaxed);
	pthread_mutex_init(&thread->mutex, NULL);
	pthread_cond_init(&thread->pause, NULL);
	pthread_create(&thread->handle, NULL, run_loop, thread);

	return thread;
}

void racer_thread_destroy(racer_thread *thread) {
	// notify run loop to break
	atomic_store_explicit(&thread->state, RACER_THREAD_STOPPED, memory_order_relaxed);

	// wait for thread to stop and clean up resources
	pthread_join(thread->handle, NULL);
	pthread_mutex_destroy(&thread->mutex);
	pthread_cond_destroy(&thread->pause);
	free(thread);
}

void racer_thread_resume(racer_thread *thread) {
	atomic_store_explicit(&thread->state, RACER_THREAD_RUNNING, memory_order_relaxed);

	pthread_mutex_lock(&thread->mutex);
	struct timespec current_time;
	clock_gettime(CLOCK_MONOTONIC, &current_time);
	thread->field_start_time = current_time;

	pthread_cond_signal(&thread->pause);
	pthread_mutex_unlock(&thread->mutex);
}

void racer_thread_pause(racer_thread *thread) {
	atomic_store_explicit(&thread->state, RACER_THREAD_PAUSED, memory_order_relaxed);
}

bool racer_thread_is_paused(racer_thread *thread) {
	racer_thread state = atomic_load_explicit(&thread->state, memory_order_relaxed);
	return state == RACER_THREAD_PAUSED;
}

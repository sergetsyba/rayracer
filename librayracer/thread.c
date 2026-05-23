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

	// adding 1 guards agains
	long seconds = current_time.tv_sec - thread->field_start_time.tv_sec;
	long nanoseconds = current_time.tv_nsec - thread->field_start_time.tv_nsec;
	long field_time = seconds * 1000000000 + nanoseconds;

	// fps = (α⋅time) + ((1-α)⋅time)
	// α = 0.1, smoothing factor
	thread->field_time *= 0.9;
	thread->field_time += 0.1 * (double)field_time;
	thread->field_start_time = current_time;
}

static inline void advance_write_buffer_index(racer_thread *thread) {
	thread->write_buffer_index += 1;
	thread->write_buffer_index %= thread->buffer_count;

	// skip buffer when it is being drawn
	if (thread->write_buffer_index == thread->draw_buffer_index) {
		thread->write_buffer_index += 1;
		thread->write_buffer_index %= thread->buffer_count;
	}
}

static void sync_video(const void *output, racer_video_sync sync) {
	if (!(sync & (VIDEO_VERTICAL_SYNC | VIDEO_BUFFER_SYNC))) {
		// do nothing unless it's a vertical or buffer sync
		return;
	}

	racer_thread *thread = (racer_thread *)output;
	pthread_mutex_lock(&thread->index_lock);

	// swap video output buffer in TIA
	advance_write_buffer_index(thread);

	uint8_t *buffer = thread->buffers[thread->write_buffer_index];
	thread->console->tia->video_buffer = buffer;
	thread->console->tia->video_buffer_end = buffer + thread->buffer_size;
	pthread_mutex_unlock(&thread->index_lock);

	// update field rate
	update_field_rate(thread);
}

static void * run_loop(void *data) {
	racer_thread *thread = (racer_thread *)data;
	while(true) {
		racer_atari2600_advance_clock(thread->console);
	}

	return NULL;
}

racer_thread * racer_thread_create(racer_atari2600 *console, uint8_t **buffers, int buffer_count, size_t buffer_size) {
	racer_thread *thread = malloc(sizeof(racer_thread));
	thread->buffers = malloc(buffer_count * sizeof(uint8_t *));
	thread->buffer_count = buffer_count;
	thread->buffer_size = buffer_size;
	memcpy(thread->buffers, buffers, buffer_count * sizeof(uint8_t *));

	thread->write_buffer_index = 0;
	thread->draw_buffer_index = -1;

	thread->console = console;
	thread->console->tia->video_output = thread;
	thread->console->tia->video_buffer = thread->buffers[0];
	thread->console->tia->sync_video = sync_video;
	sync_video(thread, VIDEO_BUFFER_SYNC);

	thread->field_time = DBL_MIN;
	clock_gettime(CLOCK_MONOTONIC, &thread->field_start_time);

	pthread_mutex_init(&thread->index_lock, NULL);
	pthread_create(&thread->handle, NULL, run_loop, thread);
	return thread;
}

void racer_thread_resume(racer_thread *thread) {
	pthread_mutex_lock(&thread->index_lock);

	// unlock draw buffer index
	thread->draw_buffer_index = -1;
	pthread_mutex_unlock(&thread->index_lock);
}

void racer_thread_suspend(racer_thread *thread) {
	pthread_mutex_lock(&thread->index_lock);

	// lock last finished write buffer for drawing
	thread->draw_buffer_index = thread->write_buffer_index - 1;
	thread->draw_buffer_index += thread->buffer_count;
	thread->draw_buffer_index %= thread->buffer_count;
	pthread_mutex_unlock(&thread->index_lock);
}

bool racer_thread_is_suspended(racer_thread *thread) {
	// no breaks here
	return false;
}

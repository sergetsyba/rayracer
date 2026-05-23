//
//  thread.c
//  librayracer
//
//  Created by Serge Tsyba on 25.4.2026.
//

#include "thread.h"
#include "tia.h"

#include <stdlib.h>
#include <stdio.h>

static void update_field_rate(racer_thread *thread) {
	clock_t current_clock = clock();
	// adding 1 guards agains 
	long field_time = (current_clock - thread->field_start_clock) + 1;

	// fps = α⋅(1/time) + (1-α)⋅fps
	// α = 0.1, smoothing factor
	thread->field_rate *= 0.9;
	thread->field_rate += 0.1/field_time;
	thread->field_start_clock = current_clock;
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

racer_thread * racer_thread_create(racer_atari2600 *console, uint8_t *buffers[3], int buffer_count, size_t buffer_size) {
	racer_thread *thread = malloc(sizeof(racer_thread));
	thread->buffers = buffers;
	thread->buffer_count = buffer_count;
	thread->buffer_size = buffer_size;

	thread->write_buffer_index = 0;
	thread->draw_buffer_index = -1;

	thread->console = console;
	thread->console->tia->video_output = thread;
	thread->console->tia->video_buffer = buffers[0];
	thread->console->tia->sync_video = sync_video;

	sync_video(thread, VIDEO_BUFFER_SYNC);
	thread->field_rate = 0;
	thread->field_start_clock = clock();

	pthread_mutex_init(&thread->index_lock, NULL);
	pthread_create(&thread->handle, NULL, run_loop, thread);
	return thread;
}

void racer_thread_resume(racer_thread *thread) {

}

int racer_thread_lock_draw_buffer(racer_thread *thread) {
	pthread_mutex_lock(&thread->index_lock);
	thread->draw_buffer_index = thread->write_buffer_index - 1;
	thread->draw_buffer_index += thread->buffer_count;
	thread->draw_buffer_index %= thread->buffer_count;

	pthread_mutex_unlock(&thread->index_lock);
	return thread->draw_buffer_index;
}

void racer_thread_unlock_draw_buffer(racer_thread *thread) {
	pthread_mutex_lock(&thread->index_lock);
	thread->draw_buffer_index = -1;

	pthread_mutex_unlock(&thread->index_lock);
}

int racer_thread_get_field_rate(racer_thread *thread) {
	return (int)(thread->field_rate * CLOCKS_PER_SEC);
}

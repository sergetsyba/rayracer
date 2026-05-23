//
//  thread.h
//  librayracer
//
//  Created by Serge Tsyba on 25.4.2026.
//

#ifndef thread_h
#define thread_h

#include "atari2600.h"

#include <pthread.h>
#include <stdint.h>
#include <time.h>

typedef struct {
	racer_atari2600 *console;
	uint8_t **buffers;
	int buffer_count;
	size_t buffer_size;

	int write_buffer_index;
	int draw_buffer_index;

	pthread_t handle;
	pthread_mutex_t mutex;
	pthread_mutex_t index_lock;

	double field_time;
	struct timespec field_start_time;
} racer_thread;

racer_thread * racer_thread_create(racer_atari2600 *console, uint8_t **buffers, int buffer_count, size_t buffer_size);
void racer_thread_suspend(racer_thread *thread);
void racer_thread_resume(racer_thread *thread);

int racer_thread_lock_draw_buffer(racer_thread *thread);
void racer_thread_unlock_draw_buffer(racer_thread *thread);

#endif /* thread_h */

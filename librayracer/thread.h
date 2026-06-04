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
#include <stdatomic.h>
#include <stdint.h>
#include <time.h>

typedef enum {
	RACER_THREAD_RUNNING,
	RACER_THREAD_PAUSED,
	RACER_THREAD_STOPPED
} racer_thread_state;

typedef struct {
	racer_atari2600 *console;
	uint8_t *buffer;
	size_t buffer_size;

	pthread_t handle;
	pthread_mutex_t mutex;
	pthread_cond_t pause;
	_Atomic racer_thread_state state;

	double field_time;
	struct timespec field_start_time;
} racer_thread;

racer_thread * racer_thread_create(racer_atari2600 *console, uint8_t *buffer, size_t buffer_size);
void racer_thread_destroy(racer_thread *thread);
void racer_thread_resume(racer_thread *thread);
void racer_thread_pause(racer_thread *thread);

#endif /* thread_h */

//
//  thread.h
//  librayracer
//
//  Created by Serge Tsyba on 25.4.2026.
//

#ifndef thread_h
#define thread_h

#include "atari2600.h"
#include <stdint.h>
#include <stdbool.h>

typedef struct racer_thread racer_thread;

racer_thread *racer_thread_create(racer_atari2600 *console, const uint8_t *buffer, size_t buffer_size);
void racer_thread_destroy(racer_thread *thread);

/**
 * Resumes the thread when it is paused with a pause priority lower or equal to the sepcified one.
 */
void racer_thread_resume(racer_thread *thread, uint8_t priority);

/**
 * Pauses the thread with the specified pause priority.
 *
 * When the thread is already paused with pause priority lower than the specified one, updates pause
 * priority to the specified one.
 */
void racer_thread_pause(racer_thread *thread, uint8_t priority);

/**
 * Returns `true` when the thread is paused; returns `false` otherwise.
 */
bool racer_thread_is_paused(const racer_thread *thread);

long int racer_thread_get_field_time(const racer_thread *thread);

#endif /* thread_h */

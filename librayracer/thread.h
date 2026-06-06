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

racer_thread *racer_thread_create(racer_atari2600 *console, uint8_t *buffer, size_t buffer_size);
void racer_thread_destroy(racer_thread *thread);

void racer_thread_resume(racer_thread *thread);
void racer_thread_pause(racer_thread *thread);
bool racer_thread_is_paused(racer_thread *thread);

long int racer_thread_get_field_time(racer_thread *thread);

#endif /* thread_h */

//
//  atari2600.h
//  RayRacer
//
//  Created by Serge Tsyba on 5.12.2025.
//

#ifndef atari2600_h
#define atari2600_h

#include <stdint.h>

#include "mcs6507.h"
#include "mcs6532.h"
#include "tia.h"

typedef struct {
	racer_mcs6507 *mpu;
	racer_mcs6532 *riot;
	racer_tia *tia;
	
	unsigned char *program;
} racer_atari2600;

racer_atari2600 *racer_atari2600_create(void);
void racer_atari2600_reset(racer_atari2600 *console);
void racer_atari2600_advance_clock(racer_atari2600 *console);

#endif /* atari2600_h */

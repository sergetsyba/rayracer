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
#include "cartridge.h"

typedef enum {
	ATARI2600_SWITCH_RESET = 1<<0,
	ATARI2600_SWITCH_SELECT = 1<<1,
	ATARI2600_SWITCH_COLOR = 1<<3,
	ATARI2600_SWITCH_DIFFICULTY_0 = 1<<6,
	ATARI2600_SWITCH_DIFFICULTY_1 = 1<<7
} racer_atari2600_switch;

typedef struct {
	racer_mcs6507 *mpu;
	racer_mcs6532 *riot;
	racer_tia *tia;
	
	uint8_t switches[2];
	uint8_t input;
	
	racer_cartridge_type cartridge_type;
	void *cartridge;
	uint8_t (*read_cartridge)(void *cartridge, int address);
	void (*write_cartridge)(void *cartridge, int address, uint8_t data);
} racer_atari2600;

racer_atari2600 *racer_atari2600_create(void);
void racer_atari2600_reset(racer_atari2600 *console);
void racer_atari2600_advance_clock(racer_atari2600 *console);

#endif /* atari2600_h */

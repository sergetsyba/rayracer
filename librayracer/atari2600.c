//
//  atari2600.c
//  RayRacer
//
//  Created by Serge Tsyba on 5.12.2025.
//

#include "atari2600.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static int read_bus(void *bus, int address) {
	racer_atari2600 *console = (racer_atari2600 *)bus;
	if (address & (1<<12)) {
		return console->program[address & 0x0fff];
	} else if ((address & 0x280) == 0x280) {
		return racer_mcs6532_read(console->riot, address & 0x1f);
	} else if ((address & 0x80) == 0x80) {
		return console->riot->memory[address & 0x7f];
	} else {
		return racer_tia_read(*console->tia, address & 0x3f);
	}
}

static void write_bus(void *bus, int address, int data) {
	racer_atari2600 *console = (racer_atari2600 *)bus;
	
	if ((address & 0xf000) == 0xf000) {
		printf("write_bus: ignoring write at rom address $%04x.\n", address);
	} else if ((address & 0x280) == 0x280) {
		racer_mcs6532_write(console->riot, address & 0x1f, data);
	} else if ((address & 0x80) == 0x80) {
		console->riot->memory[address & 0x7f] = data;
	} else {
		racer_tia_write(console->tia, address & 0x3f, data);
	}
}


// MARK: -
// MARK: MCS6532 peripherals
static uint8_t read_controllers(const void *peripheral) {
	return 0;
}

static void write_controllers(void *peripheral, uint8_t data) {
	
}

static uint8_t read_switches(const void *peripheral) {
	const racer_atari2600 *console = (racer_atari2600 *)peripheral;
	
	// when switches for `select` and `reset` are on, corresponding
	// bits are 0
	return console->switches ^ 0x3;
}

static void write_switches(void *peripheral, uint8_t data) {
	racer_atari2600 *console = (racer_atari2600 *)peripheral;
	
	// switches are supposed to be read-only, but can be written to
	// nonetheless; writing sets the 3 unused bits
	console->switches &= ~0x34;
	console->switches |= data & 0x34;
}


// MARK: -
racer_atari2600 *racer_atari2600_create(void) {
	racer_atari2600 *console = (racer_atari2600 *)malloc(sizeof(racer_atari2600));
	
	// create and wire MPU
	console->mpu = (racer_mcs6507 *)malloc(sizeof(racer_mcs6507));
	console->mpu->bus = console;
	console->mpu->read_bus = read_bus;
	console->mpu->write_bus = write_bus;
	
	// create and wire RIOT
	console->riot = (racer_mcs6532 *)malloc(sizeof(racer_mcs6532));
	memcpy(console->riot->peripherals, (void *[]){
		console,
		console
	}, sizeof(console->riot->peripherals));
	memcpy(console->riot->read_port, (uint8_t (*[])(const void *)){
		read_controllers,
		read_switches
	}, sizeof(console->riot->read_port));
	memcpy(console->riot->write_port, (void (*[])(void *, uint8_t)){
		write_controllers,
		write_switches
	}, sizeof(console->riot->write_port));
	
	// create and wire TIA
	console->tia = (racer_tia *)malloc(sizeof(racer_tia));
	console->tia->is_ready = &console->mpu->is_ready;
	racer_tia_init();
	
	return console;
}

void racer_atari2600_reset(racer_atari2600 *console) {
	racer_mcs6507_reset(console->mpu);
	racer_mcs6532_reset(console->riot);
	racer_tia_reset(console->tia);
}

void racer_atari2600_advance_clock(racer_atari2600 *console) {
	racer_mcs6507_advance_clock(console->mpu);
	racer_mcs6532_advance_clock(console->riot);
	
	racer_tia_advance_clock(console->tia);
	racer_tia_advance_clock(console->tia);
	racer_tia_advance_clock(console->tia);
}

//
//  atari2600.c
//  RayRacer
//
//  Created by Serge Tsyba on 5.12.2025.
//

#include "atari2600.h"
#include "cartridge.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


// MARK: -
// MARK: Bus
static uint8_t read_bus(void *bus, int address) {
	racer_atari2600 *console = (racer_atari2600 *)bus;
	if (address & 0x1000) {
		return console->read_cartridge(console->cartridge, address & 0xfff);
	} else if ((address & 0x280) == 0x280) {
		return racer_mcs6532_read(console->riot, address & 0x1f);
	} else if ((address & 0x80) == 0x80) {
		return console->riot->memory[address & 0x7f];
	} else {
		return racer_tia_read(console->tia, address & 0x3f);
	}
}

static void write_bus(void *bus, int address, uint8_t data) {
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
// MARK: MCS6532 and TIA peripherals
static uint8_t riot_read_controllers(const void *peripheral) {
	const racer_atari2600 *console = (racer_atari2600 *)peripheral;
	return ~(console->switches[0]);
}

static void riot_write_controllers(void *peripheral, uint8_t data) {
	// does nothing
}

static uint8_t riot_read_switches(const void *peripheral) {
	// when switches for `select` and `reset` are on, corresponding
	// bits are 0
	const racer_atari2600 *console = (racer_atari2600 *)peripheral;
	return console->switches[1] ^ 0x3;
}

static void riot_write_switches(void *peripheral, uint8_t data) {
	racer_atari2600 *console = (racer_atari2600 *)peripheral;
	
	// switches are supposed to be read-only, but can be written to
	// nonetheless; writing sets the 3 unused bits
	console->switches[1] &= ~0x34;
	console->switches[1] |= data & 0x34;
}

static uint8_t tia_read_controllers(const void *peripheral) {
	const racer_atari2600 *console = (racer_atari2600 *)peripheral;
	return ~(console->input);
}


// MARK: -
static int null_position = 0;
racer_atari2600 *racer_atari2600_create(void) {
	racer_atari2600 *console = (racer_atari2600 *)malloc(sizeof(racer_atari2600));
	
	// create and wire MPU
	console->mpu = (racer_mcs6507 *)malloc(sizeof(racer_mcs6507));
	console->mpu->bus = console;
	console->mpu->read_bus = read_bus;
	console->mpu->write_bus = write_bus;
	
	// create and wire RIOT
	console->riot = (racer_mcs6532 *)malloc(sizeof(racer_mcs6532));
	console->riot->timer_scale = 10;
	console->riot->timer = 0xb8 * (1<<10);
	
	memcpy(console->riot->peripherals, (void *[]){
		console,
		console
	}, sizeof(console->riot->peripherals));
	memcpy(console->riot->read_port, (uint8_t (*[])(const void *)){
		riot_read_controllers,
		riot_read_switches
	}, sizeof(console->riot->read_port));
	memcpy(console->riot->write_port, (void (*[])(void *, uint8_t)){
		riot_write_controllers,
		riot_write_switches
	}, sizeof(console->riot->write_port));
	
	// create and wire TIA
	console->tia = (racer_tia *)malloc(sizeof(racer_tia));
	console->tia->is_ready = &console->mpu->is_ready;
	console->tia->peripheral = console;
	console->tia->read_port = tia_read_controllers;
	
	// init graphics objects
	console->tia->players[0].missile_position = &null_position;
	console->tia->players[1].missile_position = &null_position;
	return console;
}

void racer_atari2600_insert_cartridge(racer_atari2600 *console, racer_cartridge_type type, const uint8_t *data) {
	switch (type) {
		case CARTRIDGE_ATARI_2KB:
			console->cartridge_type = type;
			console->cartridge = (void *)data;
			console->read_cartridge = read_atari_2kb_cartridge;
			break;
			
		case CARTRIDGE_ATARI_4KB:
			console->cartridge_type = type;
			console->cartridge = (void *)data;
			console->read_cartridge = read_atari_4kb_cartridge;
			break;
			
		case CARTRIDGE_ATARI_8KB: {
			atari_8k_cartridge *cartridge = (atari_8k_cartridge *)malloc(sizeof(atari_8k_cartridge));
			cartridge->data[0] = &data[0];
			cartridge->data[1] = &data[0x1000];
			
			console->cartridge_type = type;
			console->cartridge = cartridge;
			console->read_cartridge = read_atari_8kb_cartridge;
			break;
		}
			
		default:
			printf("insert cartridge: unsupport cartridge type: %d\n", type);
			return;
	}
}

static void reset_cartridge(racer_atari2600 *console) {
	switch (console->cartridge_type) {
		case CARTRIDGE_ATARI_8KB: {
			atari_8k_cartridge *cartridge = console->cartridge;
			cartridge->bank_index = 1;
			break;
		}
		default:
			break;
	}
}

void racer_atari2600_reset(racer_atari2600 *console) {
	// reset bank index in cartridge
	reset_cartridge(console);
	// reset controller input
	console->switches[0] = 0x00;
	console->input = 0x00;
	
	racer_tia_reset(console->tia);
	racer_mcs6532_reset(console->riot);
	racer_mcs6507_reset(console->mpu);
}

void racer_atari2600_advance_clock(racer_atari2600 *console) {
	racer_mcs6507_advance_clock(console->mpu);
	racer_mcs6532_advance_clock(console->riot);
	
	racer_tia_advance_clock(console->tia);
	racer_tia_advance_clock(console->tia);
	racer_tia_advance_clock(console->tia);
}

//
//  cartridge.c
//  librayracer
//
//  Created by Serge Tsyba on 20.12.2025.
//

#include "cartridge.h"
#include "atari2600.h"

#include <stdlib.h>
#include <stdio.h>

void racer_cartridge_reset(racer_cartridge_type type, void *cartridge_ptr) {
	switch (type) {
		case CARTRIDGE_ATARI_8KB:
		case CARTRIDGE_ATARI_12KB:
		case CARTRIDGE_ATARI_16KB:
		case CARTRIDGE_ATARI_32KB: {
			racer_atari_multi_bank_cartridge *cartridge = (racer_atari_multi_bank_cartridge *)cartridge_ptr;
			cartridge->bank_index = 0;
			break;
		}
		default:
			break;
	}
}


// MARK: -
// MARK: Cartridge access
static uint8_t read_atari_2kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address & 0x7ff];
}

static uint8_t read_atari_4kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address];
}

static void write_atari_cartridge(void *cartridge, int address, uint8_t data) {
	printf("%s: ignoring write at address $%03x.\n", __func__, address);
}

static uint8_t read_atari_multi_bank_cartridge(void *cartridge_ptr, int address) {
	racer_atari_multi_bank_cartridge *cartridge = (racer_atari_multi_bank_cartridge *)cartridge_ptr;
	uint8_t *data = ((uint8_t (*)[0x1000])cartridge->data)[cartridge->bank_index];
	
	// switch bank when read address is within bank switching address range
	if (address >= cartridge->bank_switch_address) {
		const int bank_index = address - cartridge->bank_switch_address;
		if (bank_index < cartridge->bank_count) {
			cartridge->bank_index = bank_index;
		}
	}
	
	return data[address];
}

static void write_atari_multi_bank_cartridge(void *cartridge_ptr, int address, uint8_t data) {
	racer_atari_multi_bank_cartridge *cartridge = (racer_atari_multi_bank_cartridge *)cartridge_ptr;
	
	// switch bank when read address is within bank switching address range
	if (address >= cartridge->bank_switch_address) {
		const int bank_index = address - cartridge->bank_switch_address;
		if (bank_index < cartridge->bank_count) {
			cartridge->bank_index = bank_index;
		}
	}
}


// MARK: -
// MARK: Console integration
static racer_atari_multi_bank_cartridge *create_atari_multi_bank_cartridge(int bank_count, int bank_switch_address, const uint8_t *data) {
	racer_atari_multi_bank_cartridge *cartridge = (racer_atari_multi_bank_cartridge *)malloc(sizeof(racer_atari_multi_bank_cartridge));
	cartridge->bank_count = bank_count;
	cartridge->bank_index = 0;
	cartridge->bank_switch_address = bank_switch_address;
	cartridge->data = data;
	
	return cartridge;
}

void racer_atari2600_insert_cartridge(void *console_ptr, racer_cartridge_type type, const uint8_t *data) {
	racer_atari2600 *console = (racer_atari2600 *)console_ptr;
	console->cartridge_type = type;
	
	switch (type) {
		case CARTRIDGE_ATARI_2KB:
			console->cartridge = (void *)data;
			console->read_cartridge = read_atari_2kb_cartridge;
			console->write_cartridge = write_atari_cartridge;
			break;
			
		case CARTRIDGE_ATARI_4KB:
			console->cartridge = (void *)data;
			console->read_cartridge = read_atari_4kb_cartridge;
			console->write_cartridge = write_atari_cartridge;
			break;
			
		case CARTRIDGE_ATARI_8KB:
			console->cartridge = create_atari_multi_bank_cartridge(8/4, 0xff8, data);
			console->read_cartridge = read_atari_multi_bank_cartridge;
			console->write_cartridge = write_atari_multi_bank_cartridge;
			break;
			
		case CARTRIDGE_ATARI_12KB:
			console->cartridge = create_atari_multi_bank_cartridge(12/4, 0xff8, data);
			console->read_cartridge = read_atari_multi_bank_cartridge;
			console->write_cartridge = write_atari_multi_bank_cartridge;
			break;
			
		case CARTRIDGE_ATARI_16KB:
			console->cartridge = create_atari_multi_bank_cartridge(16/4, 0xff6, data);
			console->read_cartridge = read_atari_multi_bank_cartridge;
			console->write_cartridge = write_atari_multi_bank_cartridge;
			break;
			
		case CARTRIDGE_ATARI_32KB:
			console->cartridge = create_atari_multi_bank_cartridge(32/4, 0xff4, data);
			console->read_cartridge = read_atari_multi_bank_cartridge;
			console->write_cartridge = write_atari_multi_bank_cartridge;
			break;
			
		default:
			printf("%s: unsupport cartridge type: %d\n", __func__, type);
			exit(EXIT_FAILURE);
			break;
	}
}

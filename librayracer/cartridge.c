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
			atari_multi_bank_cartridge *cartridge = (atari_multi_bank_cartridge *)cartridge_ptr;
			cartridge->bank_index = 0;
			break;
		}
		default:
			break;
	}
}


// MARK: -
// MARK: Atari single-bank cartridge
uint8_t read_atari_2kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address & 0x7ff];
}

uint8_t read_atari_4kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address];
}

void write_atari_cartridge(void *cartridge, int address, uint8_t data) {
	printf("%s: ignoring write at address $%03x.\n", __func__, address);
}


// MARK: -
// MARK: Atari mutli-bank cartridge
uint8_t read_atari_multi_bank_cartridge(void *cartridge_ptr, int address) {
	atari_multi_bank_cartridge *cartridge = (atari_multi_bank_cartridge *)cartridge_ptr;
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

void write_atari_multi_bank_cartridge(void *cartridge_ptr, int address, uint8_t data) {
	atari_multi_bank_cartridge *cartridge = (atari_multi_bank_cartridge *)cartridge_ptr;
	
	// switch bank when read address is within bank switching address range
	if (address >= cartridge->bank_switch_address) {
		const int bank_index = address - cartridge->bank_switch_address;
		if (bank_index < cartridge->bank_count) {
			cartridge->bank_index = bank_index;
		}
	}
}

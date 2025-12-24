//
//  cartridge.c
//  librayracer
//
//  Created by Serge Tsyba on 20.12.2025.
//

#include "cartridge.h"

uint8_t read_atari_2kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address & 0x7ff];
}

uint8_t read_atari_4kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address];
}

uint8_t read_atari_8kb_cartridge(void *cartridge, int address) {
	atari_8k_cartridge *cartridge2 = (atari_8k_cartridge *)cartridge;
	const uint8_t data = cartridge2->data[cartridge2->bank_index][address];
	
	switch (address) {
		case 0xff8:
			cartridge2->bank_index = 0;
			break;
		case 0xff9:
			cartridge2->bank_index = 1;
		default:
			break;
	}
	
	return data;
}

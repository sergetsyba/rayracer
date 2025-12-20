//
//  cartridge.c
//  librayracer
//
//  Created by Serge Tsyba on 20.12.2025.
//

#include "cartridge.h"

uint8_t read_2kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address & 0x7ff];
}

uint8_t read_4kb_cartridge(void *cartridge, int address) {
	const uint8_t *data = (uint8_t *)cartridge;
	return data[address];
}

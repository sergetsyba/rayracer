//
//  cartridge.h
//  librayracer
//
//  Created by Serge Tsyba on 20.12.2025.
//

#ifndef cartridge_h
#define cartridge_h

#include <stdint.h>

typedef struct {
	int bank_index;
	const uint8_t *data[2];
} racer_atari_8k_cartridge;

uint8_t read_atari_2kb_cartridge(void *cartridge, int address);
uint8_t read_atari_4kb_cartridge(void *cartridge, int address);
uint8_t read_atari_8kb_cartridge(void *cartridge, int address);

#endif /* cartridge_h */

//
//  cartridge.h
//  librayracer
//
//  Created by Serge Tsyba on 20.12.2025.
//

#ifndef cartridge_h
#define cartridge_h

#include <stdint.h>

typedef enum {
	CARTRIDGE_ATARI_2KB,
	CARTRIDGE_ATARI_4KB,
	CARTRIDGE_ATARI_8KB,
	CARTRIDGE_ATARI_12KB,
	CARTRIDGE_ATARI_16KB,
	CARTRIDGE_ATARI_32KB
} racer_cartridge_type;

void racer_cartridge_reset(racer_cartridge_type type, void *cartridge);

// MARK: -
// MARK: Atari single-bank cartridge
uint8_t read_atari_2kb_cartridge(void *cartridge, int address);
uint8_t read_atari_4kb_cartridge(void *cartridge, int address);
void write_atari_cartridge(void *cartridge, int address, uint8_t data);


// MARK: -
// MARK: Atari multi-bank cartridge
typedef struct {
	int bank_count;
	int bank_index;
	int bank_switch_address;
	
	const uint8_t *data;
} atari_multi_bank_cartridge;

uint8_t read_atari_multi_bank_cartridge(void *cartridge, int address);
void write_atari_multi_bank_cartridge(void *cartridge, int address, uint8_t data);

#endif /* cartridge_h */

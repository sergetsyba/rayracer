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

typedef struct {
	int bank_count;
	int bank_index;
	int bank_switch_address;
	
	const uint8_t *data;
} racer_atari_multi_bank_cartridge;

void racer_cartridge_reset(racer_cartridge_type type, void *cartridge);
void racer_atari2600_insert_cartridge(void *console, racer_cartridge_type type, const uint8_t *data);

#endif /* cartridge_h */

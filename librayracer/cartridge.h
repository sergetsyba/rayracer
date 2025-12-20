//
//  cartridge.h
//  librayracer
//
//  Created by Serge Tsyba on 20.12.2025.
//

#ifndef cartridge_h
#define cartridge_h

#include <stdint.h>

uint8_t read_2kb_cartridge(void *cartridge, int address);
uint8_t read_4kb_cartridge(void *cartridge, int address);

#endif /* cartridge_h */

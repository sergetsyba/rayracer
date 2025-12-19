//
//  graphics.h
//  librayracer
//
//  Created by Serge Tsyba on 18.12.2025.
//

#ifndef graphics_h
#define graphics_h

#include <stdint.h>

extern const uint16_t copy_modes[][2];
extern uint8_t *reflections;
extern uint16_t *collisions;
extern uint8_t *draw_priorities;

void racer_init(void);

#endif /* graphics_h */

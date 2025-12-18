//
//  playfield.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef play_field_h
#define play_field_h

#include <stdint.h>
#include <stdbool.h>

typedef struct {
	uint64_t graphics;
	uint8_t data[6];
	
	bool is_reflected;
	bool is_score_mode_on;
	bool has_priority;
} racer_playfield;

void set_playfield_graphics(racer_playfield *playfield, uint8_t data, int index);
void set_playfield_control(racer_playfield *playfield, uint8_t control);
bool playfield_needs_drawing(racer_playfield playfield, int position);

#endif /* play_field_h */

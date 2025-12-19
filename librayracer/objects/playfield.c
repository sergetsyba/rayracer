//
//  playfield.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include <string.h>

#include "playfield.h"
#include "../graphics.h"

static void update_playfield_graphics(racer_playfield *playfield) {
	// copy left half graphics
	uint8_t *graphics = (uint8_t *)&playfield->graphics;
	memcpy(graphics, playfield->data, 3);
	
	// copy right half graphics
	if (playfield->is_reflected) {
		memcpy(graphics + 3, playfield->data + 3, 3);
		playfield->graphics >>= 4;
	} else {
		playfield->graphics >>= 4;
		playfield->graphics &= 0xfffff00000;
		playfield->graphics |= playfield->graphics << 20;
	}
}

void set_playfield_graphics(racer_playfield *playfield, uint8_t data, int index) {
	playfield->data[index] = data;
	playfield->data[3+(2-index)] = reflections[data];
	update_playfield_graphics(playfield);
}

void set_playfield_control(racer_playfield *playfield, uint8_t control) {
	// update playfield when the new is_reflected option is different
	// from the current one
	if ((playfield->is_reflected ^ (control & 0x1))) {
		update_playfield_graphics(playfield);
	}
	
	playfield->is_reflected = control & 0x1;
	playfield->is_score_mode_on = (control & 0x6) == 0x2;
	playfield->has_priority = control & 0x4;
}

bool playfield_needs_drawing(racer_playfield playfield, int position) {
	// each bit of playfield graphics draws for 4 color clocks
	const int bit = position >> 2;		// position / 4
	return playfield.graphics & (1L << bit);
}

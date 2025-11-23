//
//  playfield.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "playfield.h"
#include "object.h"

void set_playfield_graphics(rr_playfield* playfield, int data, int bit) {
	playfield->graphics &= ~(0xffL << bit);
	playfield->graphics |= data << bit;
	
	if (playfield->flags & PLAYFIELD_REFLECTED) {
		data = reflections[data];
		bit = (20-8)-bit;
	}
	
	playfield->graphics &= ~(0xffL << (bit + 20));
	playfield->graphics |= (long)data << (bit + 20);
}

void set_playfield_flags(rr_playfield *playfield, int flags) {
	// reflect right half of playfield when relfected flag is different
	// from the current one
	if ((playfield->flags ^ flags) & PLAYFIELD_REFLECTED) {
		int reflected[] = {
			reflections[(playfield->graphics >> 0) & 0xff],
			reflections[(playfield->graphics >> 8) & 0xff],
			reflections[(playfield->graphics >> 16) & 0xf],
		};
		
		playfield->graphics &= 0xfffff;
		playfield->graphics |= (long)reflected[2] << (20-4);
		playfield->graphics |= (long)reflected[1] << (20+4);
		playfield->graphics |= (long)reflected[0] << (20+12);
	}
	
	playfield->flags = flags;
}

bool playfield_needs_drawing(rr_playfield playfield, int position) {
	// each bit of playfield graphics draws for 4 color clocks
	const int bit = position >> 2;		// position / 4
	return playfield.graphics & (1L << bit);
}

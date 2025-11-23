//
//  playfield.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "playfield.h"
#include "object.h"

bool rr_playfield_needs_drawing(rr_playfield playfield, int position) {
	// each bit of playfield graphics draws for 4 color clocks
	const int bit = position >> 2;		// position / 4
	return playfield.graphics & (1L << bit);
}

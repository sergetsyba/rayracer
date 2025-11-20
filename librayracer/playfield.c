//
//  playfield.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "playfield.h"

bool rr_playfield_needs_drawing(rr_playfield playfield, int position) {
	// each bit of playfield graphics draws for 4 color clocks
	const int bit = position >> 2;		// position / 4
	
	const bool is_right_half = bit > 19;
	const bool is_reflected = playfield.options & 0x1;
	const long mask = is_right_half && is_reflected
	? (1L << 39) >> bit
	: 1 << bit;
	
	return playfield.graphics & mask;
}

//
//  player.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "player.h"

bool rr_player_needs_drawing(rr_player player) {
	int section = player.position >> 3;		// position / 8
	section >>= player.scale;				// position / size
	
	// ensure position counter is within any of the 8-color clock wide
	// sections of a scan line where a player copy can be drawn
	if ((player.copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	const int graphics = player.flags & PLAYER_DELAYED
	? player.graphics[1]
	: player.graphics[0];
	
	const int bit = player.position & 0x7;	// position % 8
	const int mask = player.flags & PLAYER_REFLECTED
	? (1 << 7) >> bit
	: 1 << bit;
	
	return graphics & mask;
}

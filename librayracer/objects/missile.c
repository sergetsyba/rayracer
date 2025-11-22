//
//  missile.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "missile.h"
#include "bits.h"

bool rr_missile_needs_drawing(rr_missile missile) {
	// ensure missile is enabled and not reset to player
	if (!(missile.flags & MISSILE_ENABLED)
		|| (missile.flags & MISSILE_RESET_TO_PLAYER)) {
		return false;
	}
	
	// ensure position counter is within one of the 8-color clock wide
	// sections of a scan line where a missile copy can be drawn
	const int section = missile.position >> 3;	// position / 8
	if ((missile.copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	const int bit = missile.position & 0x7;		// position % 8
	return bit < missile.size;
}

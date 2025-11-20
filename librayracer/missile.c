//
//  missile.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "missile.h"

bool rr_missile_needs_drawing(rr_missile missile) {
	// ensure missile is enabled and not reset to player
	if (missile.is_enabled == false || missile.is_reset) {
		return false;
	}
	
	// ensure position counter is within one of the 8-color clock wide
	// sections of a scan line where a missile copy can be drawn
	const int section = missile.position >> 3;	// position / 8
	if ((missile.copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	return missile.position < missile.size;
}

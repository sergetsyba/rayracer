//
//  missile.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef missile_h
#define missile_h

#include <stdbool.h>

typedef struct {
	int copy_mask;
	
	int size;
	bool is_enabled;
	bool is_reset_to_player;
	
	int position;
	int motion;
} racer_missile;

bool missile_needs_drawing(racer_missile missile);

#endif /* missile_h */

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
	int flags;
	
	int position;
	int motion;
} rr_missile;

typedef enum {
	MISSILE_ENABLED = 1 << 0,
	MISSILE_RESET_TO_PLAYER = 1 << 1
} rr_missile_flag;

bool rr_missile_needs_drawing(rr_missile missile);

#endif /* missile_h */

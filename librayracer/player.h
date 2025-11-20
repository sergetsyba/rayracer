//
//  player.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef player_h
#define player_h

#include <stdbool.h>

typedef struct {
	int copy_mask;
	int scale;
	
	int graphics[2];
	bool is_reflected;
	bool is_delayed;
	
	int position;
	int motion;
} rr_player;

bool rr_player_needs_drawing(rr_player player);

#endif /* player_h */

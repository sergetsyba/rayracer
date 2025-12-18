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
	
	int graphics[2];
	int scale;
	bool is_reflected;
	bool is_delayed;
	
	int position;
	int motion;
} racer_player;

void set_player_graphics(racer_player* player, int graphics);
void set_player_reflected(racer_player* player, bool is_reflected);
bool player_needs_drawing(racer_player player);

#endif /* player_h */

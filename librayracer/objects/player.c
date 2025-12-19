//
//  player.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "player.h"
#include "../graphics.h"

void set_player_graphics(racer_player* player, int graphics) {
	if (player->is_reflected) {
		graphics = reflections[graphics];
	}
	player->graphics[0] = graphics;
}

void set_player_reflected(racer_player* player, bool is_reflected) {
	if (player->is_reflected ^ is_reflected) {
		player->graphics[0] = reflections[player->graphics[0]];
		player->graphics[1] = reflections[player->graphics[1]];
	}
	player->is_reflected = is_reflected;
}

bool player_needs_drawing(racer_player player) {
	int section = player.position >> 3;		// position / 8
	section >>= player.scale;				// position / size
	
	// ensure position counter is within any of the 8-color clock wide
	// sections of a scan line where a player copy can be drawn
	if ((player.copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	const int graphics = player.graphics[player.is_delayed];
	const int bit = player.position & 0x7;	// position % 8
	return graphics & (1 << bit);
}

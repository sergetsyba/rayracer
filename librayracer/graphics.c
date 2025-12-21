//
//  graphics.c
//  librayracer
//
//  Created by Serge Tsyba on 18.12.2025.
//

#include "graphics.h"
#include <stdlib.h>

bool player_needs_drawing(const racer_player *player) {
	int section = player->position >> 3;	// position / 8
	section >>= player->scale;				// position / size
	
	// ensure position counter is within any of the 8-color clock wide
	// sections of a scan line where a player copy can be drawn
	if ((player->copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	const int graphics = player->graphics[player->control];
	const int bit = player->position & 0x7;	// position % 8
	return graphics & (1 << bit);
}

bool missile_needs_drawing(const racer_missile *missile) {
	// ensure missile is enabled and not reset to player
	if (missile->control != MISSILE_ENABLED) {
		return false;
	}
	
	// ensure position counter is within one of the 8-color clock wide
	// sections of a scan line where a missile copy can be drawn
	const int section = missile->position >> 3;	// position / 8
	if ((missile->copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	const int bit = missile->position & 0x7;	// position % 8
	return bit < missile->size;
}

bool ball_needs_drawing(const racer_ball *ball) {
	// ensure ball is enabled
	if ((ball->control != BALL_ENABLED_0) &&
		(ball->control != (BALL_ENABLED_1 | BALL_DELAYED))) {
		return false;
	}
	
	return ball->position < ball->size;
}

bool playfield_needs_drawing(const racer_playfield *playfield, int position) {
	const bool is_reflected = playfield->control & PLAYFIELD_REFLECTED;
	const uint64_t graphics = playfield->graphics[is_reflected];
	
	// each bit of playfield graphics draws for 4 color clocks
	const int bit = position >> 2;		// position / 4
	return graphics & (1L << bit);
}

void advance_player_position(racer_player *player) {
	player->position += 1;
	
	if (player->position == 160) {
		player->position = 0;
		*player->missile_position = 0;
	}
}

int no_missile_position = 0;

#define flip(value, bit) (((value >> (bit)) & 0x1) << (7-(bit)))
uint8_t reflect_graphics(uint8_t graphics) {
	return 0x00
	| flip(graphics, 0)
	| flip(graphics, 1)
	| flip(graphics, 2)
	| flip(graphics, 3)
	| flip(graphics, 4)
	| flip(graphics, 5)
	| flip(graphics, 6)
	| flip(graphics, 7);
}

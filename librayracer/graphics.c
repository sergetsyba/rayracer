//
//  graphics.c
//  librayracer
//
//  Created by Serge Tsyba on 18.12.2025.
//

#include "graphics.h"
#include "tia.h"

// MARK: Drawing
static bool is_player_visible(const racer_player *player) {
	int section = player->position >> 3;		// position / 8
	section >>= player->scale;					// position / size
	
	// ensure position counter is within any of the 8-color clock wide
	// sections of a scan line where a player copy can be drawn
	if ((player->copy_mask & (1 << section)) == 0) {
		return false;
	}
	
	const int size = 8 << player->scale;
	int bit = player->position & (size - 1);	// position % size
	bit >>= player->scale;
	
	const int graphics = player->graphics[player->control & 0x3];
	return graphics & (1 << bit);
}

static bool is_missile_visible(const racer_missile *missile) {
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

static bool is_ball_visible(const racer_ball *ball) {
	// ensure ball is enabled
	if ((ball->control != BALL_ENABLED_0) &&
		(ball->control != (BALL_ENABLED_1 | BALL_DELAYED))) {
		return false;
	}
	
	return ball->position < ball->size;
}

static bool is_playfield_visible(const racer_playfield *playfield, int position) {
	const bool is_reflected = playfield->control & PLAYFIELD_REFLECTED;
	const uint64_t graphics = playfield->graphics[is_reflected];
	
	// each bit of playfield graphics draws for 4 color clocks
	const int bit = position >> 2;		// position / 4
	return graphics & (1L << bit);
}

uint16_t get_object_draw_state(const struct racer_tia *tia) {
	// right screen half
	const int position = tia->color_clock - 68;
	uint16_t state = position >= 80;
	
	// playfield score mode and priority
	state |= (tia->playfield.control & 0x6);
	
	// graphics objects
	state |= is_player_visible(&tia->players[0]) << 3;
	state |= is_player_visible(&tia->players[1]) << 4;
	state |= is_missile_visible(&tia->missiles[0]) << 5;
	state |= is_missile_visible(&tia->missiles[1]) << 6;
	state |= is_ball_visible(&tia->ball) << 7;
	state |= is_playfield_visible(&tia->playfield, position) << 8;
	
	return state;
}

/**
 * Returns index of the object to be drawn for the specified draw state.
 *
 * The is an index
 *	0 - player/missile 0
 *	1 - player/missile 1
 *	2 - ball/playfield
 *	3 - background
 */
static uint8_t get_draw_index(uint16_t draw_state) {
	if ((draw_state & (TIA_DRAWS_PLAYFIELD | PLAYFIELD_PRIORITY)
		 && draw_state & ~(PLAYFIELD_PRIORITY))) {
		// playfield priority (score mode off)
		return 2;
	} else if (draw_state & (TIA_DRAWS_PLAYER_0 | TIA_DRAWS_MISSILE_0)) {
		// player 0/missile 0
		return 0;
	} else if (draw_state & (TIA_DRAWS_PLAYER_1 | TIA_DRAWS_MISSILE_1)) {
		// player 1/missile 1
		return 1;
	} else if (draw_state & TIA_DRAWS_BALL) {
		// ball
		return 2;
	} else if (draw_state & TIA_DRAWS_PLAYFIELD) {
		if (draw_state & PLAYFIELD_SCORE_MODE) {
			// score mode (players)
			return (draw_state & TIA_DRAWS_RIGHT_HALF) ? 1 : 0;
		} else {
			// playefield
			return 2;
		}
	} else {
		// background
		return 3;
	}
}

// MARK: -
// MARK: Collisions
#define has_collision(state, objects) \
	((state & (objects)) == (objects))

/**
 * Returns a bit set describing collisions of all objects for the specified draw state.
 *
 * Each bit represents collisions between 2 objects
 * 	bit 0 - missile 0/player 0
 * 	bit 1 - missile 0/player 1
 * 	bit 2 - missile 1/player 0
 * 	bit 3 - missile 1/player 1
 * 	bit 4 - player 0/ball
 * 	bit 5 - player 0/playfield
 * 	bit 6 - player 1/ball
 * 	bit 7 - player 1/playfield
 * 	bit 8 - missile 0/ball
 * 	bit 9 - missile 0/playfiled
 * 	bit 10 - missile 1/ball
 * 	bit 11 - missile 1/playfield
 * 	bit 12 - ball/playfield
 * 	bit 14 - missile 0/missile 1
 * 	bit 15 - player 0/player 1
 *
 * The returned bit set matches bit order returned when reading individual collisions registers in the TIA.
 */
static uint16_t get_collision_state(uint16_t draw_state) {
	uint16_t state = 0;
	// cxm0p
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_0 | TIA_DRAWS_PLAYER_0) << 0;
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_0 | TIA_DRAWS_PLAYER_1) << 1;
	// cxm1p
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_1 | TIA_DRAWS_PLAYER_1) << 2;
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_1 | TIA_DRAWS_PLAYER_0) << 3;
	// cxp0fb
	state |= has_collision(draw_state, TIA_DRAWS_PLAYER_0 | TIA_DRAWS_BALL) << 4;
	state |= has_collision(draw_state, TIA_DRAWS_PLAYER_0 | TIA_DRAWS_PLAYFIELD) << 5;
	// cxp1fb
	state |= has_collision(draw_state, TIA_DRAWS_PLAYER_1 | TIA_DRAWS_BALL) << 6;
	state |= has_collision(draw_state, TIA_DRAWS_PLAYER_1 | TIA_DRAWS_PLAYFIELD) << 7;
	// cxm0fb
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_0 | TIA_DRAWS_BALL) << 8;
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_0 | TIA_DRAWS_PLAYFIELD) << 9;
	// cxm1fb
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_1 | TIA_DRAWS_BALL) << 10;
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_1 | TIA_DRAWS_PLAYFIELD) << 11;
	// cxblpf
	state |= has_collision(draw_state, TIA_DRAWS_BALL | TIA_DRAWS_PLAYFIELD) << 12;
	// cxppmm
	state |= has_collision(draw_state, TIA_DRAWS_MISSILE_0 | TIA_DRAWS_MISSILE_1) << 14;
	state |= has_collision(draw_state, TIA_DRAWS_PLAYER_0 | TIA_DRAWS_PLAYER_1) << 15;
	
	return state;
}


// MARK: -
// MARK: Graphics
#define flip(value, bit) \
(((value >> (bit)) & 0x1) << (7-(bit)))

static uint8_t reflect_graphics(uint8_t graphics) {
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

uint8_t draw_indices[0x200];
uint16_t collisions[0x40];
uint8_t reflections[0x100];

int null_missile_position = 0;

void init_graphics(void) {
	for (int graphics = 0x00; graphics < 0x100; ++graphics) {
		reflections[graphics] = reflect_graphics(graphics);
	}
	for (uint16_t state = 0x00; state < 0x200; ++state) {
		draw_indices[state] = get_draw_index(state);
	}
	for (int state = 0x00; state < 0x40; ++state) {
		collisions[state] = get_collision_state(state << 3);
	}
}

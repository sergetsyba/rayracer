//
//  graphics.c
//  librayracer
//
//  Created by Serge Tsyba on 18.12.2025.
//

#include "graphics.h"
#include <stdlib.h>

const uint16_t copy_modes[][2] = {
	{0x001, 0},	// ●○○○○○○○○○
	{0x005, 0},	// ●○●○○○○○○○
	{0x011, 0},	// ●○○●○○○○○○
	{0x015, 0},	// ●○●○●○○○○○
	{0x101, 0},	// ●○○○○○○○●○
	{0x001, 1},	// ●●○○○○○○○○
	{0x111, 0},	// ●○○○●○○○●○
	{0x001, 2}	// ●●●●○○○○○○
};

#define flip(value, bit) (((value >> (bit)) & 0x1) << (7-(bit)))

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

#define collision(state, mask) ((state & (mask)) == (mask))

#define PLAYER_0 (1<<0)
#define PLAYER_1 (1<<1)
#define MISSILE_0 (1<<2)
#define MISSILE_1 (1<<3)
#define BALL (1<<4)
#define PLAYFIELD (1<<5)

#define SCORE_MODE (1<<6)
#define PLAYFIELD_PRIORITY (1<<7)
#define RIGHT_SCREEN_HALF (1<<8)

static uint16_t get_collisions(uint16_t state) {
	return 0x0000
	// cxm0p
	| collision(state, MISSILE_0 | PLAYER_0) << 0
	| collision(state, MISSILE_0 | PLAYER_1) << 1
	// cxm1p
	| collision(state, MISSILE_1 | PLAYER_1) << 2
	| collision(state, MISSILE_1 | PLAYER_0) << 3
	// cxp0fb
	| collision(state, PLAYER_0 | BALL) << 4
	| collision(state, PLAYER_0 | PLAYFIELD) << 5
	// cxp1fb
	| collision(state, PLAYER_1 | BALL) << 6
	| collision(state, PLAYER_1 | PLAYFIELD) << 7
	// cxm0fb
	| collision(state, MISSILE_0 | BALL) << 8
	| collision(state, MISSILE_0 | PLAYFIELD) << 9
	// cxm1fb
	| collision(state, MISSILE_1 | BALL) << 10
	| collision(state, MISSILE_1 | PLAYFIELD) << 11
	// cxblpf
	| collision(state, BALL | PLAYFIELD) << 12
	// cxppmm
	| collision(state, MISSILE_0 | MISSILE_1) << 14
	| collision(state, PLAYER_0 | PLAYER_1) << 15;
}

#define flag(state, flags) (state & (flags))

static int get_draw_priority(uint16_t state) {
	if (flag(state, PLAYFIELD | PLAYFIELD_PRIORITY)
		&& !flag(state, SCORE_MODE)) {
		// playfield priority (score mode off)
		return 2;
	} else if (flag(state, PLAYER_0 | MISSILE_0)) {
		// player 0/missile 0
		return 0;
	} else if (flag(state, PLAYER_1 | MISSILE_1)) {
		// player 1/missile 1
		return 1;
	} else if (flag(state, BALL)) {
		// ball
		return 2;
	} else if (flag(state, PLAYFIELD)) {
		if (flag(state, SCORE_MODE)) {
			// score mode (players)
			return (flag(state, RIGHT_SCREEN_HALF)) ? 1 : 0;
		} else {
			// playefield
			return 2;
		}
	} else {
		// background
		return 3;
	}
}

uint8_t *reflections;
uint16_t *collisions;
uint8_t *draw_priorities;

void racer_init(void) {
	reflections = malloc(0x100 * sizeof(uint8_t));
	for (int graphics = 0x00; graphics < 0x100; ++graphics) {
		reflections[graphics] = reflect_graphics(graphics);
	}
	
	collisions = malloc(0x20 * sizeof(uint16_t));
	for (int state = 0x00; state < 0x20; ++state) {
		collisions[state] = get_collisions(state);
	}
	
	draw_priorities = malloc(0x200 * sizeof(uint8_t));
	for (uint16_t state = 0x00; state < 0x200; ++state) {
		draw_priorities[state] = get_draw_priority(state);
	}
}

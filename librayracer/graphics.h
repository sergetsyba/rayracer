//
//  graphics.h
//  librayracer
//
//  Created by Serge Tsyba on 18.12.2025.
//

#ifndef graphics_h
#define graphics_h

#include <stdint.h>

// MARK: -
typedef struct {
	uint16_t copy_mask;
	
	uint8_t graphics[4];
	int scale;
	uint8_t control;
	
	int position;
	int motion;
	int *missile_position;
} racer_player;

#define PLAYER_REFLECTED (1<<0)
#define PLAYER_DELAYED (1<<1)
#define PLAYER_POSITION_RESET (1<<2)


// MARK: -
typedef struct {
	uint16_t copy_mask;
	
	int size;
	uint8_t control;
	
	int position;
	int motion;
} racer_missile;

#define MISSILE_ENABLED (1<<0)
#define MISSILE_RESET_TO_PLAYER (1<<1)


// MARK: -
typedef struct {
	int size;
	uint8_t control;
	
	int position;
	int motion;
} racer_ball;

#define BALL_ENABLED_0 (1<<0)
#define BALL_ENABLED_1 (1<<1)
#define BALL_DELAYED (1<<2)


// MARK: -
typedef struct {
	uint64_t graphics[2];
	uint8_t control;
} racer_playfield;

#define PLAYFIELD_REFLECTED (1<<0)
#define PLAYFIELD_SCORE_MODE (1<<1)
#define PLAYFIELD_PRIORITY (1<<2)


// MARK: -
typedef struct racer_tia racer_tia;
extern uint8_t reflections[];
extern uint16_t collisions[];
extern uint8_t draw_indices[];

extern int null_missile_position;

/**
 * Initializes look-up tables for drawing graphics and collision detection.
 */
void init_graphics(void);

/**
 * Returns a bit set describing current drawing conditions of the TIA.
 *
 * Each bit represents the following conditiions:
 * 	bit 0 - TIA is drawing right half of the screen
 *	bit 1 - playfield is in score mode
 *	bit 2 - playfiled has drawing priority over movable objects
 *	bit 3 - player 0 is visible
 *	bit 4 - player 1 is visible
 *	bit 5 - missile 0 is visible
 *	bit 6 - missile 1 is visible
 *	bit 7 - ball is visible
 *	bit 8 - playfield is visible
 */
uint16_t get_object_draw_state(const racer_tia *tia);

#define TIA_DRAWS_RIGHT_HALF (1<<0)
// PLAYFIELD_SCORE_MODE (1<<1)
// PLAYFIELD_PRIORITY (1<<2)
#define TIA_DRAWS_PLAYER_0 (1<<3)
#define TIA_DRAWS_PLAYER_1 (1<<4)
#define TIA_DRAWS_MISSILE_0 (1<<5)
#define TIA_DRAWS_MISSILE_1 (1<<6)
#define TIA_DRAWS_BALL (1<<7)
#define TIA_DRAWS_PLAYFIELD (1<<8)

#endif /* graphics_h */

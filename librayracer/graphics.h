//
//  graphics.h
//  librayracer
//
//  Created by Serge Tsyba on 18.12.2025.
//

#ifndef graphics_h
#define graphics_h

#include <stdint.h>
#include <stdbool.h>

// MARK: -
typedef struct {
	uint8_t copy_mask;
	
	uint8_t graphics[4];
	int scale;
	uint8_t control;
	
	int position;
	int motion;
	int *missile_position;
} racer_player;

bool player_needs_drawing(const racer_player *player);
void reset_player_position(racer_player *player);
void advance_player_position(racer_player *player);

#define PLAYER_REFLECTED (1<<0)
#define PLAYER_DELAYED (1<<1)
#define PLAYER_POSITION_RESET (1<<2)


// MARK: -
typedef struct {
	uint8_t copy_mask;
	
	int size;
	uint8_t control;
	
	int position;
	int motion;
} racer_missile;

bool missile_needs_drawing(const racer_missile *missile);
void set_missile_reset_to_player(racer_missile *missile, racer_player *player, bool is_reset);

#define MISSILE_ENABLED (1<<0)
#define MISSILE_RESET_TO_PLAYER (1<<1)


// MARK: -
typedef struct {
	int size;
	uint8_t control;
	
	int position;
	int motion;
} racer_ball;

bool ball_needs_drawing(const racer_ball *ball);

#define BALL_ENABLED_0 (1<<0)
#define BALL_ENABLED_1 (1<<1)
#define BALL_DELAYED (1<<2)


// MARK: -
typedef struct {
	uint64_t graphics[2];
	uint8_t control;
	
	bool is_reflected;
	bool is_score_mode_on;
	bool has_priority;
} racer_playfield;

bool playfield_needs_drawing(const racer_playfield *playfield, int position);

#define PLAYFIELD_REFLECTED (1<<0)
#define PLAYFIELD_SCORE_MODE (1<<1)
#define PLAYFIELD_PRIORITY (1<<2)


// MARK: -
uint8_t reflect_graphics(uint8_t graphics);

#define reset_position(object) \
	object.position = 160-4

#define advance_position(object) \
	object.position += 1; \
	if (object.position == 160) { \
		object.position = 0; \
	}

#endif /* graphics_h */

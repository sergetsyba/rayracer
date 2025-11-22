//
//  tia.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef tia_h
#define tia_h

#include <stdbool.h>

#include "objects/player.h"
#include "objects/player.h"
#include "objects/missile.h"
#include "objects/ball.h"
#include "objects/playfield.h"

typedef struct {
	rr_player players[2];
	rr_missile missiles[2];
	rr_ball ball;
	rr_playfield playfield;
	
	int color_clock;
	int flags;
	int colors[4];
	int collisions;
	
	int input;
	int output;
} rr_tia;

typedef enum {
	TIA_WAIT_ON_HORIZONTAL_SYNC = 1 << 0,
	TIA_APPLY_MOTION = 1 << 1
} rr_tia_flag;

typedef enum {
	TIA_OUTPUT_BLANK = 1 << 8,
	TIA_OUTPUT_HORIZONTAL_SYNC = 1 << 9,
	TIA_OUTPUT_VERTICAL_SYNC = 1 << 10
} rr_tia_output_flag;


rr_tia* rr_tia_init(void);
void rr_tia_advance_clock(rr_tia *tia);

int rr_tia_read(rr_tia tia, int address);
void rr_tia_write(rr_tia *tia, int address, int data);

#endif /* tia_h */

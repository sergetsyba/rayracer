//
//  tia.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef tia_h
#define tia_h

#include <stdbool.h>

#include "player.h"
#include "missile.h"
#include "ball.h"
#include "playfield.h"

typedef struct {
	rr_player players[2];
	rr_missile missiles[2];
	rr_ball ball;
	rr_playfield playfield;
	
	bool awaits_horizontal_sync;
	int color_clock;
	int blank_reset_clock;
	
	int is_blanking;
	int colors[4];
	int collisions;
	
	int input;
	int output;
} rr_tia;

rr_tia* rr_tia_init(void);
void rr_tia_advance_clock(rr_tia *tia);

int rr_tia_read(rr_tia tia, int address);
void rr_tia_write(rr_tia *tia, int address, int data);

#endif /* tia_h */

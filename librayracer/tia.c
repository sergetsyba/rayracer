//
//  tia.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include <stdlib.h>
#include <stdio.h>

#include "tia.h"
#include "flags.h"
#include "object.h"


// MARK: Initialization
static int get_object_index(int state);
static int object_indexes[256];
static int collistions[256];

static int reflect(int graphics) {
	int reflected = 0;
	for (int bit = 0; bit < 8; ++bit) {
		if (graphics & 0x1) {
			reflected |= (1 << (7 - bit));
		}
		graphics >>= 1;
	}
	
	return reflected;
}

rr_tia* rr_tia_init(void) {
	// initialize object draw state/object indexes look up
	for (int state = 0x00; state <= 0xff; ++state) {
		object_indexes[state] = get_object_index(state);
	}
	
	// initialize graphics reflections look up
	for (int graphics = 0x00; graphics <= 0xff; ++graphics) {
		reflections[graphics] = reflect(graphics);
	}
	
	rr_tia* tia = (rr_tia *)malloc(sizeof(rr_tia));
	tia->color_clock = 0;
	tia->flags = 0;
	tia->output = 0x700;
	
	return tia;
}

static int get_object_index(int state) {
	if (state & 0b0101) {
		// player 0/missile 0
		return 0;
	} else if (state & 0b1010) {
		// player 1/missile 1
		return 1;
	} else if (state & 0x30) {
		// ball/playefield
		// TODO: check priority
		return 2;
	} else {
		// background
		return 3;
	}
}


// MARK: -
// MARK: Drawing
static int get_draw_state(rr_tia tia) {
	return (rr_player_needs_drawing(tia.players[0]) << 0)
	| (rr_player_needs_drawing(tia.players[1]) << 1)
	| (rr_missile_needs_drawing(tia.missiles[0]) << 2)
	| (rr_missile_needs_drawing(tia.missiles[1]) << 3)
	| (rr_ball_needs_drawing(tia.ball) << 4)
	| (playfield_needs_drawing(tia.playfield, tia.color_clock - 68) << 5);
}

void rr_tia_advance_clock(rr_tia *tia) {
	// update horizontal blanking
	const int reset_clock = tia->flags & TIA_APPLY_MOTION ? 68+8 : 68;
	const bool blank = tia->color_clock < reset_clock;
	add_flag(tia->flags, TIA_OUTPUT_BLANK, blank);
	
	int color = 0x00;
	if (blank) {
		// position counters of movable objects do not receive clock
		// signals during horizontal blanking/retrace
	} else {
		// get state of all graphics objects
		const int state = get_draw_state(*tia);
		
		// update graphics objects collisions
		tia->collisions |= collistions[state];
		
		// get output color
		if (!(tia->output & TIA_OUTPUT_BLANK)) {
			const int index = object_indexes[state];
			color = tia->colors[index];
		}
		
		// advance position counters of graphics objects
		advance_position(tia->players[0]);
		advance_position(tia->players[1]);
		advance_position(tia->missiles[0]);
		advance_position(tia->missiles[1]);
		advance_position(tia->ball);
	}
	
	// update output color and horizontal sync
	tia->output &= 0xff01;
	tia->output |= color;
	set_flag(tia->output, TIA_OUTPUT_HORIZONTAL_SYNC, blank);
	
	// advance color clock
	tia->color_clock += 1;
	
	// reset scan line
	if (tia->color_clock == 228) {
		tia->color_clock = 0;
		clear_flag(tia->flags, TIA_WAIT_ON_HORIZONTAL_SYNC | TIA_APPLY_MOTION);
	}
}


// MARK: -
// MARK: Bus integration
static void apply_motion(rr_tia *tia) {
	const int remaining_clock = (68+8)-7 - tia->color_clock;
	if (remaining_clock < 0) {
		// ignore horizontal motion when HMOVE strobed late during
		// horizontal blanking interval or during visible portion of
		// a scan line
		return;
	}
	
	// calculate maximum amount of horizontal motion, which could be
	// applied during horizontal blanking interval
	const int ripples = remaining_clock >> 2;		// remaining_clock / 4;
	move(tia->players[0], ripples);
	move(tia->players[1], ripples);
	move(tia->missiles[0], ripples);
	move(tia->missiles[1], ripples);
	move(tia->ball, ripples);
}


int rr_tia_read(rr_tia tia, int address) {
	switch (address % 0x10) {
		case 0x00: // MARK: cxm0p
			return ((tia.collisions & 0x3) << 6) | address;
		case 0x01: // MARK: cxm1p
			return ((tia.collisions & 0xc) << 4) | address;
		case 0x02: // MARK: cxp0fb
			return ((tia.collisions & 0x30) << 2) | address;
		case 0x03: // MARK: cxp1fb
			return (tia.collisions & 0xc0) | address;
		case 0x04: // MARK: cxm0fb
			return ((tia.collisions & 0x300) >> 2) | address;
		case 0x05: // MARK: cxm1fb
			return ((tia.collisions & 0xc00) >> 4) | address;
		case 0x06: // MARK: cxblpf
			return ((tia.collisions & 0x1000) >> 5) | address;
		case 0x07: // MARK: cxppmm
			return ((tia.collisions & 0x6000) >> 7) | address;
			
		case 0x08: // MARK: inpt0
			return (tia.input << 7) & 0x80;
		case 0x09: // MARK: inpt1
			return (tia.input << 6) & 0x80;
		case 0x0a: // MARK: inpt2
			return (tia.input << 5) & 0x80;
		case 0x0b: // MARK: inpt3
			return (tia.input << 4) & 0x80;
		default:
			return rand() & 0xff;
	}
}

void rr_tia_write(rr_tia *tia, int address, int data) {
	switch (address) {
		case 0x00:	// MARK: vsync
			set_flag(tia->output, TIA_OUTPUT_VERTICAL_SYNC, data & 0x2);
			break;
			
		case 0x01:	// MARK: vblank
			set_flag(tia->output, TIA_OUTPUT_BLANK, data & 0x2);
			break;
			
		case 0x02:	// MARK: wsync
			// NOTE: when last CPU clock cycle of a write instruction coincides
			// with last three TIA color clocks in a scan line, WSYNC will
			// incorrectly stay on for an extra scanline, since it is reset at
			// the end of each TIA color clock cycle emulation, but the writing
			// CPU clock cycle is executed after that in console clock
			// emulation;
			// ensuring color clock is not reset guards against this edge case
			set_flag(tia->flags, TIA_WAIT_ON_HORIZONTAL_SYNC, (bool)(tia->color_clock > 0));
			break;
			
		case 0x03:	// MARK: rsync
			tia->color_clock = 0;
			break;
			
		case 0x04: {// MARK: nusiz0
			const int *mode = copy_modes[data & 0x7];
			tia->players[0].copy_mask = mode[0];
			tia->players[0].scale = mode[1];
			
			const int scale = (data >> 4) & 0x3;
			tia->missiles[0].copy_mask = mode[0];
			tia->missiles[0].size = 1 << scale;
			break;
		}
		case 0x05: {// MARK: nusiz1
			const int *mode = copy_modes[data & 0x7];
			tia->players[1].copy_mask = mode[0];
			tia->players[1].scale = mode[1];
			
			const int scale = (data >> 4) & 0x3;
			tia->missiles[1].copy_mask = mode[0];
			tia->missiles[1].size = 1 << scale;
			break;
		}
			
		case 0x06:	// MARK: colup0
			tia->colors[0] = data;
			break;
		case 0x07:	// MARK: colup1
			tia->colors[1] = data;
			break;
		case 0x08:	// MARK: colupf
			tia->colors[2] = data;
			break;
		case 0x09:	// MARK: colubk
			tia->colors[3] = data;
			break;
			
		case 0x0a:	// MARK: ctrlpf
			set_playfield_flags(&tia->playfield, data & 0x3);
			tia->ball.size = 1 << ((data >> 4) & 0x3);
			break;
			
		case 0x0d: // MARK: pf0
			set_playfield_graphics(&tia->playfield, (data >> 4) | (tia->playfield.graphics & 0x0f), 0);
			break;
		case 0x0e: // MARK: pf1
			set_playfield_graphics(&tia->playfield, reflections[data], 4);
			break;
		case 0x0f:	// MARK: pf2
			set_playfield_graphics(&tia->playfield, data, 16);
			break;
			
		case 0x0b:	// MARK: refp0
			set_flag(tia->players[0].flags, PLAYER_REFLECTED, data & 0x8);
			break;
		case 0x0c:	// MARK: refp1
			set_flag(tia->players[1].flags, PLAYER_REFLECTED, data & 0x8);
			break;
		case 0x10:	// MARK: resp0
			reset_position(tia->players[0]);
			break;
		case 0x11:	// MARK: resp1
			reset_position(tia->players[1]);
			break;
		case 0x12:	// MARK: resm0
			reset_position(tia->missiles[0]);
			break;
		case 0x13:	// MARK: resm1
			reset_position(tia->missiles[1]);
			break;
		case 0x14:	// MARK: resbl
			reset_position(tia->ball);
			break;
			
		case 0x1b:	// MARK: grp0
			tia->players[0].graphics[0] = data;
			tia->players[1].graphics[1] = tia->players[1].graphics[0];
			break;
			
		case 0x1c:	// MARK: grp1
			tia->players[1].graphics[0] = data;
			tia->players[0].graphics[1] = tia->players[0].graphics[0];
			tia->ball.is_enabled[1] = tia->ball.is_enabled[0];
			break;
			
		case 0x1d:	// MARK: enam0
			set_flag(tia->missiles[0].flags, MISSILE_ENABLED, data & 0x2);
			break;
		case 0x1e:	// MARK: enam1
			set_flag(tia->missiles[1].flags, MISSILE_ENABLED, data & 0x2);
			break;
		case 0x1f:	// MARK: enabl
			tia->ball.is_enabled[0] = data & 0x2;
			break;
			
		case 0x20:	// MARK: hmp0
			tia->players[0].motion = (data >> 4) ^ 0x8;
			break;
		case 0x21:	// MARK: hmp1
			tia->players[1].motion = (data >> 4) ^ 0x8;
			break;
		case 0x22:	// MARK: hmm0
			tia->missiles[0].motion = (data >> 4) ^ 0x8;
			break;
		case 0x23:	// MARK: hmm1
			tia->missiles[1].motion = (data >> 4) ^ 0x8;
			break;
		case 0x24:	// MARK: hmbl
			tia->ball.motion = (data >> 4) ^ 0x8;
			break;
			
		case 0x25:	// MARK: vdelp0
			set_flag(tia->players[0].flags, PLAYER_DELAYED, data & 0x1);
			break;
		case 0x26:	// MARK: vdelp1
			set_flag(tia->players[1].flags, PLAYER_DELAYED, data & 0x1);
			break;
		case 0x27:	// MARK: vdelbl
			tia->ball.is_delayed = data & 0x1;
			break;
			
		case 0x28:	// MARK: resmp0
			set_flag(tia->missiles[0].flags, MISSILE_RESET_TO_PLAYER, data & 0x2);
			break;
		case 0x29:	// MARK: resmp1
			set_flag(tia->missiles[1].flags, MISSILE_RESET_TO_PLAYER, data & 0x2);
			break;
			
		case 0x2a:	// MARK: hmove
			set_flag(tia->flags, TIA_APPLY_MOTION, 1);
			apply_motion(tia);
			break;
			
		case 0x2b:	// MARK: hmclr
			clear_motion(tia->players[0]);
			clear_motion(tia->players[1]);
			clear_motion(tia->missiles[0]);
			clear_motion(tia->missiles[1]);
			clear_motion(tia->ball);
			break;
			
		case 0x2c:	// MARK: cxclr
			tia->collisions = 0;
			break;
			
		default:
			break;
	}
}

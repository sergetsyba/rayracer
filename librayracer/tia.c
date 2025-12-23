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

// MARK: -
// MARK: Input port
void racer_tia_write_port(racer_tia *tia, uint8_t data) {
	// latch 0 on pins 4,5 when port latch enabled
	if (!(tia->input_control & TIA_INPUT_PORT_LATCH)) {
		tia->input_latch &= (data & 0xc0);
	}
}


// MARK: -
// MARK: Bus
#define min(a, b) a < b ? a : b
#define move(object, limit) object.position += min(object.motion, limit)

static void apply_motion(racer_tia *tia) {
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

static uint8_t color_indexes[0x200];
static uint16_t collisions[0x40];

uint8_t racer_tia_read(const racer_tia *tia, uint8_t address) {
	switch (address % 0x10) {
		case 0x00: {// MARK: cxm0p
			const uint8_t data = (tia->collisions >> 0) & 0x3;
			return (data << 6) | address;
		}
		case 0x01: {// MARK: cxm1p
			const uint8_t data = (tia->collisions >> 2) & 0x3;
			return (data << 6) | address;
		}
		case 0x02: {// MARK: cxp0fb
			const uint8_t data = (tia->collisions >> 4) & 0x3;
			return (data << 6) | address;
		}
		case 0x03: {// MARK: cxp1fb
			const uint8_t data = (tia->collisions >> 6) & 0x3;
			return (data << 6) | address;
		}
		case 0x04: {// MARK: cxm0fb
			const uint8_t data = (tia->collisions >> 8) & 0x3;
			return (data << 6) | address;
		}
		case 0x05: {// MARK: cxm1fb
			const uint8_t data = (tia->collisions >> 10) & 0x3;
			return (data << 6) | address;
		}
		case 0x06: {// MARK: cxblpf
			const uint8_t data = (tia->collisions >> 12) & 0x1;
			return (data << 6) | address;
		}
		case 0x07: {// MARK: cxppmm
			const uint8_t data = (tia->collisions >> 14) & 0x3;
			return (data << 6) | address;
		}
			
		case 0x08: {// MARK: inpt0
			const uint8_t data = tia->read_port(tia->peripheral);
			return (data << 7) & 0x80;
		}
		case 0x09: {// MARK: inpt1
			const uint8_t data = tia->read_port(tia->peripheral);
			return (data << 6) & 0x80;
		}
		case 0x0a: {// MARK: inpt2
			const uint8_t data = tia->read_port(tia->peripheral);
			return (data << 5) & 0x80;
		}
		case 0x0b: {// MARK: inpt3
			const uint8_t data = tia->read_port(tia->peripheral);
			return (data << 4) & 0x80;
		}
		case 0x0c: {// MARK: inpt4
			const uint8_t data = (tia->input_control & TIA_INPUT_PORT_LATCH)
			? tia->input_latch
			: tia->read_port(tia->peripheral);
			
			return (data << 3) & 0x80;
		}
		case 0x0d: {// MARK: inpt5
			const uint8_t data = (tia->input_control & TIA_INPUT_PORT_LATCH)
			? tia->input_latch
			: tia->read_port(tia->peripheral);
			
			return (data << 2) & 0x80;
		}
		default:
			return arc4random_uniform(0x100);
	}
}

static uint8_t reflections[0x100];
static uint16_t copy_modes[][2] = {
	{0x001, 0},	// ●○○○○○○○○○
	{0x005, 0},	// ●○●○○○○○○○
	{0x011, 0},	// ●○○●○○○○○○
	{0x015, 0},	// ●○●○●○○○○○
	{0x101, 0},	// ●○○○○○○○●○
	{0x001, 1},	// ●●○○○○○○○○
	{0x111, 0},	// ●○○○●○○○●○
	{0x001, 2}	// ●●●●○○○○○○
};

void racer_tia_write(racer_tia *tia, uint8_t address, uint8_t data) {
	switch (address) {
		case 0x00:	{// MARK: vsync
			const bool vertical_sync = data & 0x2;
			set_flag(tia->output_control, TIA_OUTPUT_VERTICAL_SYNC, vertical_sync);
			
			// notify video output when vertical sync enabled
			if (vertical_sync) {
				tia->sync_video_output(tia->output, TIA_OUTPUT_VERTICAL_SYNC);
			}
			break;
		}
			
		case 0x01: {// MARK: vblank
			// vertical blanking
			const bool vertical_blank = data & 0x2;
			set_flag(tia->output_control, TIA_OUTPUT_VERTICAL_BLANK, vertical_blank);
			
			// input control
			tia->input_control = data & 0xc0;
			// reset input latches when input port I4-I5 latching is disabled;
			// both values are reset to 1
			if (!(tia->input_control & TIA_INPUT_PORT_LATCH)) {
				tia->input_latch = 0x30;
			}
			break;
		}
			
		case 0x02:	// MARK: wsync
			// when the last clock cycle of WSYNC write instruction coincides
			// with the last color clock of a scan line (which resets color
			// clock to 0), WSYNC should not be enabled
			if (tia->color_clock != 0) {
				*tia->is_ready = false;
			}
			break;
			
		case 0x03:	// MARK: rsync
			// FIXME: RSYNC
			tia->color_clock = -6;
			break;
			
		case 0x04: {// MARK: nusiz0
			const uint16_t *copy_mode = copy_modes[data & 0x7];
			tia->players[0].copy_mask = copy_mode[0];
			tia->players[0].scale = copy_mode[1];
			
			const int missile_scale = (data >> 4) & 0x3;
			tia->missiles[0].copy_mask = copy_mode[0];
			tia->missiles[0].size = 1 << missile_scale;
			break;
		}
		case 0x05: {// MARK: nusiz1
			const uint16_t *copy_mode = copy_modes[data & 0x7];
			tia->players[1].copy_mask = copy_mode[0];
			tia->players[1].scale = copy_mode[1];
			
			const int missile_scale = (data >> 4) & 0x3;
			tia->missiles[1].copy_mask = copy_mode[0];
			tia->missiles[1].size = 1 << missile_scale;
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
			tia->playfield.control = data & 0x3;
			tia->ball.size = 1 << ((data >> 4) & 0x3);
			break;
			
		case 0x0d: {// MARK: pf0
			const uint64_t graphics = data >> 4;
			tia->playfield.graphics[0] &= 0xffff0ffff0;
			tia->playfield.graphics[0] |= graphics | (graphics << 20);
			
			const uint64_t reflected = reflections[graphics];
			tia->playfield.graphics[1] &= 0x0fffffff0;
			tia->playfield.graphics[1] |= graphics | (reflected << (40-8));
			break;
		}
		case 0x0e: {// MARK: pf1
			const uint64_t graphics = reflections[data];
			tia->playfield.graphics[0] &= 0xff00fff00f;
			tia->playfield.graphics[0] |= (graphics << 4) | (graphics << (20+4));
			
			const uint64_t reflected = data;
			tia->playfield.graphics[1] &= 0xf00ffff00f;
			tia->playfield.graphics[1] |= (graphics << 4) | (reflected << (20+8));
			break;
		}
		case 0x0f: {// MARK: pf2
			const uint64_t graphics = data;
			tia->playfield.graphics[0] &= 0x00fff00fff;
			tia->playfield.graphics[0] |= (graphics << 12) | (graphics << (20+12));
			
			const uint64_t reflected = reflections[data];
			tia->playfield.graphics[1] &= 0xfff0000fff;
			tia->playfield.graphics[1] |= (graphics << 12) | (reflected << 20);
			break;
		}
			
		case 0x0b:	// MARK: refp0
			set_flag(tia->players[0].control, PLAYER_REFLECTED, !(data & 0x8));
			break;
		case 0x0c:	// MARK: refp1
			set_flag(tia->players[1].control, PLAYER_REFLECTED, !(data & 0x8));
			break;
		case 0x10:	// MARK: resp0
			reset_player_position(&tia->players[0]);
			break;
		case 0x11:	// MARK: resp1
			reset_player_position(&tia->players[1]);
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
			// set player 0 graphics
			tia->players[0].graphics[0] = data;
			tia->players[0].graphics[1] = reflections[data];
			// copy player 1 delayed graphics
			tia->players[1].graphics[2] = tia->players[1].graphics[0];
			tia->players[1].graphics[3] = tia->players[1].graphics[1];
			break;
			
		case 0x1c:	// MARK: grp1
			// set player 1 graphics
			tia->players[1].graphics[0] = data;
			tia->players[1].graphics[1] = reflections[data];
			// copy player 0 delayed graphics
			tia->players[0].graphics[2] = tia->players[0].graphics[0];
			tia->players[0].graphics[3] = tia->players[0].graphics[1];
			
			// copy ball delayed control flag
			tia->ball.control &= ~BALL_ENABLED_1;
			tia->ball.control |= (bool)(tia->ball.control & BALL_ENABLED_0);
			break;
			
		case 0x1d:	// MARK: enam0
			set_flag(tia->missiles[0].control, MISSILE_ENABLED, data & 0x2);
			break;
		case 0x1e:	// MARK: enam1
			set_flag(tia->missiles[1].control, MISSILE_ENABLED, data & 0x2);
			break;
		case 0x1f:	// MARK: enabl
			set_flag(tia->ball.control, BALL_ENABLED_0, data & 0x2);
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
			set_flag(tia->players[0].control, PLAYER_DELAYED, data & 0x1);
			break;
		case 0x26:	// MARK: vdelp1
			set_flag(tia->players[1].control, PLAYER_DELAYED, data & 0x1);
			break;
		case 0x27:	// MARK: vdelbl
			set_flag(tia->ball.control, BALL_DELAYED, data & 0x1);
			break;
			
		case 0x28:	// MARK: resmp0
			set_missile_reset_to_player(&tia->missiles[0], &tia->players[0], data & 0x2);
			break;
		case 0x29:	// MARK: resmp1
			set_missile_reset_to_player(&tia->missiles[1], &tia->players[1], data & 0x2);
			break;
			
		case 0x2a:	// MARK: hmove
			tia->blank_reset_clock = 68+8;
			apply_motion(tia);
			break;
			
		case 0x2b:	// MARK: hmclr
			tia->players[0].motion = 0;
			tia->players[1].motion = 0;
			tia->missiles[0].motion = 0;
			tia->missiles[1].motion = 0;
			tia->ball.motion = 0;
			break;
			
		case 0x2c:	// MARK: cxclr
			tia->collisions = 0;
			break;
			
		default:
			break;
	}
}


// MARK: -
// MARK: Drawing
static uint16_t get_graphics_state(const racer_tia *tia) {
	// right screen half
	const int position = tia->color_clock - 68;
	uint16_t state = position >= 80;
	
	// playfield score mode and priority
	state |= (tia->playfield.control & 0x6);
	
	// graphics objects
	state |= player_needs_drawing(&tia->players[0]) << 3;
	state |= player_needs_drawing(&tia->players[1]) << 4;
	state |= missile_needs_drawing(&tia->missiles[0]) << 5;
	state |= missile_needs_drawing(&tia->missiles[1]) << 6;
	state |= ball_needs_drawing(&tia->ball) << 7;
	state |= playfield_needs_drawing(&tia->playfield, position) << 8;
	
	return state;
}

#define RIGHT_SCREEN_HALF (1<<0)
#define PLAYER_0 (1<<3)
#define PLAYER_1 (1<<4)
#define MISSILE_0 (1<<5)
#define MISSILE_1 (1<<6)
#define BALL (1<<7)
#define PLAYFIELD (1<<8)

static int get_color_index(uint16_t state) {
	if ((state & (PLAYFIELD | PLAYFIELD_SCORE_MODE | PLAYFIELD_PRIORITY)) ==
		(PLAYFIELD | PLAYFIELD_PRIORITY)) {
		// playfield priority (score mode off)
		return 2;
	} else if (state & (PLAYER_0 | MISSILE_0)) {
		// player 0/missile 0
		return 0;
	} else if (state & (PLAYER_1 | MISSILE_1)) {
		// player 1/missile 1
		return 1;
	} else if (state & BALL) {
		// ball
		return 2;
	} else if (state & PLAYFIELD) {
		if (state & PLAYFIELD_SCORE_MODE) {
			// score mode (players)
			return (state & RIGHT_SCREEN_HALF) ? 1 : 0;
		} else {
			// playefield
			return 2;
		}
	} else {
		// background
		return 3;
	}
}

#define collide(state, object1, object2) \
((state & (object1 | object2)) == (object1 | object2))

static uint16_t get_collisions(uint16_t state) {
	// cxm0p
	return collide(state, MISSILE_0, PLAYER_0)
	| collide(state, MISSILE_0, PLAYER_1) << 1
	// cxm1p
	| collide(state, MISSILE_1, PLAYER_1) << 2
	| collide(state, MISSILE_1, PLAYER_0) << 3
	// cxp0fb
	| collide(state, PLAYER_0, BALL) << 4
	| collide(state, PLAYER_0, PLAYFIELD) << 5
	// cxp1fb
	| collide(state, PLAYER_1, BALL) << 6
	| collide(state, PLAYER_1, PLAYFIELD) << 7
	// cxm0fb
	| collide(state, MISSILE_0, BALL) << 8
	| collide(state, MISSILE_0, PLAYFIELD) << 9
	// cxm1fb
	| collide(state, MISSILE_1, BALL) << 10
	| collide(state, MISSILE_1, PLAYFIELD) << 11
	// cxblpf
	| collide(state, BALL, PLAYFIELD) << 12
	// cxppmm
	| collide(state, MISSILE_0, MISSILE_1) << 14
	| collide(state, PLAYER_0, PLAYER_1) << 15;
}


// MARK: -
void racer_tia_reset(racer_tia *tia) {
	tia->color_clock = 0;
	*tia->is_ready = true;
	tia->blank_reset_clock = 68;
	
	tia->output_control = 0x00;
	tia->input_control = 0x00;
	tia->input_latch = 0xc0;
}

void racer_tia_advance_clock(racer_tia *tia) {
	const bool horizontal_blank = tia->color_clock < tia->blank_reset_clock;
	uint8_t color = horizontal_blank;
	
	// position counters of movable objects do not receive clock signals
	// during horizontal blanking/retrace; no need to re-calculate draw state
	// and update object collisions
	if (!horizontal_blank) {
		const uint16_t state = get_graphics_state(tia);
		
		// set output color unless TIA ouputs blank
		const bool vertical_blank = tia->output_control & TIA_OUTPUT_VERTICAL_BLANK;
		color |= vertical_blank;
		
		if (!vertical_blank) {
			const int index = color_indexes[state];
			color = tia->colors[index];
		}
		
		// update collisions
		tia->collisions |= collisions[state >> 3];
		
		// advance position counters of graphics objects
		advance_player_position(&tia->players[0]);
		advance_player_position(&tia->players[1]);
		advance_position(tia->missiles[0]);
		advance_position(tia->missiles[1]);
		advance_position(tia->ball);
	}
	
	const uint16_t sync = (tia->output_control & 0x2) | (tia->color_clock < 68);
	tia->write_video_output(tia->output, (sync << 8) | color);
	tia->color_clock += 1;
	
	// reset scan line
	if (tia->color_clock == 228) {
		tia->color_clock = 0;
		*tia->is_ready = true;
		tia->blank_reset_clock = 68;
		
		// notify video output horizontal sync started
		tia->sync_video_output(tia->output, TIA_OUTPUT_HORIZONTAL_SYNC);
	}
}

void racer_init_graphics(void) {
	for (uint16_t state = 0x00; state < 0x200; ++state) {
		color_indexes[state] = get_color_index(state);
	}
	for (int state = 0x00; state < 0x40; ++state) {
		collisions[state] = get_collisions(state << 3);
	}
	for (int graphics = 0x00; graphics < 0x100; ++graphics) {
		reflections[graphics] = reflect_graphics(graphics);
	}
}

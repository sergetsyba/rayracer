//
//  tia.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include <stdlib.h>
#include <stdio.h>

#include "tia.h"
#include "object.h"
#include "flags.h"

// MARK: Initialization
static int get_object_index(int state);
static int object_indexes[0x100];
static int get_collisions(int state);
static int collisions[0x200];

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

void racer_tia_init(void) {
	// initialize graphics reflections look up
	for (int graphics = 0x00; graphics <= 0xff; ++graphics) {
		reflections[graphics] = reflect(graphics);
	}
	
	// initialize object draw state/object indexes look up
	for (int state = 0x00; state <= 0xff; ++state) {
		object_indexes[state] = get_object_index(state);
	}
	
	// initialize collisions look up
	for (int state = 0x00; state < 0x1ff; ++state) {
		collisions[state] = get_collisions(state);
	}
}

void racer_tia_reset(racer_tia *tia) {
	tia->color_clock = 0;
	*tia->is_ready = true;
	tia->blank_reset_clock = 68;
	
	tia->output_control = 0x00;
	tia->input_control = 0x00;
	tia->input_latch = 0xc0;
}

#define state_player_0 (1 << 0)
#define state_missile_0 (1 << 1)
#define state_player_1 (1 << 2)
#define state_missile_1 (1 << 3)
#define state_ball (1 << 4)
#define state_playfield (1 << 5)
#define state_score_mode (1 << 6)
#define state_playfield_priority (1 << 7)
#define state_right_half (1 << 8)

static int get_object_index(int state) {
	if (state & (state_playfield | state_playfield_priority)
		&& !(state & state_score_mode)) {
		// playfield priority (score mode off)
		return 2;
	} else if (state & (state_player_0 | state_missile_0)) {
		// player 0/missile 0
		return 0;
	} else if (state & (state_player_1 | state_missile_1)) {
		// player 1/missile 1
		return 1;
	} else if (state & state_ball) {
		// ball
		return 2;
	} else if (state & state_playfield) {
		// playefield
		if (state & state_score_mode) {
			// score mode
			return (state & state_right_half) ? 1 : 0;
		} else {
			return 2;
		}
	} else {
		// background
		return 3;
	}
}

#define is_set(data, mask) (((data) & (mask)) == (mask))

static int get_collisions(int state) {
	return 0x00
	| is_set(state, state_missile_0 | state_player_0) << 0
	| is_set(state, state_missile_0 | state_player_1) << 1
	| is_set(state, state_missile_1 | state_player_0) << 2
	| is_set(state, state_missile_1 | state_player_1) << 3
	| is_set(state, state_player_0 | state_ball) << 4
	| is_set(state, state_player_0 | state_playfield) << 5
	| is_set(state, state_player_1 | state_ball) << 6
	| is_set(state, state_player_1 | state_playfield) << 7
	| is_set(state, state_missile_0 | state_ball) << 8
	| is_set(state, state_missile_0 | state_playfield) << 9
	| is_set(state, state_missile_1 | state_ball) << 10
	| is_set(state, state_missile_1 | state_playfield) << 11
	| is_set(state, state_ball | state_playfield) << 12
	| is_set(state, state_missile_0 | state_missile_1) << 13
	| is_set(state, state_player_0 | state_player_1) << 14;
}


// MARK: -
// MARK: Drawing
static int get_draw_state(racer_tia tia) {
	return (rr_player_needs_drawing(tia.players[0]) << 0)
	| (rr_player_needs_drawing(tia.players[1]) << 1)
	| (rr_missile_needs_drawing(tia.missiles[0]) << 2)
	| (rr_missile_needs_drawing(tia.missiles[1]) << 3)
	| (rr_ball_needs_drawing(tia.ball) << 4)
	| (playfield_needs_drawing(tia.playfield, tia.color_clock - 68) << 5);
}

void racer_tia_advance_clock(racer_tia *tia) {
	const bool horizontal_blank = tia->color_clock < tia->blank_reset_clock;
	uint8_t color = horizontal_blank;
	
	// position counters of movable objects do not receive clock signals
	// during horizontal blanking/retrace; no need to re-calculate draw state
	// and update object collisions
	if (!horizontal_blank) {
		const uint8_t state = get_draw_state(*tia);
		tia->collisions |= collisions[state];
		
		// set output color unless TIA ouputs blank
		const bool vertical_blank = tia->output_control & TIA_OUTPUT_VERTICAL_BLANK;
		color |= vertical_blank;
		
		if (!vertical_blank) {
			const int index = object_indexes[state];
			color |= tia->colors[index];
		}
		
		// advance position counters of graphics objects
		advance_position(tia->players[0]);
		advance_position(tia->players[1]);
		advance_position(tia->missiles[0]);
		advance_position(tia->missiles[1]);
		advance_position(tia->ball);
	}
	
	const uint8_t horizontal_sync = tia->color_clock < 68;
	const uint8_t vertical_sync = tia->output_control & 0x2;
	const uint16_t signal = ((horizontal_sync | vertical_sync) << 8) | color;
	
	tia->write_video_output(tia->output, signal);
	tia->color_clock += 1;
	
	// reset scan line
	if (tia->color_clock == 228) {
		tia->color_clock = 0;
		*tia->is_ready = true;
		tia->blank_reset_clock = 68;
		
		// notify video output horizontal sync started
		const u_int8_t sync = TIA_OUTPUT_HORIZONTAL_SYNC | vertical_sync;
		tia->sync_video_output(tia->output, sync);
	}
}


// MARK: -
// MARK: Input port
void racer_tia_write_port(racer_tia *tia, uint8_t data) {
	// latch 0 on pins 4,5 when port latch enabled
	if (!is_flag_set(tia->input_control, TIA_INPUT_PORT_LATCH)) {
		tia->input_latch &= (data & 0xc0);
	}
}

// MARK: -
// MARK: Bus integration
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
			return (data << 7) | address;
		}
		case 0x07: {// MARK: cxppmm
			const uint8_t data = (tia->collisions >> 13) & 0x3;
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
			const uint8_t data = is_flag_set(tia->input_control, TIA_INPUT_PORT_LATCH)
			? tia->input_latch
			: tia->read_port(tia->peripheral);
			
			return (data << 3) & 0x80;
		}
		case 0x0d: {// MARK: inpt5
			const uint8_t data = is_flag_set(tia->input_control, TIA_INPUT_PORT_LATCH)
			? tia->input_latch
			: tia->read_port(tia->peripheral);
			
			return (data << 2) & 0x80;
		}
		default:
			return arc4random_uniform(0x100);
	}
}

void racer_tia_write(racer_tia *tia, uint8_t address, uint8_t data) {
	switch (address) {
		case 0x00:	{// MARK: vsync
			const bool vertical_sync = data & 0x2;
			set_flag(tia->output_control, TIA_OUTPUT_VERTICAL_SYNC, vertical_sync);
			
			// notify video output when vertical sync enabled
			if (vertical_sync) {
				const uint8_t sync = vertical_sync | (tia->color_clock < 68);
				tia->sync_video_output(tia->output, sync);
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
			if (!is_flag_set(tia->input_control, TIA_INPUT_PORT_LATCH)) {
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
			set_playfield_control(&tia->playfield, data & 0x3);
			tia->ball.size = 1 << ((data >> 4) & 0x3);
			break;
			
		case 0x0d: // MARK: pf0
			set_playfield_graphics(&tia->playfield, data, 0);
			break;
		case 0x0e: // MARK: pf1
			set_playfield_graphics(&tia->playfield, reflections[data], 1);
			break;
		case 0x0f:	// MARK: pf2
			set_playfield_graphics(&tia->playfield, data, 2);
			break;
			
		case 0x0b:	// MARK: refp0
			set_player_reflected(&tia->players[0], data & 0x8);
			break;
		case 0x0c:	// MARK: refp1
			set_player_reflected(&tia->players[1], data & 0x8);
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
			set_player_graphics(&tia->players[0], data);
			tia->players[1].graphics[1] = tia->players[1].graphics[0];
			break;
			
		case 0x1c:	// MARK: grp1
			set_player_graphics(&tia->players[1], data);
			tia->players[0].graphics[1] = tia->players[0].graphics[0];
			tia->ball.is_enabled[1] = tia->ball.is_enabled[0];
			break;
			
		case 0x1d:	// MARK: enam0
			tia->missiles[0].is_enabled = data & 0x2;
			break;
		case 0x1e:	// MARK: enam1
			tia->missiles[1].is_enabled = data & 0x2;
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
			tia->players[0].is_delayed = data & 0x1;
			break;
		case 0x26:	// MARK: vdelp1
			tia->players[1].is_delayed = data & 0x1;
			break;
		case 0x27:	// MARK: vdelbl
			tia->ball.is_delayed = data & 0x1;
			break;
			
		case 0x28:	// MARK: resmp0
			tia->missiles[0].is_reset_to_player = data & 0x2;
			break;
		case 0x29:	// MARK: resmp1
			tia->missiles[1].is_reset_to_player = data & 0x2;
			break;
			
		case 0x2a:	// MARK: hmove
			tia->blank_reset_clock = 68+8;
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

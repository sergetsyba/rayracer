//
//  tia.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//
#include "tia.h"
#include "flags.h"

#include <stdlib.h>

// MARK: Object positioning
static void advance_player_position(racer_player *player) {
	player->position += 1;

	if (player->position == 160) {
		player->position = 0;
		// reset position counter of a missile, if it is reset to player
		*player->missile_position = 0;

		// clear position reset flag and enable drawing main copy
		player->control &= ~PLAYER_POSITION_RESET;
		player->copy_mask |= 0x1;
	}
}

#define advance_object_position(object) \
	(object)->position += 1; \
	if ((object)->position == 160) { \
		(object)->position = 0; \
	}

#define apply_object_motion(object) \
	(object)->position += (object)->motion ^ 0x8

#define reset_object_motion(object) \
	(object)->motion = 0

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


// MARK: -
void racer_tia_reset(racer_tia *tia) {
	tia->color_clock = 0;
	*tia->is_ready = true;
	tia->blank_reset_clock = 68;

	tia->output_control = 0x00;
	tia->input_control = 0x00;
	tia->input_latch = 0xc0;

	tia->players[0].missile_position = &null_missile_position;
	tia->players[1].missile_position = &null_missile_position;

	// TODO: send composite sync
}

void racer_tia_advance_clock(racer_tia *tia) {
	// NOTE: scan line reset check needs to happen at the beginning of
	// a color clock cycle due to simultaneous clock simulation of
	// the console
	if (tia->color_clock >= 228) {
		tia->color_clock = 0;
		*tia->is_ready = true;
		tia->blank_reset_clock = 68;

		// notify video output horizontal sync started
		tia->video_sync(tia->video_output, VIDEO_HORIZONTAL_SYNC);
	}

	const bool horizontal_blank = tia->color_clock < tia->blank_reset_clock;
	uint8_t color = horizontal_blank;

	// position counters of movable objects do not receive clock signals
	// during horizontal blanking/retrace; no need to re-calculate draw state
	// and update object collisions
	if (!horizontal_blank) {
		const uint16_t state = get_object_draw_state(tia);

		// set output color unless TIA ouputs blank
		const bool vertical_blank = tia->output_control & TIA_OUTPUT_VERTICAL_BLANK;
		color |= vertical_blank;

		if (!vertical_blank) {
			const int index = draw_indices[state];
			color = tia->colors[index];
		}

		// update collisions
		tia->collisions |= collisions[state >> 3];

		// advance position counters of graphics objects
		advance_player_position(&tia->players[0]);
		advance_player_position(&tia->players[1]);
		advance_object_position(&tia->missiles[0]);
		advance_object_position(&tia->missiles[1]);
		advance_object_position(&tia->ball);
	}

	tia->color_clock += 1;

	// sync video output when buffer is filled
	if (tia->video_buffer == tia->video_buffer_end) {
		tia->video_sync(tia->video_output, VIDEO_BUFFER_SYNC);
	}

	// write color output
	*tia->video_buffer = color;
	tia->video_buffer++;
}


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

void racer_tia_write(racer_tia *tia, uint8_t address, uint8_t data) {
	switch (address) {
		case 0x00: {// MARK: vsync
			const bool vertical_sync = data & 0x2;
			set_flag(tia->output_control, VIDEO_VERTICAL_SYNC, vertical_sync);

			// notify video output when vertical sync started
			if (vertical_sync) {
				tia->video_sync(tia->video_output, VIDEO_VERTICAL_SYNC);
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

		case 0x0a: {// MARK: ctrlpf
			tia->playfield.control = data & 0x3;
			tia->ball.size = 1 << ((data >> 4) & 0x3);
			break;
		}

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

		case 0x10: {// MARK: resp0
			// it takes 4 color clock cycles to reset position counter and
			// an extra clock cycle to latch the draw start signal
			tia->players[0].position = 160-4-1;

			// clear first bit in copy mask to skip drawing first player copy
			tia->players[0].control |= PLAYER_POSITION_RESET;
			tia->players[0].copy_mask &= ~0x1;
			break;
		}
		case 0x11: {// MARK: resp1
			tia->players[1].position = 160-4-1;
			tia->players[1].control |= PLAYER_POSITION_RESET;
			tia->players[1].copy_mask &= ~0x1;
			break;
		}
		case 0x12:	// MARK: resm0
			// it takes 4 color clock cycles to reset position counter
			tia->missiles[0].position = 160-4;
			break;
		case 0x13:	// MARK: resm1
			tia->missiles[1].position = 160-4;
			break;
		case 0x14:	// MARK: resbl
			tia->ball.position = 160-4;
			break;

		case 0x1b: {// MARK: grp0
			// set player 0 graphics
			tia->players[0].graphics[0] = data;
			tia->players[0].graphics[1] = reflections[data];

			// copy player 1 delayed graphics
			tia->players[1].graphics[2] = tia->players[1].graphics[0];
			tia->players[1].graphics[3] = tia->players[1].graphics[1];
			break;
		}

		case 0x1c: {// MARK: grp1
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
		}

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
			tia->players[0].motion = data >> 4;
			break;
		case 0x21:	// MARK: hmp1
			tia->players[1].motion = data >> 4;
			break;
		case 0x22:	// MARK: hmm0
			tia->missiles[0].motion = data >> 4;
			break;
		case 0x23:	// MARK: hmm1
			tia->missiles[1].motion = data >> 4;
			break;
		case 0x24:	// MARK: hmbl
			tia->ball.motion = data >> 4;
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

		case 0x28: {// MARK: resmp0
			if (data & 0x2) {
				tia->missiles[0].control |= MISSILE_RESET_TO_PLAYER;
				tia->players[0].missile_position = &tia->missiles[1].position;
			} else {
				tia->missiles[0].control &= ~MISSILE_RESET_TO_PLAYER;
				tia->players[0].missile_position = &null_missile_position;
			}
			break;
		}
		case 0x29: {// MARK: resmp1
			if (data & 0x2) {
				tia->missiles[1].control |= MISSILE_RESET_TO_PLAYER;
				tia->players[1].missile_position = &tia->missiles[1].position;
			} else {
				tia->missiles[1].control &= ~MISSILE_RESET_TO_PLAYER;
				tia->players[1].missile_position = &null_missile_position;
			}
			break;
		}

		case 0x2a: {// MARK: hmove
			tia->blank_reset_clock = 68+8;

			// NOTE: in hardware, horizontal motion is applied gradually,
			// 1 unit every 4 color clocks, approximately 7 color clocks
			// after HMOVE register is strobed;
			// this is a simplified simulation which applies horizontal
			// motion at once, it will produce correct results when HMOVE
			// is strobed at the beginning of a scan line, as recommended
			// by Atari 2600 programming manual
			apply_object_motion(&tia->players[0]);
			apply_object_motion(&tia->players[1]);
			apply_object_motion(&tia->missiles[0]);
			apply_object_motion(&tia->missiles[1]);
			apply_object_motion(&tia->ball);
			break;
		}

		case 0x2b: {// MARK: hmclr
			reset_object_motion(&tia->players[0]);
			reset_object_motion(&tia->players[1]);
			reset_object_motion(&tia->missiles[0]);
			reset_object_motion(&tia->missiles[1]);
			reset_object_motion(&tia->ball);
			break;
		}

		case 0x2c:	// MARK: cxclr
			tia->collisions = 0;
			break;

		default:
			break;
	}
}

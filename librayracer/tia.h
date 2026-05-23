//
//  tia.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef tia_h
#define tia_h

#include "graphics.h"

#include <stdint.h>
#include <stdbool.h>

typedef enum {
	VIDEO_HORIZONTAL_SYNC = 1<<0,
	VIDEO_VERTICAL_SYNC = 1<<1,
	VIDEO_BUFFER_SYNC = 1<<2
} racer_video_sync;

struct racer_tia {
	racer_player players[2];
	racer_missile missiles[2];
	racer_ball ball;
	racer_playfield playfield;

	int color_clock;
	uint8_t colors[4];
	uint16_t collisions;

	bool *is_ready;
	int blank_reset_clock;

	/**
	 * Reads data from the specified peripheral, connected to input port (pins I0-I5).
	 *
	 * When bit 6 of VBLANK register is set to 0, reading data at addresses $0x8-$0xd will read
	 * peripheral and return value from the corresponding pin.
	 * Otherwise, values on pins I4-I5 are latched whenever peripheral writes to input port. In this case,
	 * reading data at addresses $0x8-$0xb reads peripheral on pins I0-I3, and reading data at
	 * addresses $0x8-$0xb returns latched values.
	 */
	uint8_t (*read_port)(const void *peripheral);
	void *peripheral;

	/**
	 * Peripheral input control flags.
	 *
	 * Bit 6 denotes whether input on pins I4-I5 is latched.
	 * Bit 7 denotes whether pins I0-I3 are grounded.
	 */
	uint8_t input_control;
	uint8_t input_latch;

	/**
	 * Notifies video output when TIA starts vertical or horizontal sync or when video buffer is filled.
	 *
	 * Video output must reset video buffer on buffer sync or TIA will write the next color value past
	 * the video buffer end.
	 *
	 * This function is always called before writing the first color value of a field or scan line.
	 */
	void (*sync_video)(const void *video_output, racer_video_sync sync);
	void *video_output;

	uint8_t *video_buffer;
	uint8_t *video_buffer_end;

	/**
	 * Video output control flags.
	 *
	 * Bit 0 denotes whether vertical blanking is on.
	 * Bit 1 denotes whether vertical sync is on.
	 */
	uint8_t output_control;
};

/**
 * Resets the TIA.
 */
void racer_tia_reset(racer_tia *tia);

/**
 * Advanced TIA clock by 1 cycle.
 */
void racer_tia_advance_clock(racer_tia *tia);

#define TIA_INPUT_PORT_LATCH (1<<6)
#define TIA_INPUT_PORT_DUMP (1<<7)
#define TIA_OUTPUT_VERTICAL_BLANK (1<<0)

/**
 * Writes the specified data to the TIA input port (pins I0-I5).
 *
 * When bit 6 of VBLANK register is set to 1, pins I4 and I5 are latched into the TIA. Otherwise, writing
 * to input port has no effect.
 */
void racer_tia_write_port(racer_tia *tia, uint8_t data);

/**
 * Reads data from the TIA.
 */
uint8_t racer_tia_read(const racer_tia *tia, uint8_t address);

/**
 * Reads data to the TIA.
 */
void racer_tia_write(racer_tia *tia, uint8_t address, uint8_t data);

#endif /* tia_h */

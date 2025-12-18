//
//  tia.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef tia_h
#define tia_h

#include "objects/player.h"
#include "objects/missile.h"
#include "objects/ball.h"
#include "objects/playfield.h"

typedef enum {
	TIA_OUTPUT_HORIZONTAL_SYNC = 1<<0,
	TIA_OUTPUT_VERTICAL_SYNC = 1<<1
} racer_tia_output_sync;

typedef struct {
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
	 * Notifies video output once TIA begins vertical or horizontal sync.
	 *
	 * This function is always called before writing the first signal of a field or scan line.
	 */
	void (*sync_video_output)(const void *output, uint8_t sync);
	
	/**
	 * Writes the specified video signal value to the video output.
	 *
	 * Lower byte of the specified signal is the output color value. Bit 0 denotes whether output is blank.
	 * The higher 7 bits are the color value from the current palette; the color value is valid only when the
	 * lowest bit is 0.
	 *
	 * Higher byte of the specified signal is video output sync. Horizontal sync is controlled by console
	 * in the actual hardware; this simulation outputs horizontal sync for the first 68 color clocks of each
	 * scan line. Vertical sync is controlled by the program via VSYNC register.
	 */
	void (*write_video_output)(const void *output, uint16_t signal);
	void *output;
	
	/**
	 * Video output control flags.
	 *
	 * Bit 0 denotes whether vertical blanking is on.
	 * Bit 1 denotes whether vertical sync is on.
	 */
	uint8_t output_control;
	
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
} racer_tia;

void racer_tia_init(void);
void racer_tia_reset(racer_tia *tia);
void racer_tia_advance_clock(racer_tia *tia);

/**
 * Writes the specified data to the TIA input port (pins I0-I5).
 *
 * When bit 6 of VBLANK register is set to 1, pins I4 and I5 are latched into the TIA. Otherwise, writing
 * to input port has no effect.
 */
void racer_tia_write_port(racer_tia *tia, uint8_t data);

uint8_t racer_tia_read(const racer_tia *tia, uint8_t address);
void racer_tia_write(racer_tia *tia, uint8_t address, uint8_t data);


// MARK: -
// MARK: Output control flags
#define TIA_INPUT_PORT_LATCH (1<<6)
#define TIA_INPUT_PORT_DUMP (1<<7)

#define TIA_OUTPUT_VERTICAL_BLANK (1<<0)

#endif /* tia_h */

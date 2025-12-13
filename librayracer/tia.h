//
//  tia.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef tia_h
#define tia_h

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
	int colors[4];
	int collisions;
	
	bool *is_ready;
	int blank_reset_clock;
	
	/// Notifies video output once when TIA begins vertical or horizontal sync.
	///
	/// The specified sync value is 1 for vertical and 2 for horizontal sync. For composite sync, this
	/// function is called twice, separately for vertical and horizontal sync.
	///
	/// This function is always called before writing the first signal of a field or scan line.
	void (*sync_video_output)(const void *output, int sync);
	
	/// Writes the specified signal value to the video output.
	///
	/// The specified signal value consists of 2 bytes, with lower byte being color and higher byte is
	/// screen sync.
	///
	/// Bit 0 of the color output denotes whether output is blank or not. The higher 7 bits is the color
	/// value from the current palette. The color value is valid only when the lowest bit is 0.
	///
	/// Bit 0 of the sync output denotes vertical and bit 1 denotess horizontal sync. Vertical sync is
	/// controlled by the program via VSYNC register. Horizontal sync is controlled by console itself in
	/// the actual hardware; this simulation outputs horizontal sync for the first 68 color clocks of
	/// each scan line.
	void (*write_video_output)(const void *output, int signal);
	void *output;
	int output_control;
	
	int input;
} racer_tia;



void racer_tia_init(void);
void racer_tia_reset(racer_tia *tia);
void racer_tia_advance_clock(racer_tia *tia);

int racer_tia_read(racer_tia tia, int address);
void racer_tia_write(racer_tia *tia, int address, int data);


// MARK: -
// MARK: Output control flags
#define TIA_OUTPUT_VERTICAL_SYNC (1<<0)
#define TIA_OUTPUT_HORIZONTAL_SYNC (1<<1)
#define TIA_OUTPUT_BLANK (1<<0)

#endif /* tia_h */

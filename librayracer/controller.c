//
//  controller.c
//  librayracer
//
//  Created by Serge Tsyba on 17.12.2025.
//

#include "controller.h"

void racer_joysticks_write_output(racer_atari2600 *console, const uint8_t buttons[2]) {
	const uint16_t switches = ((buttons[0] & 0x0f) << 4) | (buttons[1] & 0x0f);
	const uint16_t input = ((buttons[0] & 0x10) >> 1) | (buttons[1] & 0x10);
	
	console->switches[0] |= ~switches;
	console->input |= ~input;
	racer_tia_write_port(console->tia, ~input);
}

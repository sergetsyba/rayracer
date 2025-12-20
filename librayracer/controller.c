//
//  controller.c
//  librayracer
//
//  Created by Serge Tsyba on 17.12.2025.
//

#include "controller.h"
#include <stdio.h>

void racer_joysticks_write_output(racer_atari2600 *console, const uint8_t buttons[2]) {
	// swcha 0-3
	console->switches[0] = (buttons[0] & 0x0f) << 4;
	console->switches[0] |= buttons[1] & 0x0f;
	
	// inpt 4,5
	console->input = buttons[0] & 0x10;
	console->input |= (buttons[1] & 0x10) << 1;
	racer_tia_write_port(console->tia, ~console->input);
}

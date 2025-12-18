//
//  controller.h
//  librayracer
//
//  Created by Serge Tsyba on 16.12.2025.
//

#ifndef controller_h
#define controller_h

#include "atari2600.h"

typedef enum {
	JOYSTICK_BUTTON_UP = 1<<0,
	JOYSTICK_BUTTON_DOWN = 1<<1,
	JOYSTICK_BUTTON_LEFT = 1<<2,
	JOYSTICK_BUTTON_RIGHT = 1<<3,
	JOYSTICK_BUTTON_FIRE = 1<<5,
} racer_joystick_button;

void racer_joysticks_write_output(racer_atari2600 *console, const uint8_t buttons[2]);

#endif /* controller_h */

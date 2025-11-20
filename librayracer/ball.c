//
//  ball.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "ball.h"

bool rr_ball_needs_drawing(rr_ball ball) {
	const bool is_enabled = ball.is_delayed
	? ball.is_enabled[1]
	: ball.is_enabled[0];
	
	return is_enabled
	&& ball.position < ball.size;
}

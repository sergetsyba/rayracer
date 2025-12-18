//
//  ball.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "ball.h"

bool ball_needs_drawing(racer_ball ball) {
	// ensure ball is enabled
	if (!ball.is_enabled[ball.is_delayed]) {
		return false;
	}
	
	return ball.position < ball.size;
}

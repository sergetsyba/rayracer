//
//  ball.c
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#include "ball.h"

bool rr_ball_needs_drawing(rr_ball ball) {
	// ensure ball is enabled
	if (!(~(ball.flags & BALL_DELAYED) && (ball.flags & BALL_ENABLED_0))
		|| ((ball.flags & BALL_DELAYED) && ~(ball.flags & BALL_ENABLED_1))) {
		return false;
	}
	
	return ball.position < ball.size;
}

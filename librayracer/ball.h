//
//  ball.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef ball_h
#define ball_h

#include <stdbool.h>

typedef struct {
	int size;
	bool is_enabled[2];
	bool is_delayed;
	
	int position;
	int motion;
} rr_ball;

bool rr_ball_needs_drawing(rr_ball ball);

#endif /* ball_h */

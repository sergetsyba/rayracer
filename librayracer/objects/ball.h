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
} racer_ball;

bool ball_needs_drawing(racer_ball ball);

#endif /* ball_h */

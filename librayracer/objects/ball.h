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
	int flags;
	
	int position;
	int motion;
} rr_ball;

typedef enum {
	BALL_ENABLED_0 = 1 << 0,
	BALL_ENABLED_1 = 1 << 1,
	BALL_DELAYED = 1 << 2,
} rr_ball_flag;

bool rr_ball_needs_drawing(rr_ball ball);

#endif /* ball_h */

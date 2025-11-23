//
//  playfield.h
//  rayracer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef play_field_h
#define play_field_h

#include <stdbool.h>

typedef struct {
	long int graphics;
	int flags;
} rr_playfield;

typedef enum {
	PLAYFIELD_REFLECTED = 1 << 0,
	PLAYFIELD_SCORE = 1 << 1,
	PLAYFIELD_PRIORITY = 1 << 2
} rr_playfield_flag;

void set_playfield_graphics(rr_playfield* playfield, int data, int bit);
void set_playfield_flags(rr_playfield *playfield, int flags);
bool playfield_needs_drawing(rr_playfield playfield, int position);

#endif /* play_field_h */

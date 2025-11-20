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
	
	/**
	 * Playfield options:
	 * 	0. right half duplicated/reflected
	 * 	1: score mode off/on
	 * 	2: playefield & ball below/above players
	 */
	int options;
} rr_playfield;

bool rr_playfield_needs_drawing(rr_playfield playfield, int position);

#endif /* play_field_h */

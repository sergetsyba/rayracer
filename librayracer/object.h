//
//  object.h
//  RayRacer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef object_h
#define object_h

static const int copy_modes[][2] = {
	{0x001, 0},	// ●○○○○○○○○○
	{0x005, 0},	// ●○●○○○○○○○
	{0x011, 0},	// ●○○●○○○○○○
	{0x015, 0},	// ●○●○●○○○○○
	{0x101, 0},	// ●○○○○○○○●○
	{0x001, 1},	// ●●○○○○○○○○
	{0x111, 0},	// ●○○○●○○○●○
	{0x001, 2}	// ●●●●○○○○○○
};

#define min(a, b) \
	a < b ? a : b

#define reset_position(object) \
	object.position = 160-4
#define advance_position(object) \
	object.position += 1; \
	if (object.position == 160) { \
		object.position = 0; \
	}

#define move(object, limit) \
	object.position += min(object.motion, limit)
#define clear_motion(object) \
	object.motion = 0

#endif /* object_h */

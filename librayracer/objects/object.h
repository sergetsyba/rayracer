//
//  object.h
//  RayRacer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef object_h
#define object_h

extern const int copy_modes[][2];
extern int reflections[];

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

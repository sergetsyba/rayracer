//
//  object.h
//  RayRacer
//
//  Created by Serge Tsyba on 19.11.2025.
//

#ifndef object_h
#define object_h

#define reset_position(object) \
	object.position = 160-4
#define advance_position(object) \
	object.position += 1; \
	if (object.position == 160) { \
		object.position = 0; \
	}

#define min(a, b) \
	a < b ? a : b

#define move(object, limit) \
	object.position += min(object.motion, limit)
#define clear_motion(object) \
	object.motion = 0

#endif /* object_h */

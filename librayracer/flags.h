//
//  flags.h
//  RayRacer
//
//  Created by Serge Tsyba on 21.11.2025.
//

#ifndef flags_h
#define flags_h

#define clear_flag(flags, flag) \
	flags &= ~(flag)

#define add_flag(flags, flag, on) \
	flags |= (on) ? (flag) : 0

#define set_flag(flags, flag, on) \
	flags &= ~(flag); \
	flags |= (on) ? (flag) : 0

#endif /* flags_h */

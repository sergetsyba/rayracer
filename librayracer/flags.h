//
//  flags.h
//  RayRacer
//
//  Created by Serge Tsyba on 21.11.2025.
//

#ifndef flags_h
#define flags_h

#define set_flag(flags, flag, on) \
flags = on ? (flags | (flag)) : (flags & ~(flag))

#define clear_flag(flags, flag) \
flags &= ~(flag)

#endif /* flags_h */

//
//  flags.h
//  RayRacer
//
//  Created by Serge Tsyba on 21.11.2025.
//

#ifndef flags_h
#define flags_h

#define is_bit_set(data, bit) \
	((data >> (bit)) & 0x1)

#define clear_bit(data, bit) \
	data &= ~(1 << (bit))

#define set_bit(data, bit, on) \
	clear_bit(data, (bit)); \
	data |= (on) ? (1 << (bit)) : 0


#define clear_flag(flags, flag) \
	flags &= ~(flag)

#define add_flag(flags, flag, on) \
	flags |= (on) ? (flag) : 0

#define set_flag(flags, flag, on) \
	flags &= ~(flag); \
	flags |= (on) ? (flag) : 0

#endif /* flags_h */

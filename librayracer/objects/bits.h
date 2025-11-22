//
//  bits.h
//  RayRacer
//
//  Created by Serge Tsyba on 20.11.2025.
//

#ifndef bits_h
#define bits_h

#define get_bit(data, bit) \
	(((data) >> (bit)) & 0x1)

#define set_bit(data, bit, value) \
	data = (((data) & ~(1 << (bit))) | ((bool)(value) << (bit)))

#endif /* bits_h */

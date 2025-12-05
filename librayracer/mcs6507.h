//
//  mcs6507.h
//  RayRacer
//
//  Created by Serge Tsyba on 26.11.2025.
//

#ifndef mcs6507_h
#define mcs6507_h

#include <stdbool.h>
#include "flags.h"

typedef struct {
	int code;
	int address;
	int duration;
	int length;
} decoded;


typedef struct {
	int accumulator;
	int x;
	int y;
	
	bool is_ready;
	
	int status;
	int stack_pointer;
	int program_counter;
	
	int (*read_bus)(int);
	void (*write_bus)(int, int);
	
	decoded operation;
	int clock;
} rr_mcs6507;

rr_mcs6507 *rr_create_mcs6507(void);
void rr_advance_clock(rr_mcs6507 *cpu);

// MARK: -
// MARK: Status flags
#define is_carry_set(cpu) \
	is_bit_set(cpu->status, 0)
#define is_zero_set(cpu) \
	is_bit_set(cpu->status, 1)
#define is_interrupt_disable_set(cpu) \
	is_bit_set(cpu->status, 2)
#define is_decimal_mode_set(cpu) \
	is_bit_set(cpu->status, 3)
#define is_break_set(cpu) \
	is_bit_set(cpu->status, 4)
#define is_overflow_set(cpu) \
	is_bit_set(cpu->status, 6)
#define is_negative_set(cpu) \
	is_bit_set(cpu->status, 7)

#define set_carry(cpu, on) \
	set_bit(cpu->status, 0, on)
#define set_zero(cpu, on) \
	set_bit(cpu->status, 1, on)
#define set_interrupt_disable(cpu, on) \
	set_bit(cpu->status, 2, on)
#define set_decimal_mode(cpu, on) \
	set_bit(cpu->status, 3, on)
#define set_break(cpu, on) \
	set_bit(cpu->status, 4, on)
#define set_overflow(cpu, on) \
	set_bit(cpu->status, 6, on)
#define set_negative(cpu, on) \
	set_bit(cpu->status, 7, on)

#endif /* mcs6507_h */

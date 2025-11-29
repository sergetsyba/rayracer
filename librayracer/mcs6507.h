//
//  mcs6507.h
//  RayRacer
//
//  Created by Serge Tsyba on 26.11.2025.
//

#ifndef mcs6507_h
#define mcs6507_h

#include <stdbool.h>

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

#define is_carry(cpu) ((cpu->status >> 0) & 0x1)
#define is_zero(cpu) ((cpu->status >> 1) & 0x1)
#define is_interrupt_disabled(cpu) ((cpu->status >> 2) & 0x1)
#define is_decimal_mode(cpu) ((cpu->status >> 3) & 0x1)
#define is_break(cpu)  ((cpu->status >> 4) & 0x1)
#define is_overflow(cpu) ((cpu->status >> 6) & 0x1)
#define is_negative(cpu) ((cpu->status >> 7) & 0x1)

#define set_bit(data, bit, on) \
data &= ~(1<<bit); \
data |= on ? (1<<bit) : 0;

#define set_carry(cpu, on) set_bit(cpu->status, 0, on)
#define set_zero(cpu, on) set_bit(cpu->status, 1, on)
#define set_interrupt_disabled(cpu, on) set_bit(cpu->status, 2, on)
#define set_decimal_mode(cpu, on) set_bit(cpu->status, 3, on)
#define set_break(cpu, on) set_bit(cpu->status, 4, on)
#define set_overflow(cpu, on) set_bit(cpu->status, 6, on)
#define set_negative(cpu, on) set_bit(cpu->status, 7, on)

#endif /* mcs6507_h */

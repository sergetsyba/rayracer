//
//  mcs6507.h
//  RayRacer
//
//  Created by Serge Tsyba on 26.11.2025.
//

#ifndef mcs6507_h
#define mcs6507_h

#include <stdint.h>
#include <stdbool.h>

typedef struct {
	int code;
	int address;
	int duration;
	int length;
} decoded;

typedef enum {
	MCS6507_STATUS_CARRY = 1<<0,
	MCS6507_STATUS_ZERO = 1<<1,
	MCS6507_STATUS_INTERRUPT_DISABLE = 1<<2,
	MCS6507_STATUS_DECIMAL_MODE = 1<<3,
	MCS6507_STATUS_BREAK = 1<<4,
	MCS6507_STATUS_OVERFLOW = 1<<6,
	MCS6507_STATUS_NEGATIVE = 1<<7
} racer_mcs6507_status;

typedef struct {
	int accumulator;
	int x;
	int y;
	
	bool is_ready;
	
	int status;
	int stack_pointer;
	int program_counter;
	
	void *bus;
	uint8_t (*read_bus)(void *bus, int address);
	void (*write_bus)(void *bus, int address, uint8_t data);
	
	decoded operation;
	int operation_clock;
} racer_mcs6507;

/// Resets the specified MCS6507 chip.
///
/// Resetting the chip sets Interrupt Disable status flag, stack pointer to 0xfd and progam counter
/// to 0xfffc. All other internal state is assumed unpredictable.
///
/// This function is equivalent to pulling RES line low for 6 clock cycles in actual hardware.
void racer_mcs6507_reset(racer_mcs6507 *cpu);

/// Advanced MCS6507 chip clock by 1 full (2-phase) cycle.
void racer_mcs6507_advance_clock(racer_mcs6507 *cpu);

#endif /* mcs6507_h */

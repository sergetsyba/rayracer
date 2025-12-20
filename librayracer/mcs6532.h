//
//  mcs6532.h
//  RayRacer
//
//  Created by Serge Tsyba on 29.11.2025.
//

#ifndef mcs6532_h
#define mcs6532_h

#include <stdint.h>

typedef struct {
	unsigned char memory[128];
	
	int data[2];
	int data_direction[2];
	int data_latch;
	
	int timer;
	int timer_scale;
	
	/**
	 * Interrupt control holds options for edge detection and interrupt behavior.
	 *
	 * Bit 0 denotes polarity of transition to be detected on line 7 of port A. When set, edge detction will
	 * target positive transition (i.e. 0→1); when clear - negative (i.e. 1→0).
	 * Bit 6 denotes whether interrupt should be asserted once active transition occurrs on line 7 of
	 * port A.
	 * Bit 7 denotes whether interrupt should be asserted on the next clock cycle after timer reaches 0.
	 */
	int interrupt_control;
	
	/**
	 * Interrupt flag reister.
	 *
	 * Bit 6 is set when an active transition occurs on line 7 of port A. This bit is cleared once interrupt
	 * flag is read.
	 * Bit 7 is set on the next clock cycle after timer counts down to 0. This bit is cleared once timer is
	 * read or written to.
	 */
	int interrupt;
	
	void *peripherals[2];
	uint8_t (*read_port[2])(const void *peripheral);
	void (*write_port[2])(void *peripheral, uint8_t data);
} racer_mcs6532;

/**
 * Resets the specified MCS6532.
 *
 * This function is equivalent to pulling RES line low for 1 clock cycle in actual hardware.
 *
 * Resetting the chip clears both data and data direction registers, disables interrupt for edge detect
 * and sets it to detect negative transition. It does not reset the timer or clear interrupt registers.
 */
void racer_mcs6532_reset(racer_mcs6532 *riot);

/**
 * Advances internal clock by 1 cycle.
 */
void racer_mcs6532_advance_clock(racer_mcs6532 *riot);

/**
 * Reads data from the specified MCS6532 (excluding RAM).
 *
 * This function is equivalent to pulling RS and R/W lines high, and putting the specified address onto
 * address lines A0-A7; the returned value would be put onto data lines D0-D7.
 */
int racer_mcs6532_read(racer_mcs6532 *riot, int address);

/**
 * Writes data to the specified MCS6532 (excluding RAM).
 *
 * This function is equivalent to pulling RS line high, R/W line low, putting the specified address onto
 * address lines A0-A7 and the specified data onto data lines D0-D7.
 */
void racer_mcs6532_write(racer_mcs6532 *riot, int address, int data);

// MARK: -
// MARK: Interrupt control flags
#define MCS6532_EDGE_DETECT_POLARITY (1<<0)
#define MCS6532_EDGE_DETECT_INTERRUPT (1<<6)
#define MCS6532_TIMER_INTERRUPT (1<<7)

#endif /* mcs6532_h */

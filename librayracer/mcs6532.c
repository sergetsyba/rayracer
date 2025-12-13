//
//  mcs6532.c
//  RayRacer
//
//  Created by Serge Tsyba on 29.11.2025.
//

#include "mcs6532.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

void racer_mcs6532_reset(racer_mcs6532 *riot) {
	// randomize memory
	for (int index = 0; index < 128; ++index) {
		riot->memory[index] = arc4random_uniform(0x100);
	}
	
	// clear both data and data direction registers
	riot->data[0] = 0x00;
	riot->data_direction[0] = 0x00;
	riot->data[1] = 0x00;
	riot->data_direction[1] = 0x00;
	
	// disable interrupt for edge detect and set it to detect negative
	// transition
	set_edge_detect_interrupt_enabled(riot, false);
	set_edge_detect_polarity(riot, 0);
}

void racer_mcs6532_advance_clock(racer_mcs6532 *riot) {
	// stop timer when it reaches max count down -0xff
	if (riot->timer == -0xff) {
		return;
	}
	
	riot->timer -= 1;
	
	if (riot->timer == -1) {
		// set timer interrupt flag after timer expires
		set_timer_interrupt_flag(riot, true);
		
		// call interrupt if enabled in interrupt control
		if (is_timer_interrupt_enabled(riot)) {
			riot->interrupt();
		}
	}
}


// MARK: -
// MARK: Port integration
static int get_port_data(racer_mcs6532 riot, int index) {
	// read pins driven by a connected peripheral
	int input = riot.read_port[index](riot.peripherals[index]);
	input &= ~riot.data_direction[index];
	
	// read data for pins driven by MCS6532
	int output = riot.data[index];
	output &= riot.data_direction[index];
	
	return input | output;
}

static void edge_detect_bit7(racer_mcs6532 *riot, int data) {
	const int last_data = riot->interrupt_control;
	set_edge_detect_value(riot, data);
	
	// check whether bit 7 differs from last observed value
	// and save new observed value
	const bool is_active = (last_data ^ data) & 0x80;
	if (!is_active) {
		// do nothing when there no active transition
		return;
	}
	
	// 0 - negative transition 1->0
	// 1 - positive transition 0->1
	const int polarity = get_edge_detect_polarity(riot);
	if (polarity == (data >> 7)) {
		// set edge detect interrupt flag when transition polarity
		// matches one in interrupt control
		set_edge_detect_interrupt_flag(riot, true);
		
		// call interrupt if enabled in interrupt control
		if (is_edge_detect_interrupt_enabled(riot)) {
			riot->interrupt();
		}
	}
}

// MARK: -
// MARK: Bus integration
int racer_mcs6532_read(racer_mcs6532 *riot, int address) {
	switch (address & 0x7) {
			// MARK: output a
		case 0x0: {
			// perform edge detection for line 7
			const int data = get_port_data(*riot, 0);
			edge_detect_bit7(riot, data);
			
			return data;
		}
			
			// MARK: data direction a
		case 0x1:
			return riot->data_direction[0];
			
			// MARK: output b
		case 0x2:
			return get_port_data(*riot, 1);
			
			// MARK: data direction b
		case 0x3:
			return riot->data_direction[1];
			
			// MARK: timer
		case 0x4:
			// reading or writing timer sets timer interrupt
			set_timer_interrupt_enabled(riot, address & (1<<2));
			
			// reading or writing timer clears timer interrupt flag, unless
			// reading happens on the same cycle as timer expires
			if (riot->timer != 0) {
				clear_timer_interrupt_flag(riot);
			}
			return get_timer(riot);
			
			// MARK: interrupt flag
		case 0x5: {
			const int interrupts = riot->interrupt_flags;
			
			// reading interrupt flag clears edge detect interrupt flag
			clear_edge_detect_interrupt_flag(riot);
			return interrupts;
		}
			
		default:
			printf("msc6532: invalid read address: %d.\n", address);
			return 0;
	}
}

void racer_mcs6532_write(racer_mcs6532 *riot, int address, int data) {
	switch (address & 0x1f) {
			// MARK: data a
		case 0x0: {
			riot->data[0] = data;
			
			// perform edge detection for line 7
			const int data = get_port_data(*riot, 0);
			edge_detect_bit7(riot, data);
			
			// update peripheral on port A
			riot->write_port[0](riot->peripherals[0], data);
			break;
		}
			
			// MARK: data direction a
		case 0x1: {
			riot->data_direction[0] = data;
			
			// perform edge detection for line 7
			const int data = get_port_data(*riot, 1);
			edge_detect_bit7(riot, data);
			
			// update peripheral on port A
			riot->write_port[0](riot->peripherals[0], data);
			break;
		}
			
			// MARK: data b
		case 0x2: {
			riot->data[1] = data;
			
			// update peripheral on port B
			const int data = get_port_data(*riot, 1);
			riot->write_port[1](riot->peripherals[0], data);
			break;
		}
			
			// MARK: data direction b
		case 0x3: {
			riot->data_direction[1] = data;
			
			// update peripheral on port B
			const int data = get_port_data(*riot, 1);
			riot->write_port[1](riot->peripherals[0], data);
			break;
		}
			
		case 0x4: case 0x5: case 0x6: case 0x7:
			// MARK: edge detect
			set_edge_detect_polarity(riot, address & (1<<0));
			set_edge_detect_interrupt_enabled(riot, address & (1<<1));
			break;
			
			// MARK: timer x1
		case 0x14: case 0x1c:
			set_timer_interrupt_enabled(riot, address & (1<<4));
			clear_timer_interrupt_flag(riot);
			
			riot->timer_scale = 0;
			riot->timer = data << riot->timer_scale;
			break;
			
			// MARK: timer x8
		case 0x15: case 0x1d:
			set_timer_interrupt_enabled(riot, address & (1<<4));
			clear_timer_interrupt_flag(riot);
			
			riot->timer_scale = 3;
			riot->timer = data << riot->timer_scale;
			break;
			
			// MARK: timer x64
		case 0x16: case 0x1e:
			set_timer_interrupt_enabled(riot, address & (1<<4));
			clear_timer_interrupt_flag(riot);
			
			riot->timer_scale = 6;
			riot->timer = data << riot->timer_scale;
			break;
			
			// MARK: timer x1024
		case 0x17: case 0x1f:
			set_timer_interrupt_enabled(riot, address & (1<<4));
			clear_timer_interrupt_flag(riot);
			
			riot->timer_scale = 10;
			riot->timer = data << riot->timer_scale;
			break;
			
		default:
			printf("msc6532: invalid write address: %d.\n", address);
			break;
	}
}

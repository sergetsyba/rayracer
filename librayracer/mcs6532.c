//
//  mcs6532.c
//  RayRacer
//
//  Created by Serge Tsyba on 29.11.2025.
//

#include "mcs6532.h"
#include "flags.h"

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

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
	riot->data_latch = 0x0;
	
	// disable interrupt for edge detect and set it to detect negative
	// transition
	clear_flag(riot->interrupt_control, MCS6532_EDGE_DETECT_INTERRUPT);
	clear_flag(riot->interrupt_control, MCS6532_EDGE_DETECT_POLARITY);
}

void racer_mcs6532_advance_clock(racer_mcs6532 *riot) {
	// stop timer when it reaches max count down -0xff
	if (riot->timer == -0xff) {
		return;
	}
	
	riot->timer -= 1;
	
	if (riot->timer == -1) {
		// set timer interrupt flag once timer expires
		add_flag(riot->interrupt, MCS6532_TIMER_INTERRUPT);
		// call interrupt if enabled in interrupt control
		if (is_flag_set(riot->interrupt_control, MCS6532_TIMER_INTERRUPT)) {
			// TODO: call interrupt
		}
	}
}


// MARK: -
// MARK: Port integration
static int get_port_data(const racer_mcs6532 *riot, int index) {
	// read pins driven by a connected peripheral
	int input = riot->read_port[index](riot->peripherals[index]);
	input &= ~riot->data_direction[index];
	
	// read data for pins driven by MCS6532
	int output = riot->data[index];
	output &= riot->data_direction[index];
	
	return input | output;
}

static void edge_detect_bit7(racer_mcs6532 *riot, int data) {
	const bool is_active = (riot->data_latch ^ data) & 0x80;
	if (!is_active) {
		// do nothing when there no active transition
		return;
	}
	
	// 0 - negative transition 1->0
	// 1 - positive transition 0->1
	const int polarity = is_flag_set(riot->interrupt_control, MCS6532_EDGE_DETECT_POLARITY) ? 0x1 : 0x0;
	if (polarity == (data >> 7)) {
		// set edge detect interrupt flag when transition polarity
		// matches one in interrupt control
		add_flag(riot->interrupt, MCS6532_EDGE_DETECT_INTERRUPT);
		// call interrupt if enabled in interrupt control
		if (is_flag_set(riot->interrupt_control, MCS6532_EDGE_DETECT_INTERRUPT)) {
			// TODO: call interrupt
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
			const int port_data = get_port_data(riot, 0);
			edge_detect_bit7(riot, port_data);
			
			riot->data_latch = port_data;
			return port_data;
		}
			
			// MARK: data direction a
		case 0x1:
			return riot->data_direction[0];
			
			// MARK: output b
		case 0x2:
			return get_port_data(riot, 1);
			
			// MARK: data direction b
		case 0x3:
			return riot->data_direction[1];
			
			// MARK: timer
		case 0x4:
			// reading or writing timer enables timer interrupt
			set_flag(riot->interrupt_control, MCS6532_TIMER_INTERRUPT, address & 0x8);
			
			// reading or writing timer while it has not yet expired clears
			// timer interrupt flag, unless reading happens on the same cycle
			// as timer expires
			if (riot->timer > 0) {
				clear_flag(riot->interrupt, MCS6532_TIMER_INTERRUPT);
			}
			
			return riot->timer < 0
			? riot->timer + 0x100
			: riot->timer >> riot->timer_scale;
			
			// MARK: interrupt flag
		case 0x5: {
			const int interrupt = riot->interrupt;
			
			// reading interrupt flag clears edge detect interrupt flag
			clear_flag(riot->interrupt, MCS6532_EDGE_DETECT_INTERRUPT);
			return interrupt;
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
			const int port_data = get_port_data(riot, 0);
			edge_detect_bit7(riot, port_data);
			
			// update peripheral on port A and latch port data
			riot->write_port[0](riot->peripherals[0], port_data);
			riot->data_latch = port_data;
			break;
		}
			
			// MARK: data direction a
		case 0x1: {
			riot->data_direction[0] = data;
			
			// perform edge detection for line 7
			const int port_data = get_port_data(riot, 0);
			edge_detect_bit7(riot, port_data);
			
			// update peripheral on port A and latch port data
			riot->write_port[0](riot->peripherals[0], port_data);
			riot->data_latch = port_data;
			break;
		}
			
			// MARK: data b
		case 0x2: {
			riot->data[1] = data;
			
			// update peripheral on port B
			const int port_data = get_port_data(riot, 1);
			riot->write_port[1](riot->peripherals[1], port_data);
			break;
		}
			
			// MARK: data direction b
		case 0x3: {
			riot->data_direction[1] = data;
			
			// update peripheral on port B
			const int port_data = get_port_data(riot, 1);
			riot->write_port[1](riot->peripherals[1], port_data);
			break;
		}
			
		case 0x4: case 0x5: case 0x6: case 0x7:
			// MARK: edge detect
			set_flag(riot->interrupt_control, MCS6532_EDGE_DETECT_POLARITY, address & 0x1);
			set_flag(riot->interrupt_control, MCS6532_EDGE_DETECT_INTERRUPT, address & 0x2);
			break;
			
			// MARK: timer x1
		case 0x14: case 0x1c:
			set_flag(riot->interrupt_control, MCS6532_TIMER_INTERRUPT, address & 0x8);
			clear_flag(riot->interrupt, MCS6532_TIMER_INTERRUPT);
			
			riot->timer_scale = 0;
			riot->timer = data << riot->timer_scale;
			break;
			
			// MARK: timer x8
		case 0x15: case 0x1d:
			set_flag(riot->interrupt_control, MCS6532_TIMER_INTERRUPT, address & 0x8);
			clear_flag(riot->interrupt, MCS6532_TIMER_INTERRUPT);
			
			riot->timer_scale = 3;
			riot->timer = data << riot->timer_scale;
			break;
			
			// MARK: timer x64
		case 0x16: case 0x1e:
			set_flag(riot->interrupt_control, MCS6532_TIMER_INTERRUPT, address & 0x8);
			clear_flag(riot->interrupt, MCS6532_TIMER_INTERRUPT);
			
			riot->timer_scale = 6;
			riot->timer = data << riot->timer_scale;
			break;
			
			// MARK: timer x1024
		case 0x17: case 0x1f:
			set_flag(riot->interrupt_control, MCS6532_TIMER_INTERRUPT, address & 0x8);
			clear_flag(riot->interrupt, MCS6532_TIMER_INTERRUPT);
			
			riot->timer_scale = 10;
			riot->timer = data << riot->timer_scale;
			break;
			
		default:
			printf("msc6532: invalid write address: %d.\n", address);
			break;
	}
}

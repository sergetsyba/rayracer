//
//  mcs6507.c
//  RayRacer
//
//  Created by Serge Tsyba on 26.11.2025.
//

#include "mcs6507.h"

#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>


// MARK: -
// MARK: Memory addressing

#define address(high, low) \
((high << 8) | low)

#define is_same_page(address1, address2) \
(((address1) & 0xff) == ((address2) & 0xff))

/// Reads address, using reative addressing mode, from offset at the specified address, based on
/// the specified branching condition.
///
/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
/// address.
static int read_relative_address(rr_mcs6507 *cpu, int address, bool condition, int *cycles) {
	// when branch is not taken, program counter increments to +1
	// relative to offset operand address
	int offset_address = address + 0x1;
	
	if (condition) {
		const int offset = cpu->read_bus(address);
		
		// offset address using signed 8 bit offset
		offset_address += (offset & 0x80) ? offset - 0x100 : offset;
		*cycles = is_same_page(address, offset_address) ? 1 : 2;
	} else {
		*cycles = 0;
	}
	
	return offset_address;
}

/// Reads 0-page address at the specified address in memory.
static int read_0_page_address(rr_mcs6507 *cpu, int address) {
	return cpu->read_bus(address);
}

/// Reads address, using 0-page x-indexed addressing mode, reading from the specified address
/// in memory.
static int read_0_page_x_indexed_address(rr_mcs6507 *cpu, int address) {
	address = read_0_page_address(cpu, address);
	return (address + cpu->x) & 0xff;
}

/// Reads address, using 0-page y-indexed addressing mode, reading from the specified address
/// in memory.
static int read_0_page_y_indexed_address(rr_mcs6507 *cpu, int address) {
	address = read_0_page_address(cpu, address);
	return (address + cpu->y) & 0xff;
}

/// Reads address at the specified address in memory.
static int read_address(rr_mcs6507 *cpu, int address) {
	const int low = cpu->read_bus(address);
	const int high = cpu->read_bus(address + 0x1);
	
	return address(high, low);
}

/// Reads address, using absolute, x-indexed addressing mode, at the specified address in memory.
///
/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
/// address.
static int read_x_indexed_address(rr_mcs6507 *cpu, int address, int *cycles) {
	address = read_address(cpu, address);
	int indexed_address = address + cpu->x;
	
	*cycles = is_same_page(address, indexed_address) ? 0 : 1;
	return indexed_address;
}

/// Reads address, using absolute, y-indexed addressing mode, at the specified address in memory.
///
/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
/// address.
static int read_y_indexed_address(rr_mcs6507 *cpu, int address, int *cycles) {
	address = read_address(cpu, address);
	int indexed_address = address + cpu->y;
	
	*cycles = is_same_page(address, indexed_address) ? 0 : 1;
	return indexed_address;
}

/// Reads address, using indirect addressing mode, at the specified address in memory.
static int read_indirect_address(rr_mcs6507 *cpu, int address) {
	address = read_address(cpu, address);
	address = read_address(cpu, address);
	return address;
}

/// Reads address, using x-indexed indirect addressing mode, at the specified address in memory.
static int read_indirect_x_indexed_address(rr_mcs6507 *cpu, int address) {
	address = read_0_page_x_indexed_address(cpu, address);
	address = read_address(cpu, address);
	return address;
}

/// Reads address, using indirect y-indexed addressing mode, at the specified address in memory.
///
/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
/// address.
static int read_indirect_y_indexed_address(rr_mcs6507 *cpu, int address, int *cycles) {
	address = read_0_page_address(cpu, address);
	address = read_address(cpu, address);
	int indexed_address = address + cpu->y;
	
	*cycles = is_same_page(address, indexed_address) ? 0 : 1;
	return indexed_address;
}


// MARK: -
// MARK: Stack management

/// Pushes the specified value onto stack and updates the stack pointer.
static void push_stack(rr_mcs6507 *cpu, int data) {
	const int address = cpu->stack_pointer + 0x0100;
	cpu->write_bus(data, address);
	cpu->stack_pointer -= 0x1;
}

/// Pulls the last pushed value from the stack and updates the stack pointer.
static int pull_stack(rr_mcs6507 *cpu) {
	cpu->stack_pointer += 0x1;
	
	const int address = cpu->stack_pointer + 0x0100;
	return cpu->read_bus(address);
}


// MARK: -
// MARK: Operation execution

/// Decodes operation at the specified address.
static void decode_operation(rr_mcs6507 *cpu) {
	const int opcode = cpu->read_bus(cpu->program_counter);
	int address = cpu->program_counter + 0x1;
	int cycles = 0;
	
	switch (opcode) {
			// MARK: implied addressing
		case 0x18: case 0x38: case 0x58: case 0xb8: case 0xd8: case 0x78: case 0x88: case 0xa8: case 0x98: case 0xc8: case 0xe8: case 0xf8:
		case 0x0a: case 0x2a: case 0x4a: case 0x6a: case 0x8a: case 0x9a: case 0xaa: case 0xba: case 0xca: case 0xea:
			cpu->operation = (decoded){opcode, -1, 2, 1};
			break;
		case 0x08: case 0x48:
			cpu->operation = (decoded){opcode, -1, 3, 1};
			break;
		case 0x28: case 0x68:
			cpu->operation = (decoded){opcode, -1, 4, 1};
			break;
		case 0x40: case 0x60:
			cpu->operation = (decoded){opcode, -1, 6, 1};
			break;
		case 0x00:
			cpu->operation = (decoded){opcode, -1, 7, 1};
			break;
			
			// MARK: immediate addressing
		case 0xa2:
		case 0x09: case 0x29: case 0x49: case 0x69: case 0xa9: case 0xc9: case 0xe9:
		case 0xa0: case 0xe0: case 0xc0:
			cpu->operation = (decoded){opcode, address, 2, 2};
			break;
			
			// MARK: relative addressing
		case 0x10: {
			address = read_relative_address(cpu, address, !is_negative_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0x30: {
			address = read_relative_address(cpu, address, is_negative_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0x50: {
			address = read_relative_address(cpu, address, !is_overflow_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0x70: {
			address = read_relative_address(cpu, address, is_overflow_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0x90: {
			address = read_relative_address(cpu, address, !is_carry_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0xb0: {
			address = read_relative_address(cpu, address, is_carry_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0xd0: {
			address = read_relative_address(cpu, address, !is_zero_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
		case 0xf0: {
			address = read_relative_address(cpu, address, is_zero_set(cpu), &cycles);
			cpu->operation = (decoded){opcode, address, 2 + cycles, 2};
			break;
		}
			
			// MARK: 0-page absolute addressing
		case 0x24: case 0x84: case 0xa4: case 0xc4: case 0xe4:
		case 0x05: case 0x25: case 0x45: case 0x65: case 0x85: case 0xa5: case 0xc5: case 0xe5:
		case 0xa6: case 0x86: {
			address = read_0_page_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 3, 2};
			break;
		}
		case 0x06: case 0x26: case 0x46: case 0x66: case 0xc6: case 0xe6: {
			address = read_0_page_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 5, 2};
			break;
		}
			
			// MARK: 0-page x-indexed addressing
		case 0x94: case 0xb4:
		case 0x15: case 0x35: case 0x55: case 0x75: case 0x95: case 0xb5: case 0xd5: case 0xf5: {
			address = read_0_page_x_indexed_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 4, 2};
			break;
		}
		case 0x16: case 0x36: case 0x56: case 0x76: case 0xd6: case 0xf6: {
			address = read_0_page_x_indexed_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 6, 2};
			break;
		}
			
			// MARK: 0-page y-indexed addressing
		case 0x96: case 0xb6: {
			address = read_0_page_y_indexed_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 4, 2};
			break;
		}
			
			// MARK: absolute addressing
		case 0x4c: {
			address = read_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 3, 3};
			break;
		}
		case 0x2c: case 0x8c: case 0xac: case 0xcc: case 0xec:
		case 0x0d: case 0x2d: case 0x4d: case 0x6d: case 0x8d: case 0xad: case 0xcd: case 0xed:
		case 0x8e: case 0xae: {
			address = read_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 4, 3};
			break;
		}
		case 0x20:
		case 0x0e: case 0x2e: case 0x4e: case 0x6e: case 0xce: case 0xee: {
			address = read_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 6, 3};
			break;
		}
			
			// MARK: absolute x-indexed addressing
		case 0xbc:
		case 0x1d: case 0x3d: case 0x5d: case 0x7d: case 0xbd: case 0xdd: case 0xfd: {
			address = read_x_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 4 + cycles, 3};
			break;
		}
		case 0x9d: {
			address = read_x_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 5, 3};
			break;
		}
		case 0x1e: case 0x3e: case 0x5e: case 0x7e: case 0xde: case 0xfe: {
			address = read_x_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 7, 3};
			break;
		}
			
			// MARK: absolute y-indexed addressing
		case 0x19: case 0x39: case 0x59: case 0x79: case 0xb9: case 0xd9: case 0xf9:
		case 0xbe: {
			address = read_y_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 4 + cycles, 3};
			break;
		}
		case 0x99: {
			address = read_y_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 5, 3};
			break;
		}
			
			// MARK: indirect addressing
		case 0x6c: {
			address = read_indirect_address(cpu, address);
			cpu->operation = (decoded){opcode, address, 5, 3};
			break;
		}
			
			// MARK: indirect x-indexed addressing
		case 0x61: case 0x21: case 0xc1: case 0x41: case 0xa1: case 0x01: case 0xe1: case 0x81: {
			address = read_x_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 6, 2};
			break;
		}
			
			// MARK: indirect y-indexed addressing
		case 0x11: case 0x31: case 0x51: case 0x71: case 0x91: case 0xb1: case 0xd1: case 0xf1: {
			address = read_y_indexed_address(cpu, address, &cycles);
			cpu->operation = (decoded){opcode, address, 5 + cycles, 2};
			break;
		}
			
		default:
			printf("Unknown operation code: %d at %04x.\n", opcode, address);
			cpu->operation = (decoded){};
			break;
	}
}

/// Executes currently decoded operation.
static void execute_decoded_operation(rr_mcs6507 *cpu) {
	const int operand_address = cpu->operation.address;
	switch (cpu->operation.code) {
			// MARK: adc
		case 0x61: case 0x65: case 0x69: case 0x6d: case 0x71: case 0x75: case 0x7d: case 0x79: {
			int operand = cpu->read_bus(operand_address);
			int result;
			
			if (is_decimal_mode_set(cpu)) {
				int high = (cpu->accumulator / 0x10) + (operand / 0x10);
				int low = (cpu->accumulator % 0x10) + (operand % 0x10) + is_carry_set(cpu);
				
				if (low > 0x9) {
					high += 0x1;
					low -= 0xa;
				}
				
				result = high * 0x10 + low;
				if (result > 0x99) {
					result -= 0xa0;
					set_carry(cpu, true);
				} else {
					set_carry(cpu, false);
				}
			} else {
				result = cpu->accumulator + operand + is_carry_set(cpu);
				if (result > 0xff) {
					result -= 0x100;
					set_carry(cpu, true);
				} else {
					set_carry(cpu, false);
				}
			}
			
			const bool overflow = (cpu->accumulator ^ result) & (operand ^ result);
			
			cpu->accumulator = result;
			set_overflow(cpu, overflow & 0x80);
			break;
		}
			
			// MARK: and
		case 0x21: case 0x25: case 0x29: case 0x2d: case 0x31: case 0x35: case 0x39: case 0x3d: {
			const int operand = cpu->read_bus(operand_address);
			cpu->accumulator &= operand;
			break;
		}
			
			// MARK: asl (accumulator)
		case 0x0a:
			cpu->accumulator <<= 1;
			set_carry(cpu, cpu->accumulator & 0x100);
			cpu->accumulator &= 0xff;
			break;
			
			// MARK: asl
		case 0x06: case 0x0e: case 0x16: case 0x1e: {
			int operand = cpu->read_bus(operand_address);
			operand <<= 1;
			cpu->write_bus(operand & 0xff, operand_address);
			
			set_carry(cpu, operand & 0x100);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: bcc, bcs, beq, bmi, bne, bpl, bvc, bvs
		case 0x90: case 0xb0: case 0xf0: case 0x30: case 0xd0: case 0x10: case 0x50: case 0x70:
			cpu->program_counter = operand_address;
			break;
			
			// MARK: bit:
		case 0x24: case 0x2c: {
			int operand = cpu->read_bus(operand_address);
			set_overflow(cpu, operand & 0x40);
			
			operand &= cpu->accumulator;
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: brk
		case 0x00: {
			push_stack(cpu, cpu->program_counter >> 8);
			push_stack(cpu, cpu->program_counter & 0xff);
			push_stack(cpu, cpu->status);
			
			const int low = cpu->read_bus(0xfffe);
			const int high = cpu->read_bus(0xffff);
			cpu->program_counter = address(high, low);
			break;
		}
			
			// MARK: clc
		case 0x18:
			set_carry(cpu, false);
			break;
			// MARK: cld
		case 0xd8:
			set_decimal_mode(cpu, false);
			break;
			// MARK: cli
		case 0x58:
			set_interrupt_disable(cpu, false);
			break;
			// MARK: clv
		case 0xb8:
			set_overflow(cpu, false);
			break;
			
			// MARK: cmp
		case 0xc1: case 0xc5: case 0xc9: case 0xcd: case 0xd1: case 0xd5: case 0xd9: case 0xdd: {
			int operand = cpu->read_bus(operand_address);
			operand = cpu->accumulator - operand;
			
			set_carry(cpu, operand >= 0);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: cpx
		case 0xe0: case 0xe4: case 0xec: {
			int operand = cpu->read_bus(operand_address);
			operand = cpu->x - operand;
			
			set_carry(cpu, operand >= 0);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: cpy
		case 0xc0: case 0xc4: case 0xcc: {
			int operand = cpu->read_bus(operand_address);
			operand = cpu->y - operand;
			
			set_carry(cpu, operand >= 0);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: dec
		case 0xc6: case 0xce: case 0xd6: case 0xde: {
			int operand = cpu->read_bus(operand_address);
			operand -= 1;
			cpu->write_bus(operand & 0xff, operand_address);
			
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: dex
		case 0xca:
			cpu->x -= 1;
			cpu->x &= 0xff;
			break;
			
			// MARK: dey
		case 0x88:
			cpu->y -= 1;
			cpu->y &= 0xff;
			break;
			
			// MARK: eor
		case 0x41: case 0x45: case 0x49: case 0x4d: case 0x51: case 0x55: case 0x59: case 0x5d: {
			const int operand = cpu->read_bus(operand_address);
			cpu->accumulator ^= operand;
			break;
		}
			
			// MARK: inc
		case 0xe6: case 0xee: case 0xf6: case 0xfe: {
			int operand = cpu->read_bus(operand_address);
			operand += 0x1;
			
			cpu->write_bus(operand & 0xff, operand_address);
			set_zero(cpu, operand == 0x00);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: inx
		case 0xe8:
			cpu->x += 0x1;
			cpu->x &= 0xff;
			break;
			
			// MARK: iny
		case 0xc8:
			cpu->y += 0x1;
			cpu->y &= 0xff;
			break;
			
			// MARK: jmp
		case 0x4c: case 0x6c:
			cpu->program_counter = operand_address;
			break;
			
			// MARK: jsr
		case 0x20: {
			// NOTE: JSR pushes PC+1 onto stack, but not PC+2 as it should be,
			// and there's an extra PC+1 at the end of RTS, which then
			// correctly aligns return to the beginning of next instruction;
			const int return_address = cpu->program_counter - 0x1;
			push_stack(cpu, return_address >> 8);
			push_stack(cpu, return_address & 0xff);
			
			cpu->program_counter = operand_address;
			break;
		}
			
			// MARK: lda
		case 0xa1: case 0xa5: case 0xa9: case 0xad: case 0xb1: case 0xb5: case 0xb9: case 0xbd:
			cpu->accumulator = cpu->read_bus(operand_address);
			break;
			
			// MARK: ldx
		case 0xa2: case 0xa6: case 0xae: case 0xb6: case 0xbe:
			cpu->x = cpu->read_bus(operand_address);
			break;
			
			// MARK: ldy
		case 0xa0: case 0xa4: case 0xac: case 0xb4: case 0xbc:
			cpu->y = cpu->read_bus(operand_address);
			break;
			
			// MARK: lsr (accumulator)
		case 0x4a:
			set_carry(cpu, cpu->accumulator & 0x1);
			cpu->accumulator >>= 1;
			break;
			
			// MARK: lsr
		case 0x46: case 0x4e: case 0x56: case 0x5e: {
			int operand = cpu->read_bus(operand_address);
			operand <<= 1;
			cpu->write_bus(operand & 0xff, operand_address);
			
			set_carry(cpu, operand & 0x100);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: nop
		case 0xea:
			break;
			
			// MARK: ora
		case 0x01: case 0x05: case 0x09: case 0x0d: case 0x11: case 0x15: case 0x19: case 0x1d: {
			const int operand = cpu->read_bus(operand_address);
			cpu->accumulator |= operand;
			break;
		}
			
			// MARK: pha
		case 0x48:
			push_stack(cpu, cpu->accumulator);
			break;
			
			// MARK: php
		case 0x08:
			push_stack(cpu, cpu->status);
			break;
			
			// MARK: pla
		case 0x68:
			cpu->accumulator = pull_stack(cpu);
			break;
			
			// MARK: plp
		case 0x28:
			cpu->status = pull_stack(cpu);
			break;
			
			// MARK: rol (accumulator)
		case 0x2a:
			set_carry(cpu, cpu->accumulator & 0x80);
			cpu->accumulator <<= 1;
			cpu->accumulator &= 0xff;
			break;
			
			// MARK: rol
		case 0x26: case 0x2e: case 0x36: case 0x3e: {
			int operand = cpu->read_bus(operand_address);
			operand <<= 1;
			operand |= is_carry_set(cpu);
			cpu->write_bus(operand & 0xff, operand_address);
			
			set_carry(cpu, operand & 0x80);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: ror (accumulator)
		case 0x6a: {
			const bool carry = cpu->accumulator & 0x1;
			cpu->accumulator >>= 1;
			cpu->accumulator |= is_carry_set(cpu) << 7;
			
			set_carry(cpu, carry);
			break;
		}
			
			// MARK: ror
		case 0x66: case 0x6e: case 0x76: case 0x7e: {
			int operand = cpu->read_bus(operand_address);
			operand >>= 1;
			operand |= is_carry_set(cpu) << 7;
			cpu->write_bus(operand, operand_address);
			
			set_carry(cpu, operand & 0x1);
			set_zero(cpu, operand == 0);
			set_negative(cpu, operand & 0x80);
			break;
		}
			
			// MARK: rti
		case 0x40: {
			cpu->status = pull_stack(cpu);
			
			const int low = pull_stack(cpu);
			const int high = pull_stack(cpu);
			cpu->program_counter = address(high, low);
			break;
		}
			
			// MARK: rts
		case 0x60: {
			const int low = pull_stack(cpu);
			const int high = pull_stack(cpu);
			cpu->program_counter = address(high, low) + 0x1;
			break;
		}
			
			// MARK: sbc
		case 0xe1: case 0xe5: case 0xe9: case 0xed: case 0xf1: case 0xf5: case 0xf9: case 0xfd: {
			int operand = cpu->read_bus(operand_address);
			
			int result;
			if is_decimal_mode_set(cpu) {
				int high = (cpu->accumulator / 0x10) - (operand / 0x10);
				int low = (cpu->accumulator % 0x10) - (operand % 0x10) - is_carry_set(cpu);
				
				if (low < 0x0) {
					high -= 0x1;
					low += 0xa;
				}
				
				result = high * 0x10 + low;
				if (result < 0x0) {
					result += 0xa0;
					set_carry(cpu, false);
				} else {
					set_carry(cpu, true);
				}
			} else {
				result = cpu->accumulator - operand - is_carry_set(cpu);
				if (result < 0x0) {
					result += 0x100;
					set_carry(cpu, false);
				} else {
					set_carry(cpu, true);
				}
			}
			
			const int overflow = (cpu->accumulator ^ result) & (operand ^ result);
			cpu->accumulator = result;
			set_overflow(cpu, overflow & 0x80);
		}
			
			// MARK: sec
		case 0x38:
			set_carry(cpu, true);
			break;
			
			// MARK: sed
		case 0xf8:
			set_decimal_mode(cpu, true);
			break;
			
			// MARK: sei
		case 0x78:
			set_interrupt_disable(cpu, true);
			break;
			
			// MARK: sta
		case 0x81: case 0x85: case 0x8d: case 0x91: case 0x95: case 0x99: case 0x9d:
			cpu->write_bus(cpu->accumulator, operand_address);
			break;
			
			// MARK: stx
		case 0x86: case 0x8e: case 0x96:
			cpu->write_bus(cpu->x, operand_address);
			break;
			
			// MARK: sty
		case 0x84: case 0x8c: case 0x94:
			cpu->write_bus(cpu->y, operand_address);
			break;
			
			// MARK: tax
		case 0xaa:
			cpu->x = cpu->accumulator;
			break;
			
			// MARK: tay
		case 0xa8:
			cpu->y = cpu->accumulator;
			break;
			
			// MARK: tsx
		case 0xba:
			cpu->x = cpu->stack_pointer;
			break;
			
			// MARK: txa
		case 0x8a:
			cpu->accumulator = cpu->x;
			break;
			
			// MARK: txs
		case 0x9a:
			cpu->stack_pointer = cpu->x;
			break;
			
			// MARK: tya
		case 0x98:
			cpu->accumulator = cpu->y;
			break;
			
		default:
			printf("Unknown operation code: %d.\n", cpu->operation.code);
			break;
	}
}

rr_mcs6507 *rr_create_mcs6507(void) {
	rr_mcs6507 *cpu = (rr_mcs6507 *)malloc(sizeof(rr_mcs6507));
	cpu->clock = 0;
	
	decode_operation(cpu);
	return cpu;
}

void rr_advance_clock(rr_mcs6507 *cpu) {
	cpu->clock += 1;
	
	if (cpu->clock == cpu->operation.duration) {
		cpu->program_counter += cpu->operation.length;
		execute_decoded_operation(cpu);
		
		decode_operation(cpu);
		cpu->clock = 0;
	}
}

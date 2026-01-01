//
//  AssemblyViewController+Cells.swift
//  RayRacer
//
//  Created by Serge Tsyba on 25.12.2025.
//

import Cocoa
import librayracer

class AssemblyGroupRowView: NSTableRowView {
	@IBOutlet private var textField: NSTextField?
	
	var stringValue: String? {
		didSet {
			self.textField?
				.stringValue = self.stringValue ?? ""
		}
	}
}

// MARK: -
class AssemblyAddressCellView: NSTableCellView {
	@IBOutlet var toggle: BreakpointToggle!
	
	override var objectValue: Any? {
		didSet {
			guard let address = self.objectValue as? Int else {
				self.toggle?.stringValue = ""
				return
			}
			self.toggle?
				.stringValue = String(format: "$%03x", address)
		}
	}
	
	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			self.toggle.textColor = self.backgroundStyle == .emphasized
			? .alternateSelectedControlTextColor
			: .controlTextColor
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.toggle.tintColor = .systemRed
		self.toggle.font = .monospacedRegular
		self.toggle.insets = NSEdgeInsets(top: 2.0, left: 8.0, bottom: 2.0, right: 4.0)
	}
}

// MARK: -
class AssemblyInstructionCellView: DebugValueTableCellView {
	override var objectValue: Any? {
		didSet {
			guard let instruction = self.objectValue as? Instruction else {
				self.textField?.stringValue = ""
				return
			}
			self.textField?
				.stringValue = instruction.description
		}
	}
}

// MARK: -
class AssemblyTargetCellView: DebugValueTableCellView {
	override var objectValue: Any? {
		didSet {
			guard let (offset, instruction) = self.objectValue as? (Int, Instruction?),
				  let instruction = instruction else {
				self.textField?.stringValue = ""
				return
			}
			self.textField?
				.stringValue = self.formatTarget(of: instruction, at: offset)
		}
	}
	
	private static var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
	}
	
	private func formatTarget(of instruction: Instruction, at offset: Int) -> String {
		switch instruction.mode {
		case .implied, .immediate:
			// instructions with implied and immediate addressing do not
			// have effective addressses
			return ""
			
		case .zeroPage, .absolute:
			// for instructions with absolute addressing, always return
			// formatted operand address target
			return self.formatTarget(at: instruction.operand!, access: instruction.access)
			
		default:
			// for instructions with indexed addressing, return formatted
			// operand address target only when program is currently at
			// that instruction
			guard let cpu = Self.console.console?.pointee.mpu?.pointee,
				  (offset & 0xfff) == Int(cpu.program_counter & 0xfff) else {
				return ""
			}
			return self.formatTarget(at: Int(cpu.operation.address), access: instruction.access)
		}
	}
	
	private func formatTarget(at address: Int, access: Instruction.DataAccess) -> String {
		// append instruction data access symbol
		var formatted = Self.accessArrows[access] ?? " "
		formatted += " "
		
		// append access target
		if address & 0xd000 == 0xd000 {
			// cartridge
			formatted += String(format: "rom $%03x", address & 0xfff)
		} else if address & 0x280 == 0x80 {
			// RIOT RAM
			formatted += String(format: "ram $%02x", address & 0x7f)
		} else if address & 0x280 == 0x280 {
			// RIOT
			switch access {
			case .none:
				return ""
			case .read:
				formatted += MCS6532.readRegisters[address & 0x7] ?? ""
			case .write, .readWrite:
				formatted += MCS6532.writeRegisters[address & 0x1f] ?? ""
			}
		} else if address & 0x80 == 0x00 {
			// TIA
			formatted += TIA.registers[address & 0x3f] ?? ""
		} else {
			return ""
		}
		return formatted
	}
	
	private static let accessArrows: [Instruction.DataAccess: String] = [
		.read: "←",
		.write: "→",
		.readWrite: "↔︎"
	]
}


// MARK: -
// MARK: Data formatting
extension Instruction: CustomStringConvertible {
	var description: String {
		var formatted = self.mnemonic.rawValue
		
		// format and append operand, when present
		if let operand = self.operand,
		   let format = Self.operandFormats[self.mode] {
			formatted += " "
			formatted += String(format: format, operand)
		}
		return formatted
	}
	
	private static let operandFormats: [Instruction.AddressingMode: String] = [
		.immediate: "#$%02x",
		.zeroPage: "$%02x",
		.zeroPageX: "$%02x,x",
		.zeroPageY: "$%02x,y",
		.absolute: "$%04x",
		.absoluteX: "$%04x,x",
		.absoluteY: "$%04x,y",
		.indirect: "($%04x)",
		.indirectX: "($%02x,x)",
		.indirectY: "($%02x),y",
		.relative: "%+d"
	]
}

extension Instruction {
	enum DataAccess {
		case none
		case read
		case write
		case readWrite
	}
	
	var access: DataAccess {
		switch self.mnemonic {
		case .adc, .and, .bit, .cmp, .cpx, .cpy, .eor,
				.lda, .ldx, .ldy, .ora, .sbc:
			return .read
		case .jsr, .sta, .stx, .sty:
			return .write
		case .asl, .dec, .inc, .lsr, .rol, .ror:
			return .readWrite
		default:
			return .none
		}
	}
}

private typealias MCS6532 = racer_mcs6532
private extension MCS6532 {
	static let readRegisters = [
		0x00: "swcha",
		0x01: "swacnt",
		0x02: "swchb",
		0x03: "swbcnt",
		0x04: "intim"
	]
	
	static let writeRegisters = [
		0x00: "swcha",
		0x01: "swacnt",
		0x02: "swchb",
		0x03: "swbcnt",
		0x14: "tim1t",
		0x15: "tim8t",
		0x16: "tim64t",
		0x17: "t1024t"
	]
}

private typealias TIA = racer_tia
private extension TIA {
	static let registers = [
		0x00: "vsync",
		0x01: "vblank",
		0x02: "wsync",
		0x03: "rsync",
		0x04: "nusiz0",
		0x05: "nusiz1",
		0x06: "colup0",
		0x07: "colup1",
		0x08: "colupf",
		0x09: "colubk",
		0x0a: "ctrlpf",
		0x0b: "refp0",
		0x0c: "refp1",
		0x0d: "pf0",
		0x0e: "pf1",
		0x0f: "pf2",
		0x10: "resp0",
		0x11: "resp1",
		0x12: "resm0",
		0x13: "resm1",
		0x14: "resbl",
		0x15: "audc0",
		0x16: "audc1",
		0x17: "audf0",
		0x18: "audf1",
		0x19: "audv0",
		0x1a: "audv1",
		0x1b: "grp0",
		0x1c: "grp1",
		0x1d: "enam0",
		0x1e: "enam1",
		0x1f: "enabl",
		0x20: "hmp0",
		0x21: "hmp1",
		0x22: "hmm0",
		0x23: "hmm1",
		0x24: "hmbl",
		0x25: "vdelp0",
		0x26: "vdelp1",
		0x27: "vdelbl",
		0x28: "resmp0",
		0x29: "resmp1",
		0x2a: "hmove",
		0x2b: "hmclr",
		0x2c: "cxclr",
		0x30: "cxm0p",
		0x31: "cxm1p",
		0x32: "cxp0fb",
		0x33: "cxp1fb",
		0x34: "cxm0fb",
		0x35: "cxm1fb",
		0x36: "cxblpf",
		0x37: "cxppmm",
		0x38: "inpt0",
		0x39: "inpt1",
		0x3a: "inpt2",
		0x3b: "inpt3",
		0x3c: "inpt4",
		0x3d: "inpt5"
	]
}

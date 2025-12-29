//
//  AssemblyViewController+Cells.swift
//  RayRacer
//
//  Created by Serge Tsyba on 25.12.2025.
//

import Cocoa

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
				.stringValue = String(format: "$%04x", 0xf000 + address)
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
class AssemblyInstructionCellView: NSTableCellView {
	override var objectValue: Any? {
		didSet {
			guard let instruction = self.objectValue as? Instruction else {
				self.textField?.stringValue = ""
				return
			}
			self.textField?
				.stringValue = self.format(instruction: instruction)
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?
			.font = .monospacedRegular
	}
	
	func format(instruction: Instruction) -> String {
		var formatted = "\(instruction.mnemonic)"
		if let operand = instruction.operand {
			let operand = String(format: instruction.operandFormat, operand)
			formatted += " \(operand)"
		}
		
		return formatted
	}
}

// MARK: -
class AssemblyTargetCellView: NSTableCellView {
	override var objectValue: Any? {
		didSet {
			guard let instruction = self.objectValue as? Instruction else {
				self.textField?.stringValue = ""
				return
			}
			self.textField?
				.stringValue = self.format(targetOf: instruction, at: 0)
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?
			.font = .monospacedRegular
	}
	
	func format(targetOf instruction: Instruction, at row: Int) -> String {
		//		switch instruction.addressing {
		//		case .implied:
		//			// instructions with implied addressing do not have operands
		//			return nil
		//
		//		case .zeroPage, .absolute:
		//			// for instructions with absolute addressing, always return
		//			// formatted operand address target
		//			let address = self.unmirror(instruction.operand)
		//			return self.formatTarget(at: address)
		//
		//		default:
		//			// for instructions with indexed addressing, return formatted
		//			// operand address target only when program is currently at
		//			// that instruction
		//			let cpu = self.console.console.pointee.mpu.pointee
		//			guard let program = self.program,
		//				  program[row].0 == Int(cpu.program_counter) else {
		//				return nil
		//			}
		//
		//			let address = self.unmirror(Int(cpu.operation.address))
		//			return self.formatTarget(at: address)
		//		}
		return ""
	}
	
	private func unmirror(_ address: Int) -> Int {
		if (0x0040..<0x0080).contains(address) {
			return address - 0x40
		}
		if (0x5000..<0x6000).contains(address) {
			return address + 0xa000
		}
		return address
	}
	
	private func format(targetAt address: Int) -> String? {
		if (0x0000..<0x0040).contains(address) {
			return Self.tiaLabels[address]
		} else if (0x080..<0x0100).contains(address) {
			return String(format: "ram $%02x", address)
		} else if (0x0280..<0x0300).contains(address) {
			return Self.riotLabels[address - 0x0280]
		} else if (0xf000...0xffff).contains(address) {
			return String(format: "rom $%03x", address)
		} else {
			return nil
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Instruction {
	var operandFormat: String {
		switch self.mode {
		case .implied:
			return ""
		case .immediate:
			return "#$%02x"
		case .zeroPage:
			return "$%02x"
		case .zeroPageX:
			return "$%02x,x"
		case .zeroPageY:
			return "$%02x,y"
		case .absolute:
			return "$%04x"
		case .absoluteX:
			return "$%04x,x"
		case .absoluteY:
			return "$%04x,y"
		case .indirectX:
			return "($%02x,x)"
		case .indirectY:
			return "($%02x),y"
		case .relative:
			return "%+d"
		}
	}
}

extension AssemblyTargetCellView {
	static let tiaLabels = [
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
	
	static let riotLabels = [
		0x00: "swcha",
		0x01: "swacnt",
		0x02: "swchb",
		0x03: "swbcnt",
		0x04: "intim",
		0x06: "intim",
		0x14: "tim1t",
		0x15: "tim8t",
		0x16: "tim64t",
		0x17: "t1024t"
	]
}

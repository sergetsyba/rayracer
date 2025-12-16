//
//  AppDelegate+MainMenu.swift
//  RayRacer
//
//  Created by Serge Tsyba on 20.11.2024.
//

import AppKit

extension RayRacerDelegate {
	@IBAction func didSelectInsertCartridgeMenuItem(_ sender: AnyObject) {
		self.withModalFileOpenPanel() {
			self.showScreen(forProgramAt: $0)
		}
	}
	
	@IBAction func didSelectInsertRecentCartridgeMenuItem(_ sender: NSMenuItem) {
		// TODO: show error message when representedObject is not a URL
		if let url = sender.representedObject as? URL {
			self.showScreen(forProgramAt: url)
		}
	}
	
	@IBAction func didSelectClearInsertRecentCartridgeMenuItem(_ sender: NSMenuItem) {
		UserDefaults.standard
			.clearOpenedFileURLs()
	}
}

// MARK: -
// MARK: Console switches
extension RayRacerDelegate {
	@IBAction func didSelectLeftDifficultyMenuItem(_ sender: NSMenuItem) {
		self.setConsoleSwitch(.difficulty0, on: sender.menuIndex == 1)
	}
	
	@IBAction func didSelectRightDifficultyMenuItem(_ sender: NSMenuItem) {
		self.setConsoleSwitch(.difficulty1, on: sender.menuIndex == 1)
	}
	
	@IBAction func didSelectTVTypeMenuItem(_ sender: NSMenuItem) {
		self.setConsoleSwitch(.color, on: sender.menuIndex == 1)
	}
	
	@IBAction func didSelectGameSelectMenuItem(_ sender: NSMenuItem) {
		self.holdConsoleSwitch(.select)
	}
	
	@IBAction func didSelectGameResetMenuItem(_ sender: AnyObject) {
		self.holdConsoleSwitch(.reset)
	}
	
	@IBAction func didSelectConsoleResetMenuItem(_ sender: AnyObject) {
		self.console.reset()
		
		NotificationCenter.default
			.post(name: .reset, object: self)
	}
	
	private func setConsoleSwitch(_ `switch`: Switches, on: Bool) {
		self.console.switches[`switch`] = on
		
		// save updated switches setup
		UserDefaults.standard
			.consoleSwitches = self.console.switches
	}
	
	private func holdConsoleSwitch(_ `switch`: Switches, for interval: Int = UserDefaults.standard.consoleSwitchHoldInterval) {
		// set switch to `on`
		self.console.switches[`switch`] = true
		
		// set switch to `off` after the interval
		let deadline: DispatchTime = .now()
			.advanced(by: .milliseconds(interval))
		
		DispatchQueue.main
			.asyncAfter(deadline: deadline) { [unowned self] in
				self.console.switches[`switch`] = false
			}
	}
}


// MARK: -
// MARK: Convenience functionality
extension OptionSet {
	subscript(_ index: Self.Element) -> Bool {
		get {
			return self.contains(index)
		}
		set {
			if newValue {
				self.insert(index)
			} else {
				self.remove(index)
			}
		}
	}
}

private extension NSMenuItem {
	var menuIndex: Int? {
		return self.menu?
			.index(of: self)
	}
}

//
//  MainMenuController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 20.11.2024.
//

import AppKit

class MainMenuController: NSObject {
	var collection: (any CartridgeCollection)!
	var console: Atari2600!
}

// MARK: -
// MARK: Cartridges
extension MainMenuController {
	@IBAction func didSelectInsertCartridgeMenuItem(_ sender: NSMenuItem) {
		NSOpenPanel.runModal() {
			let cartridge = try! Cartridge(at: $0)
			self.collection.play(cartridge)
		}
	}
	
	@IBAction func didSelectInsertRecentCartridgeMenu(_ sender: NSMenuItem) {
		// does nothing; enables menu item validation
	}
	
	@IBAction func didSelectInsertRecentCartridgeMenuItem(_ sender: NSMenuItem) {
		guard let id = sender.representedObject as? String,
		let cartridge = self.collection.cartridges.first(where: { $0.id == id }) else {
			fatalError("Failed to find cartridge associated with menu item.")
		}
		self.collection.play(cartridge)
	}
	
	@IBAction func didSelectClearInsertRecentCartridgeMenuItem(_ sender: NSMenuItem) {
		self.collection.cartridges = []
	}
}

// MARK: -
// MARK: Console switches
extension MainMenuController {
	@IBAction func didSelectTVTypeMenuItem(_ sender: NSMenuItem) {
		self.console.switches[.color] = sender.menuIndex == 0
	}
	
	@IBAction func didSelectLeftDifficultyMenuItem(_ sender: NSMenuItem) {
		self.console.switches[.difficulty0] = sender.menuIndex == 0
	}
	
	@IBAction func didSelectRightDifficultyMenuItem(_ sender: NSMenuItem) {
		self.console.switches[.difficulty1] = sender.menuIndex == 0
	}
	
	@IBAction func didSelectGameSelectMenuItem(_ sender: NSMenuItem) {
		self.console.holdSwitch(.select)
	}
	
	@IBAction func didSelectGameResetMenuItem(_ sender: AnyObject) {
		self.console.holdSwitch(.reset)
	}
}

// MARK: -
// MARK: Console reset
extension MainMenuController {
	@IBAction func didSelectResetMenuItem(_ sender: AnyObject) {
		self.console.reset()
	}
}

// MARK: -
// MARK: Menu set up
extension MainMenuController: NSMenuDelegate {
	func menuNeedsUpdate(_ menu: NSMenu) {
		switch menu.identifier {
		case .insertRecentCartridgeMenu:
			menu.items = self.insertRecentCartridgeMenuItems
		case .leftDifficultyMenu:
			menu.selectedItemIndex = self.console
				.switches[.difficulty0] ? 0 : 1
		case .rightDifficultyMenu:
			menu.selectedItemIndex = self.console
				.switches[.difficulty1] ? 0 : 1
		case .tvTypeMenu:
			menu.selectedItemIndex = self.console
				.switches[.color] ? 0 : 1
		default:
			break
		}
	}
	
	private var insertRecentCartridgeMenuItems: [NSMenuItem] {
		var menuItems = self.collection.cartridges
			.map() {
				let menuItem = NSMenuItem()
				menuItem.title = $0.name
				menuItem.representedObject = $0.id
				menuItem.target = self
				menuItem.action = #selector(self.didSelectInsertRecentCartridgeMenuItem(_:))
				return menuItem
			}
		
		// when there's at least one recently opened file
		if let menuItem = menuItems.first {
			// add key shortcut for opening the most recently opened file
			menuItem.keyEquivalentModifierMask = [.command, .option]
			menuItem.keyEquivalent = "o"
			
			// add menu item for clearing the recently opened files menu
			let menuItem = NSMenuItem()
			menuItem.title = "Clear Menu"
			menuItem.target = self
			menuItem.action = #selector(self.didSelectClearInsertRecentCartridgeMenuItem(_:))
			
			menuItems.append(.separator())
			menuItems.append(menuItem)
		}
		
		return menuItems
	}
}

extension MainMenuController: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.identifier {
		case .insertRecentCartridgeMenuItem:
			return self.collection
				.cartridges.count > 0
		default:
			return true
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let insertRecentCartridgeMenu = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenu")
	static let insertRecentCartridgeMenuItem = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenuItem")
	
	static let tvTypeMenu = NSUserInterfaceItemIdentifier("TVTypeMenu")
	static let leftDifficultyMenu = NSUserInterfaceItemIdentifier("LeftDifficultyMenu")
	static let rightDifficultyMenu = NSUserInterfaceItemIdentifier("RightDifficultyMenu")
}

// MARK: -
// MARK: Convenience functionality
private extension NSMenu {
	var selectedItemIndex: Int? {
		get {
			self.items.firstIndex(where: { $0.state == .on })
		}
		set {
			for (index, item) in self.items.enumerated() {
				item.state = index == newValue ? .on : .off
			}
		}
	}
}

private extension NSMenuItem {
	/// Index of this menu item in its container menu.
	var menuIndex: Int? {
		return self.menu?
			.index(of: self)
	}
}

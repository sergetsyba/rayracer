//
//  FrameCounter.swift
//  RayRacer
//
//  Created by Serge Tsyba on 11.11.2025.
//

import os.lock

class FrameCounter {
	private var lock = os_unfair_lock()
	private var count = 0
	
	func value() -> Int {
		os_unfair_lock_lock(&self.lock)
		let count = self.count
		os_unfair_lock_unlock(&self.lock)
		
		return count
	}
	
	func increment() {
		os_unfair_lock_lock(&self.lock)
		self.count += 1
		os_unfair_lock_unlock(&self.lock)
	}
	
	func reset() {
		os_unfair_lock_lock(&self.lock)
		self.count = 0
		os_unfair_lock_unlock(&self.lock)
	}
}

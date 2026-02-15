import SwiftUI
import Foundation
import AppKit
import ServiceManagement



@main
struct PriceyApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	var body: some Scene {
		Settings {
			SettingsView()
		}
		.windowResizability(.contentSize)
		
		MenuBarExtra("Pricey", systemImage: "dollarsign.circle") {
			SettingsLink {
				Text("Settings...")
			}
			.keyboardShortcut(",", modifiers: .command)
			
			Divider()
			
			Button("Quit") {
				NSApplication.shared.terminate(nil)
			}
			.keyboardShortcut("q", modifiers: .command)
		}
	}
	
	static func getMidnightToday() -> Date {
		let calendar = Calendar.current
		let today = Date()
		return calendar.startOfDay(for: today)
	}
}

class AppDelegate: NSObject, NSApplicationDelegate {
	var statusBarItem: NSStatusItem!
	var costTracker = CostTracker()
	var updateTimer: Timer?
	var animatedTotalCost: AnimatedDouble!
	var animatedClaudeCost: AnimatedDouble!
	var timestampThreshold: Date = PriceyApp.getMidnightToday()

	private let formatter = FormatterService.shared
	private let menuBuilder = MenuBuilder()
	private let calculator = UsageCalculator()
	private let jsonlReader = IncrementalJsonlReader()

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.accessory)
		statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		
		animatedTotalCost = AnimatedDouble(initialValue: 0.0) { [weak self] value in
			DispatchQueue.main.async {
				if let button = self?.statusBarItem.button {
					button.title = self?.formatter.formatCurrency(value) ?? "$0.000"
					button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
				}
			}
		}
		
		animatedClaudeCost = AnimatedDouble(initialValue: 0.0) { [weak self] _ in
			DispatchQueue.main.async {
				self?.createMenu()
			}
		}
		
		if let button = statusBarItem.button {
			updateStatusBarTitle()
			button.action = #selector(statusBarButtonClicked)
			button.target = self
		}
		
		createMenu()
		
		updateTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.updateInterval, repeats: true) { _ in
			self.updateStatusBarTitle()
		}
	}
	
	@objc func statusBarButtonClicked() {
	}
	
	func updateStatusBarTitle() {
		_ = sumClaudeInputTokens()
		let totalCost = costTracker.claudeCost
		animatedTotalCost.value = totalCost
		animatedClaudeCost.value = costTracker.claudeCost
	}
	
	func createMenu() {
		let totalUsageStat = getTokenCounts()
		let menu = menuBuilder.buildMenu(with: totalUsageStat, target: self)
		statusBarItem.menu = menu
	}
	
	@objc func emptyCallback() {		
	}
	
	@objc func resetCosts() {
		costTracker.reset()
		animatedTotalCost.value = 0.0
		animatedClaudeCost.value = 0.0
		timestampThreshold = Date()
		
		// Clear cache to force re-reading with new timestamp threshold
		jsonlReader.clearCache()
	}
	
	@objc func openSettings() {
		print("Opening settings window...")
		
		// For status bar apps in macOS 14+, we need to open settings differently
		// Try the keyboard shortcut approach as the most reliable method
		let event = NSEvent.keyEvent(
			with: .keyDown,
			location: .zero,
			modifierFlags: .command,
			timestamp: 0,
			windowNumber: 0,
			context: nil,
			characters: ",",
			charactersIgnoringModifiers: ",",
			isARepeat: false,
			keyCode: 43
		)
		
		if let event = event {
			NSApp.sendEvent(event)
		}
		
		NSApp.activate(ignoringOtherApps: true)
	}
	
	@objc func quitApp() {
		NSApplication.shared.terminate(nil)
	}
	
	func getClaudeProjectDirectories() -> [String] {
		let claudeProjectsPath = AppConstants.Paths.claudeProjectsPath()
		let fileManager = FileManager.default
		
		do {
			let contents = try fileManager.contentsOfDirectory(atPath: claudeProjectsPath)
			return contents.compactMap { item in
				var isDirectory: ObjCBool = false
				let fullPath = "\(claudeProjectsPath)/\(item)"
				if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
					return fullPath
				}
				return nil
			}
		} catch {
			print("exception \(error)")
			return []
		}
	}
	
	func processDirectory(directoryPath: String, seenRequestIds: inout Set<String>) -> UsageStat {
		return jsonlReader.processDirectory(
			directoryPath: directoryPath,
			seenRequestIds: &seenRequestIds,
			timestampThreshold: timestampThreshold
		)
	}
	
	func getTokenCounts() -> UsageStat {
		let startTime = Date()
		var totalUsageStat = UsageStat.zero
		var seenRequestIds = Set<String>()

		let dirListStart = Date()
		let projectDirectories = getClaudeProjectDirectories()
		let dirListTime = Date().timeIntervalSince(dirListStart)
		print("⏱️ Listed \(projectDirectories.count) directories in \(String(format: "%.3f", dirListTime))s")

		for projectDir in projectDirectories {
			let dirStart = Date()
			let directoryUsageStat = processDirectory(directoryPath: projectDir, seenRequestIds: &seenRequestIds)
			let dirTime = Date().timeIntervalSince(dirStart)
			if dirTime > 0.01 {
				print("⏱️ Processed \(projectDir.split(separator: "/").last ?? "?") in \(String(format: "%.3f", dirTime))s")
			}
			totalUsageStat = totalUsageStat + directoryUsageStat
		}

		let totalCost = calculator.calculateCost(from: totalUsageStat)
		costTracker.claudeCost = totalCost

		let totalTime = Date().timeIntervalSince(startTime)
		print("⏱️ TOTAL UPDATE TIME: \(String(format: "%.3f", totalTime))s")
		print("Total tokens calculated in: \(totalUsageStat.inputTokens) out: \(totalUsageStat.outputTokens) cache_creation: \(totalUsageStat.cacheCreationTokens) cache_read: \(totalUsageStat.cacheReadTokens)")
		print("Total usage stats - Lines added: \(totalUsageStat.linesAdded) removed: \(totalUsageStat.linesRemoved)")
		print("Total Claude cost: \(formatter.formatCurrency(totalCost))")
		return totalUsageStat
	}
	
	func sumClaudeInputTokens() -> Int64 {
		let totalUsageStat = getTokenCounts()
		return totalUsageStat.inputTokens
	}
}

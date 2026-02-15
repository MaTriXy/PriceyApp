import AppKit

class MenuBuilder {
	private let formatter = FormatterService.shared
	private let calculator = UsageCalculator()

	func buildMenu(with stats: UsageStat, target: AnyObject) -> NSMenu {
		let menu = NSMenu()

		menu.addItem(createLineStatsItem(stats: stats))
		menu.addItem(createPromptsItem(count: stats.userPrompts))
		menu.addItem(createVibeTimeItem(seconds: stats.timeWaitedForPrompt))
		menu.addItem(createSalaryItem(stats: stats))
		menu.addItem(NSMenuItem.separator())
		addControlItems(to: menu, target: target)

		return menu
	}

	private func createLineStatsItem(stats: UsageStat) -> NSMenuItem {
		let lineStatsString = NSMutableAttributedString()
		lineStatsString.append(NSAttributedString("🧠 Lines changed: "))

		let linesAddedFormatted = formatter.formatNumber(stats.linesAdded)
		let linesRemovedFormatted = formatter.formatNumber(stats.linesRemoved)

		let colors = AppConstants.Colors.self
		lineStatsString.append(NSAttributedString(
			string: "+\(linesAddedFormatted)",
			attributes: [.foregroundColor: NSColor(
				red: CGFloat(colors.linesAdded.red) / 255.0,
				green: CGFloat(colors.linesAdded.green) / 255.0,
				blue: CGFloat(colors.linesAdded.blue) / 255.0,
				alpha: 1.0
			)]
		))

		lineStatsString.append(NSAttributedString(
			string: " -\(linesRemovedFormatted)",
			attributes: [.foregroundColor: NSColor(
				red: CGFloat(colors.linesRemoved.red) / 255.0,
				green: CGFloat(colors.linesRemoved.green) / 255.0,
				blue: CGFloat(colors.linesRemoved.blue) / 255.0,
				alpha: 1.0
			)]
		))

		let item = NSMenuItem()
		item.attributedTitle = lineStatsString
		item.action = #selector(AppDelegate.emptyCallback)
		return item
	}

	private func createPromptsItem(count: Int64) -> NSMenuItem {
		let promptsFormatted = formatter.formatNumber(count)
		let item = NSMenuItem(
			title: "💬 Prompts: \(promptsFormatted)",
			action: #selector(AppDelegate.emptyCallback),
			keyEquivalent: ""
		)
		return item
	}

	private func createVibeTimeItem(seconds: Int64) -> NSMenuItem {
		let timeFormatted = formatter.formatVibeTime(seconds: seconds)
		let item = NSMenuItem(
			title: "⏱️ Vibed for \(timeFormatted) minutes",
			action: #selector(AppDelegate.emptyCallback),
			keyEquivalent: ""
		)
		return item
	}

	private func createSalaryItem(stats: UsageStat) -> NSMenuItem {
		let humanSalary = calculator.calculateHumanSalary(from: stats)
		let humanSalaryFormatted = formatter.formatSalary(humanSalary)
		let item = NSMenuItem(
			title: "🤑 Saved \(humanSalaryFormatted) in Salary",
			action: #selector(AppDelegate.emptyCallback),
			keyEquivalent: ""
		)
		return item
	}

	private func addControlItems(to menu: NSMenu, target: AnyObject) {
		let resetItem = NSMenuItem(
			title: "Reset",
			action: #selector(AppDelegate.resetCosts),
			keyEquivalent: ""
		)
		resetItem.target = target
		menu.addItem(resetItem)

		let settingsItem = NSMenuItem(
			title: "Settings",
			action: #selector(AppDelegate.openSettings),
			keyEquivalent: ","
		)
		settingsItem.target = target
		menu.addItem(settingsItem)

		let quitItem = NSMenuItem(
			title: "Quit",
			action: #selector(AppDelegate.quitApp),
			keyEquivalent: "q"
		)
		quitItem.target = target
		menu.addItem(quitItem)
	}
}

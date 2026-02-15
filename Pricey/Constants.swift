import Foundation

struct AppConstants {
	static let updateInterval: TimeInterval = 5.0
	static let animationDuration: TimeInterval = 1.0
	static let animationFrameRate: Double = 60.0
	static let workDaysPerYear: Double = 260.0

	struct Defaults {
		static let linesPerDay = 100
		static let yearlySalary = 100_000
	}

	struct Colors {
		static let linesAdded = (red: 0x3F, green: 0xBA, blue: 0x50)
		static let linesRemoved = (red: 0xD1, green: 0x24, blue: 0x2F)
	}

	struct Paths {
		static func claudeProjectsPath() -> String {
			let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
			return "\(homeDirectory)/.claude/projects"
		}
	}
}

import Foundation

class UsageCalculator {
	func calculateCost(from usageStat: UsageStat) -> Double {
		var totalCost = 0.0

		for (modelName, modelUsage) in usageStat.modelUsage {
			let pricing = ClaudePricing.pricing(for: modelName)
			let modelCost = (pricing.inputTokenCostPer1 * Double(modelUsage.inputTokens)) +
							(pricing.outputTokenCostPer1 * Double(modelUsage.outputTokens)) +
							(pricing.cacheCreationTokenCostPer1 * Double(modelUsage.cacheCreationTokens)) +
							(pricing.cacheReadTokenCostPer1 * Double(modelUsage.cacheReadTokens))
			totalCost += modelCost
		}

		return totalCost
	}

	func calculateHumanSalary(from usageStat: UsageStat) -> Int {
		let linesPerDay = UserDefaults.standard.integer(forKey: "LinesPerDay")
		let yearlySalary = UserDefaults.standard.integer(forKey: "YearlySalary")

		let effectiveLinesPerDay = linesPerDay > 0 ? linesPerDay : AppConstants.Defaults.linesPerDay
		let effectiveYearlySalary = yearlySalary > 0 ? yearlySalary : AppConstants.Defaults.yearlySalary

		let totalLines = Int(usageStat.linesAdded + usageStat.linesRemoved)
		let daysWorked = ceil(Double(totalLines) / Double(effectiveLinesPerDay))
		let dailySalary = Double(effectiveYearlySalary) / AppConstants.workDaysPerYear
		let humanSalary = daysWorked * dailySalary

		return Int(ceil(humanSalary))
	}
}

import Foundation

struct ClaudePricing {
	let inputTokenCostPer1: Double
	let outputTokenCostPer1: Double
	let cacheCreationTokenCostPer1: Double
	let cacheReadTokenCostPer1: Double

	static var dynamicPricing: [String: ClaudePricing] = [:]

	static let `default` = ClaudePricing(
		inputTokenCostPer1: 3.0 / 1_000_000,
		outputTokenCostPer1: 15.0 / 1_000_000,
		cacheCreationTokenCostPer1: 3.75 / 1_000_000,
		cacheReadTokenCostPer1: 0.30 / 1_000_000
	)

	static func pricing(for modelName: String) -> ClaudePricing {
		if !dynamicPricing.isEmpty, let dynamic = dynamicPricing[modelName] {
			return dynamic
		}

        if modelName != "<synthetic>" {
            NSLog("⚠️ Unknown Claude model encountered: %@", modelName)
        }
        
        return ClaudePricing(
            inputTokenCostPer1: 0.0,
            outputTokenCostPer1: 0.0,
            cacheCreationTokenCostPer1: 0.0,
            cacheReadTokenCostPer1: 0.0
        )
	}
}

import Foundation

class ModelPricingFetcher {
	static let pricingURL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"

	static func fetch() {
		guard let url = URL(string: pricingURL) else { return }
		URLSession.shared.dataTask(with: url) { data, _, error in
			guard let data, error == nil else {
				NSLog("⚠️ Failed to fetch model pricing: %@", error?.localizedDescription ?? "unknown")
				return
			}
			do {
				guard let rawDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
					NSLog("⚠️ Unexpected format for model pricing JSON")
					return
				}
				var pricing: [String: ClaudePricing] = [:]
				for (model, value) in rawDict {
					guard let entry = value as? [String: Any],
						  (entry["litellm_provider"] as? String) == "anthropic",
						  let input = (entry["input_cost_per_token"] as? NSNumber)?.doubleValue,
						  let output = (entry["output_cost_per_token"] as? NSNumber)?.doubleValue else { continue }
					let cacheCreation = (entry["cache_creation_input_token_cost"] as? NSNumber)?.doubleValue ?? 0
					let cacheRead = (entry["cache_read_input_token_cost"] as? NSNumber)?.doubleValue ?? 0
					pricing[model] = ClaudePricing(
						inputTokenCostPer1: input,
						outputTokenCostPer1: output,
						cacheCreationTokenCostPer1: cacheCreation,
						cacheReadTokenCostPer1: cacheRead
					)
				}
				DispatchQueue.main.async {
					ClaudePricing.dynamicPricing = pricing
				}
				NSLog("✅ Loaded pricing for %d Anthropic models", pricing.count)
			} catch {
				NSLog("⚠️ Failed to parse model pricing: %@", error.localizedDescription)
			}
		}.resume()
	}
}

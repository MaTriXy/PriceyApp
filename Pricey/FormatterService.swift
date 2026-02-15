import Foundation

class FormatterService {
	static let shared = FormatterService()

	let currencyFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencyCode = "USD"
		formatter.maximumFractionDigits = 3
		formatter.minimumFractionDigits = 3
		return formatter
	}()

	let numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.maximumFractionDigits = 0
		return formatter
	}()

	let salaryFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencyCode = "USD"
		formatter.maximumFractionDigits = 0
		return formatter
	}()

	func formatCurrency(_ value: Double) -> String {
		return currencyFormatter.string(from: NSNumber(value: value)) ?? "$0.000"
	}

	func formatNumber(_ value: Int64) -> String {
		return numberFormatter.string(from: NSNumber(value: value)) ?? "0"
	}

	func formatSalary(_ value: Int) -> String {
		return salaryFormatter.string(from: NSNumber(value: value)) ?? "$0"
	}

	func formatTokenCount(_ value: Int64) -> String {
		let absValue = Double(abs(value))
		switch absValue {
		case 1_000_000_000...:
			return String(format: "%.1fG", absValue / 1_000_000_000)
		case 1_000_000...:
			return String(format: "%.1fM", absValue / 1_000_000)
		case 1_000...:
			return String(format: "%.1fK", absValue / 1_000)
		default:
			return "\(value)"
		}
	}

	func formatVibeTime(seconds: Int64) -> String {
		let totalMinutes = Int(seconds / 60)
		let minutes = totalMinutes % 60
		let hours = totalMinutes / 60
		return String(format: "%02d:%02d", hours, minutes)
	}
}

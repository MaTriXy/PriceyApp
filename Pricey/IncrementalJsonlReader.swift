import Foundation

struct FileOffsetCache {
	let byteOffset: UInt64
	let usageStat: UsageStat
	let uuidTimestamps: [String: Date]
}

struct DirectoryCache {
	let modificationDate: Date
	let jsonlFiles: [String]
	let fileSizes: [String: UInt64]
	let usageStat: UsageStat
}

class IncrementalJsonlReader {
	private var fileCache: [String: FileOffsetCache] = [:]
	private var directoryCache: [String: DirectoryCache] = [:]
	private let dateFormatter: DateFormatter

	init() {
		dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
	}

	func processDirectory(directoryPath: String, seenRequestIds: inout Set<String>, timestampThreshold: Date) -> UsageStat {
		let fileManager = FileManager.default

		guard let dirModDate = getDirectoryModificationDate(directoryPath: directoryPath) else {
			return UsageStat.zero
		}

		if let cachedDir = directoryCache[directoryPath],
		   cachedDir.modificationDate == dirModDate {
			// print("✅ Cache hit for \(directoryPath.split(separator: "/").last ?? "?")")
			var totalUsageStat = UsageStat.zero
			var needsUpdate = false

			for jsonlFile in cachedDir.jsonlFiles {
				let filePath = "\(directoryPath)/\(jsonlFile)"
				let currentFileSize = getFileSize(filePath: filePath)

				if let cachedFileSize = cachedDir.fileSizes[jsonlFile],
				   cachedFileSize == currentFileSize,
				   let cached = fileCache[filePath] {
					totalUsageStat = totalUsageStat + cached.usageStat
				} else {
					needsUpdate = true
					let usageStat = readFile(
						filePath: filePath,
						seenRequestIds: &seenRequestIds,
						timestampThreshold: timestampThreshold
					)
					totalUsageStat = totalUsageStat + usageStat
				}
			}

			if needsUpdate {
				var fileSizes: [String: UInt64] = [:]
				for jsonlFile in cachedDir.jsonlFiles {
					let filePath = "\(directoryPath)/\(jsonlFile)"
					fileSizes[jsonlFile] = getFileSize(filePath: filePath)
				}

				directoryCache[directoryPath] = DirectoryCache(
					modificationDate: dirModDate,
					jsonlFiles: cachedDir.jsonlFiles,
					fileSizes: fileSizes,
					usageStat: totalUsageStat
				)
			}

			return totalUsageStat
		}

		do {
			print("🔄 Full scan for \(directoryPath.split(separator: "/").last ?? "?")")
			let projectContents = try fileManager.contentsOfDirectory(atPath: directoryPath)
			let jsonlFiles = projectContents.filter { $0.hasSuffix(".jsonl") }
			print("   Found \(jsonlFiles.count) .jsonl files")

			var totalUsageStat = UsageStat.zero
			var fileSizes: [String: UInt64] = [:]

			for jsonlFile in jsonlFiles {
				let filePath = "\(directoryPath)/\(jsonlFile)"
				let usageStat = readFile(
					filePath: filePath,
					seenRequestIds: &seenRequestIds,
					timestampThreshold: timestampThreshold
				)
				totalUsageStat = totalUsageStat + usageStat
				fileSizes[jsonlFile] = getFileSize(filePath: filePath)
			}

			directoryCache[directoryPath] = DirectoryCache(
				modificationDate: dirModDate,
				jsonlFiles: jsonlFiles,
				fileSizes: fileSizes,
				usageStat: totalUsageStat
			)

			return totalUsageStat
		} catch {
			print("Error reading directory \(directoryPath): \(error)")
			return UsageStat.zero
		}
	}

	private func getDirectoryModificationDate(directoryPath: String) -> Date? {
		guard let attributes = try? FileManager.default.attributesOfItem(atPath: directoryPath),
			  let modDate = attributes[.modificationDate] as? Date else {
			return nil
		}
		return modDate
	}


	func readFile(
		filePath: String,
		seenRequestIds: inout Set<String>,
		timestampThreshold: Date
	) -> UsageStat {
		guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
			print("Could not open file: \(filePath)")
			return UsageStat.zero
		}
		defer { fileHandle.closeFile() }

		let fileSize = getFileSize(filePath: filePath)
		let cachedEntry = fileCache[filePath]

		if let cachedEntry = cachedEntry {
			if cachedEntry.byteOffset > fileSize {
				print("File was truncated, resetting cache for: \(filePath)")
				fileCache.removeValue(forKey: filePath)
				return readEntireFile(
					fileHandle: fileHandle,
					filePath: filePath,
					seenRequestIds: &seenRequestIds,
					timestampThreshold: timestampThreshold
				)
			}

			if cachedEntry.byteOffset == fileSize {
				return cachedEntry.usageStat
			}

			return readFromOffset(
				fileHandle: fileHandle,
				filePath: filePath,
				offset: cachedEntry.byteOffset,
				existingUsageStat: cachedEntry.usageStat,
				existingUuidTimestamps: cachedEntry.uuidTimestamps,
				seenRequestIds: &seenRequestIds,
				timestampThreshold: timestampThreshold
			)
		}

		return readEntireFile(
			fileHandle: fileHandle,
			filePath: filePath,
			seenRequestIds: &seenRequestIds,
			timestampThreshold: timestampThreshold
		)
	}

	func clearCache() {
		fileCache.removeAll()
		directoryCache.removeAll()
	}

	private func getFileSize(filePath: String) -> UInt64 {
		guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
			  let fileSize = attributes[.size] as? UInt64 else {
			return 0
		}
		return fileSize
	}

	private func readEntireFile(
		fileHandle: FileHandle,
		filePath: String,
		seenRequestIds: inout Set<String>,
		timestampThreshold: Date
	) -> UsageStat {
		fileHandle.seek(toFileOffset: 0)
		let data = fileHandle.readDataToEndOfFile()
		let (usageStat, uuidTimestamps) = parseJsonlData(
			data: data,
			seenRequestIds: &seenRequestIds,
			timestampThreshold: timestampThreshold,
			existingUuidTimestamps: [:]
		)

		let newOffset = UInt64(data.count)
		fileCache[filePath] = FileOffsetCache(
			byteOffset: newOffset,
			usageStat: usageStat,
			uuidTimestamps: uuidTimestamps
		)

		return usageStat
	}

	private func readFromOffset(
		fileHandle: FileHandle,
		filePath: String,
		offset: UInt64,
		existingUsageStat: UsageStat,
		existingUuidTimestamps: [String: Date],
		seenRequestIds: inout Set<String>,
		timestampThreshold: Date
	) -> UsageStat {
		fileHandle.seek(toFileOffset: offset)
		let newData = fileHandle.readDataToEndOfFile()

		if newData.isEmpty {
			return existingUsageStat
		}

		let (newUsageStat, newUuidTimestamps) = parseJsonlData(
			data: newData,
			seenRequestIds: &seenRequestIds,
			timestampThreshold: timestampThreshold,
			existingUuidTimestamps: existingUuidTimestamps
		)

		let combinedUsageStat = existingUsageStat + newUsageStat
		let combinedUuidTimestamps = existingUuidTimestamps.merging(newUuidTimestamps) { _, new in new }

		let newOffset = offset + UInt64(newData.count)
		fileCache[filePath] = FileOffsetCache(
			byteOffset: newOffset,
			usageStat: combinedUsageStat,
			uuidTimestamps: combinedUuidTimestamps
		)

		return combinedUsageStat
	}

	private func parseJsonlData(
		data: Data,
		seenRequestIds: inout Set<String>,
		timestampThreshold: Date,
		existingUuidTimestamps: [String: Date]
	) -> (UsageStat, [String: Date]) {
		guard let content = String(data: data, encoding: .utf8) else {
			return (UsageStat.zero, [:])
		}

		var usageStat = UsageStat.zero
		var uuidTimestamps = existingUuidTimestamps
		let lines = content.components(separatedBy: .newlines)

		for (lineIndex, line) in lines.enumerated() {
			if line.trimmingCharacters(in: .whitespaces).isEmpty {
				continue
			}

			guard let jsonData = line.data(using: .utf8),
				  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
				print("Line \(lineIndex): Failed to parse JSON")
				continue
			}

			if let requestId = json["requestId"] as? String {
				if seenRequestIds.contains(requestId) {
					continue
				}
				seenRequestIds.insert(requestId)
			}

			guard let timestampString = json["timestamp"] as? String,
				  let timestamp = dateFormatter.date(from: timestampString),
				  timestamp >= timestampThreshold else {
				continue
			}

			if let uuid = json["uuid"] as? String {
				uuidTimestamps[uuid] = timestamp
			}

			let lineStat = parseJsonLine(json: json, uuidTimestamps: uuidTimestamps)
			usageStat = usageStat + lineStat
		}

		return (usageStat, uuidTimestamps)
	}

	private func parseJsonLine(json: [String: Any], uuidTimestamps: [String: Date]) -> UsageStat {
		var inputTokens: Int64 = 0
		var outputTokens: Int64 = 0
		var cacheCreationTokens: Int64 = 0
		var cacheReadTokens: Int64 = 0
		var linesAdded: Int64 = 0
		var linesRemoved: Int64 = 0
		var userPrompts: Int64 = 0
		var timeWaitedForPrompt: Int64 = 0
		var modelName = ""

		if let message = json["message"] as? [String: Any],
		   let usage = message["usage"] as? [String: Any] {
			inputTokens = Int64(usage["input_tokens"] as? Int ?? 0)
			outputTokens = Int64(usage["output_tokens"] as? Int ?? 0)
			cacheCreationTokens = Int64(usage["cache_creation_input_tokens"] as? Int ?? 0)
			cacheReadTokens = Int64(usage["cache_read_input_tokens"] as? Int ?? 0)
			modelName = message["model"] as? String ?? ""
		}

		if let type = json["type"] as? String,
		   type == "user",
		   let message = json["message"] as? [String: Any],
		   let role = message["role"] as? String,
		   role == "user",
		   let _ = message["content"] as? String {
			userPrompts += 1

			if let parentUuid = json["parentUuid"] as? String,
			   let parentTimestamp = uuidTimestamps[parentUuid],
			   let timestampString = json["timestamp"] as? String,
			   let userTimestamp = dateFormatter.date(from: timestampString) {
				let waitTime = Int64(userTimestamp.timeIntervalSince(parentTimestamp))
				timeWaitedForPrompt += waitTime
			}
		}

		if let toolUseResult = json["toolUseResult"] as? [String: Any],
		   let structuredPatch = toolUseResult["structuredPatch"] as? [[String: Any]] {
			if structuredPatch.isEmpty {
				if let type = toolUseResult["type"] as? String, type == "create",
				   let content = toolUseResult["content"] as? String {
					let newlineCount = content.components(separatedBy: "\n").count
					linesAdded += Int64(newlineCount)
				}
			} else {
				for patch in structuredPatch {
					if let patchLines = patch["lines"] as? [String] {
						for patchLine in patchLines {
							if patchLine.hasPrefix("+") {
								linesAdded += 1
							} else if patchLine.hasPrefix("-") {
								linesRemoved += 1
							}
						}
					}
				}
			}
		}

		let modelUsageForThisRequest = ModelUsage(
			inputTokens: inputTokens,
			outputTokens: outputTokens,
			cacheCreationTokens: cacheCreationTokens,
			cacheReadTokens: cacheReadTokens
		)

		return UsageStat(
			inputTokens: inputTokens,
			outputTokens: outputTokens,
			cacheCreationTokens: cacheCreationTokens,
			cacheReadTokens: cacheReadTokens,
			linesAdded: linesAdded,
			linesRemoved: linesRemoved,
			userPrompts: userPrompts,
			timeWaitedForPrompt: timeWaitedForPrompt,
			modelUsage: modelName.isEmpty ? [:] : [modelName: modelUsageForThisRequest]
		)
	}
}

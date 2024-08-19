//
//  File.swift
//  
//
//  Created by Eric Schramm on 11/22/23.
//

import Foundation

enum CSVFileParserError: Error {
    case unableToConvertDataToString
    case dataIntegrityIssues
}

public enum CSVLineError: Error {
    case error(line: [String], error: Error)
}

public struct CSVChunkStats: Sendable {
    public let chunk: Int
    public let linesProcessed: Int
    public let modelsCreated: Int
    public let bytesProcessed: Int
    public let runInterval: DateInterval
    public let memoryAtCompletion: Int
    public let chunkRange: Range<Int>
}

public struct CSVRunStats: Sendable {
    public let wallTime: TimeInterval
    public let cpuTime: TimeInterval
    public let linesProcessed: Int
    public let bytesProcessed: Int
    public let modelsCreated: Int
    public let peakMemoryBytes: Int
    public let chunksCount: Int
}

public struct CSVRunProgress: Sendable {
    public let totalBytes: Int
    public let bytesProcessed: Int
    public let linesProcessed: Int
    public let modelsCreated: Int
    public let peakMemeory: Int
    public let wallTime: TimeInterval
    public let cpuTime: TimeInterval
    
    // for previews
    public init(totalBytes: Int, bytesProcessed: Int, linesProcessed: Int, modelsCreated: Int, peakMemeory: Int, wallTime: TimeInterval, cpuTime: TimeInterval) {
        self.totalBytes = totalBytes
        self.bytesProcessed = bytesProcessed
        self.linesProcessed = linesProcessed
        self.modelsCreated = modelsCreated
        self.peakMemeory = peakMemeory
        self.wallTime = wallTime
        self.cpuTime = cpuTime
    }
    
    public var fractionComplete: Double {
        return Double(bytesProcessed) / Double(totalBytes)
    }
}

actor LineCoordinator<T> {
    
    let liveUpdatingProgress: (@Sendable (CSVRunProgress) -> ())?
    let totalBytes: Int
    
    var chunkPrefixes = [Int : String]()
    var resultsByIndex = [Int : [Result<T, CSVLineError>]]()
    var chunkSuffixes = [Int: String]()
    var chunkStats = [CSVChunkStats]()
    
    init(totalBytes: Int, liveUpdatingProgress: (@Sendable (CSVRunProgress) -> Void)?) {
        self.totalBytes = totalBytes
        self.liveUpdatingProgress = liveUpdatingProgress
        if let liveUpdatingProgress {
            let runProgress = CSVRunProgress(totalBytes: totalBytes, bytesProcessed: 0, linesProcessed: 0, modelsCreated: 0, peakMemeory: 0, wallTime: 0, cpuTime: 0)
            Task {
                await MainActor.run {
                    liveUpdatingProgress(runProgress)
                }
            }
        }
    }
    
    func add(stats: CSVChunkStats, for index: Int) {
        chunkStats.append(stats)
        if let liveUpdatingProgress {
            let runStats = runStats()
            let runProgress = CSVRunProgress(totalBytes: totalBytes, bytesProcessed: runStats.bytesProcessed, linesProcessed: runStats.linesProcessed, modelsCreated: runStats.modelsCreated, peakMemeory: runStats.peakMemoryBytes, wallTime: runStats.wallTime, cpuTime: runStats.cpuTime)
            Task {
                await MainActor.run {
                    liveUpdatingProgress(runProgress)
                }
            }
        }
    }
    
    func add(prefix: String, results: [Result<T, CSVLineError>], suffix: String, for index: Int) {
        chunkPrefixes[index] = prefix
        resultsByIndex[index] = results
        chunkSuffixes[index] = suffix
    }
    
    func runStats() -> CSVRunStats {
        var minDate = Date.distantFuture
        var maxDate = Date.distantPast
        var cpuTime: TimeInterval = 0
        var bytesProcessed = 0
        var linesProcessed = 0
        var modelsCreated = 0
        var peakMemory = 0
        for stats in chunkStats {
            minDate = min(stats.runInterval.start, minDate)
            maxDate = max(stats.runInterval.end, maxDate)
            cpuTime += stats.runInterval.duration
            bytesProcessed += stats.bytesProcessed
            linesProcessed += stats.linesProcessed
            modelsCreated += stats.modelsCreated
            peakMemory = max(stats.memoryAtCompletion, peakMemory)
        }
        return .init(wallTime: minDate.distance(to: maxDate), cpuTime: cpuTime, linesProcessed: linesProcessed, bytesProcessed: bytesProcessed, modelsCreated: modelsCreated, peakMemoryBytes: peakMemory, chunksCount: chunkStats.count)
    }
    
    @available(macOS 13.0, *)
    @available(iOS 16.0, *)
    func statsReport(runStats: CSVRunStats, chunkStats: [CSVChunkStats]) -> String {
        var output =   "CSVFileParser Statistics"
        output +=    "\n------------------------"
        output +=    "\nCPU Time       : \(Duration.seconds(runStats.cpuTime).formatted())"
        output +=    "\nWall Time      : \(Duration.seconds(runStats.wallTime).formatted())"
        output +=    "\nLines Processed: \(runStats.linesProcessed.formatted()) - \(Int(Double(runStats.linesProcessed) / runStats.wallTime).formatted()) / sec"
        output +=    "\nModels Created : \(runStats.modelsCreated.formatted())"
        output +=    "\nBytes Processed: \(runStats.bytesProcessed.formatted(.byteCount(style: .file)))"
        output +=    "\nPeak Memory    : \(runStats.peakMemoryBytes.formatted(.byteCount(style: .memory)))"
        output +=    "\nChunks         : \(runStats.chunksCount)"
        output +=    "\n"
        
        let linesProcessedStats = chunkStats.map({ Double($0.linesProcessed) }).stats()
        output += "Lines Processed per Chunk"
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        output += linesProcessedStats.printAllStats(count: chunkStats.count, numberFormatter: nf)
        output += "\n"
        let cpuTimeStats = chunkStats.map({ $0.runInterval.duration }).stats()
        output += "Processing per Chunk"
        output += cpuTimeStats.printAllStats(count: chunkStats.count, numberFormatter: nf)
        
        return output
    }
    
    func hasIntegrityIssue() -> Bool {
        let ranges = chunkStats.map { $0.chunkRange }.sorted(by: { $0.lowerBound < $1.lowerBound })
        print("Checking integrity of chunk ranges...")
        for i in 1..<ranges.count {
            if ranges[i - 1].upperBound != ranges[i].lowerBound {
                print("INTEGRITY ISSUE! - ranges are not perfecty adjacent as expected")
                return true
            }
        }
        return false
    }
}

/// maps file to memory, only loading when data requested for multi-threaded processing
/// ASSUMES: ALL new line characters ARE new lines, so CSV content cannot have new lines inside the fields
/// Memory will balloon to about double the file size at peak
public actor CSVFileParser {
    
    struct Chunk {
        let index: Int
        let byteRange: Range<Int>
    }
    
    private let data: Data
    private let chunkRanges: [Range<Int>]
    private var lastLineByChunk = [Int : String]()
    private let printUpdates: Bool
    private let skipHeaderRow: Bool
    private let delimiter: Character
    
    /// Initializes the CSVFileParser
    /// - Parameters:
    ///   - url: file location
    ///   - chunkSizeInMBMin: default: 8 MB - will randomly choose base-2 amounts between 1 and 256, bounded to this minimum
    ///   - chunkSizeInMBMax: default: 64 MB - will randomly choose base-2 amounts between 1 and 256, bounded to this maximum
    ///   - printUpdates: send messages to console about progress
    ///   - skipHeaderRow: when processing, assume row 0 is headers and skip sending to modelConverter, default = true
    ///   - modelConverter: converts row of fields ([String]) to output model
    public init(url: URL, chunkSizeInMBMin: Int = 8, chunkSizeInMBMax: Int = 64, printUpdates: Bool = true, skipHeaderRow: Bool = true, overrideDelimiter: Character? = nil) throws {
        data = try Data(contentsOf: url, options: [.alwaysMapped, .uncached])
        
        var startByte = 0
        let fullSet = [1, 2, 4, 8, 12, 16, 24, 36, 48, 64, 96, 128, 192, 256]
        let restrictedSet = fullSet.filter({ $0 >= chunkSizeInMBMin && $0 <= chunkSizeInMBMax })
        var chunks = [Range<Int>]()
        while startByte < data.count {
            let chunkSizeInMB = restrictedSet.randomElement() ?? 8
            let chunkSizeBytes = 1024 * 1000 * chunkSizeInMB
            chunks.append(startByte..<(min(startByte + chunkSizeBytes, data.count)))
            startByte += chunkSizeBytes
        }
        
        self.chunkRanges = chunks
        self.printUpdates = printUpdates
        self.skipHeaderRow = skipHeaderRow
        self.delimiter = overrideDelimiter ?? ","
        
        if printUpdates {
            print("Total Chunks (\(restrictedSet) MB): \(chunkRanges.count)")
        }
    }
    
    /// by default looks thru first 1 kB of data for headers, adjust if longer
    public func headers(readBytes: Int = 1024) throws -> [String] {
        let string = try headerChunk(readBytes: readBytes)
        return string.parseHeaders(overrideDelimiter: delimiter)
    }
    
    /// by default looks thru first 1 kB of data for headers, adjust if longer
    public func headersMayMap<E: RawRepresentable>(stringEnum: E.Type, readBytes: Int = 1024) -> [E : Int] where E.RawValue == String, E : CaseIterable {
        do {
            let string = try headerChunk(readBytes: readBytes)
            return string.headersMayMap(stringEnum: stringEnum, overrideDelimiter: delimiter)
        } catch {
            print("Unable to create string from data")
            return [:]
        }
    }
    
    /// by default looks thru first 1 kB of data for headers, adjust if longer
    public func headersMustMap<E: RawRepresentable>(stringEnum: E.Type, readBytes: Int = 1024) throws -> [E : Int] where E.RawValue == String, E : CaseIterable {
        let string = try headerChunk(readBytes: readBytes)
        return try string.headersMustMap(stringEnum: stringEnum, overrideDelimiter: delimiter)
    }
    
    private func headerChunk(readBytes: Int) throws -> String {
        let endFrame = min(1024, data.count)
        guard let string = String(data: data[0...endFrame], encoding: .utf8) else {
            throw CSVFileParserError.unableToConvertDataToString
        }
        return string
    }
    
    /// Runs the processor with full stats mode
    /// - Parameters:
    ///   - printReport: should a report be printed to the console at completion with run statistics
    ///   - liveUpdatingProgress: an optional closure, called on MainActor, that provides updates of progress - can be used for updating UI
    /// - Returns: a tuple of (processedModels, runStatistics)
    public func csvFileToModelsWithStats<T: Sendable>(printReport: Bool, modelConverter: @escaping @Sendable ([String]) -> Result<T, CSVLineError>, liveUpdatingProgress: (@Sendable (CSVRunProgress) -> ())?) async throws -> (models: [T], errors: [Error], stats: (run: CSVRunStats, chunks: [CSVChunkStats])) {
        let lineCoordinator = LineCoordinator<T>(totalBytes: data.count, liveUpdatingProgress: liveUpdatingProgress)
        let lastChunkIndex = chunkRanges.count - 1
        if liveUpdatingProgress != nil {
            let throttledChunkGroupingCount = 20
            var firstChunk = 0
            while firstChunk <= lastChunkIndex {
                let endChunk = min(firstChunk + throttledChunkGroupingCount - 1, lastChunkIndex + 1)
                try await parseCSVLines(throttledChunks: firstChunk..<endChunk, lineCoordinator: lineCoordinator, modelConverter: modelConverter)
                firstChunk = endChunk
                print("Starting next throttled group...")
            }
        } else {
            try await parseCSVLines(throttledChunks: 0..<(lastChunkIndex + 1), lineCoordinator: lineCoordinator, modelConverter: modelConverter)
        }
    
        var output = [Result<T, CSVLineError>]()
        
        for chunkIndex in 0...lastChunkIndex {
            if chunkIndex == 0 {
                if !skipHeaderRow {
                    output += await lineCoordinator.chunkPrefixes[0]!
                        .parseCSV(overrideDelimiter: delimiter)
                        .map({ modelConverter($0) })
                }
            } else {
                let firstLine = await lineCoordinator.chunkSuffixes[chunkIndex - 1]! + lineCoordinator.chunkPrefixes[chunkIndex]!
                output += firstLine
                    .parseCSV(overrideDelimiter: delimiter)
                    .map({ modelConverter($0) })
            }
            output += await lineCoordinator.resultsByIndex[chunkIndex]!
            if chunkIndex == lastChunkIndex {
                output += await lineCoordinator.chunkSuffixes[lastChunkIndex]!
                    .parseCSV(overrideDelimiter: delimiter
                    )
                    .map({ modelConverter($0) })
            }
        }
        let runStats = await lineCoordinator.runStats()
        let chunks = await lineCoordinator.chunkStats
        if printReport, #available(iOS 16.0, *), #available(macOS 13.0, *) {
            print(await lineCoordinator.statsReport(runStats: runStats, chunkStats: chunks))
        }
        var models = [T]()
        var errors = [Error]()
        for result in output {
            if case let .success(model) = result {
                models.append(model)
            } else if case let .failure(error) = result {
                errors.append(error)
            }
        }
        
        // integrity check
        if await lineCoordinator.hasIntegrityIssue() {
            throw CSVFileParserError.dataIntegrityIssues
        }
        
        return (models: models, errors: errors, stats: (run: runStats, chunks: chunks))
    }
    
    public func csvFileToModels<T : Sendable>(modelConverter: @escaping @Sendable ([String]) -> Result<T, CSVLineError>) async throws -> [T] {
        return try await csvFileToModelsWithStats(printReport: false, modelConverter: modelConverter, liveUpdatingProgress: nil).models
    }
    
    private func parseCSVLines<T : Sendable>(throttledChunks: Range<Int>, lineCoordinator: LineCoordinator<T>, modelConverter: @escaping @Sendable ([String]) -> Result<T, CSVLineError>) async throws {
        return try await withThrowingTaskGroup(of: (Int, CSVChunk<Result<T, CSVLineError>>).self) { group in
            for idx in throttledChunks {  //0..<totalChunks {
                group.addTask {
                    let startTime = Date()
                    let csvChunkModel = try await self.fieldLinesForChunk(chunkIdx: idx)
                    let csvChunk = csvChunkModel.chunk
                    if self.printUpdates, #available(iOS 15.0, *) {
                        print("Starting model conversion for chunk \(idx) - \(csvChunk.lineModels.count.formatted()) lines")
                    }
                    let models = csvChunk.lineModels.map({ modelConverter($0) })
                    if self.printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                        let interval = DateInterval(start: startTime, end: Date())
                        let chunkByteRange = self.chunkRanges[idx]
                        print("Model conversion for chunk \(idx) complete - \(csvChunk.lineModels.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(csvChunk.lineModels.count) / interval.duration).formatted()) / sec) [\(Int((chunkByteRange.upperBound - chunkByteRange.lowerBound) / (1024 * 1000))) MB]")
                    }
                    // adding one to the counts due to partial records at the ends of chunks?
                    let stats = CSVChunkStats(chunk: idx, linesProcessed: csvChunk.lineModels.count + 1, modelsCreated: models.count + 1, bytesProcessed: csvChunkModel.byteCount, runInterval: .init(start: startTime, end: Date()), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: csvChunk.range!)
                    await lineCoordinator.add(stats: stats, for: idx)
                    return (idx, .init(prefix: csvChunk.prefix, lineModels: models, lastLine: csvChunk.lastLine, range: csvChunk.range))
                }
            }
            for try await (chunkIndex, csvChunk) in group {
                await lineCoordinator.add(prefix: csvChunk.prefix, results: csvChunk.lineModels, suffix: csvChunk.lastLine, for: chunkIndex)
                if printUpdates {
                    print("Add \(csvChunk.lineModels.count) models from chunk \(chunkIndex)")
                }
            }
        }
    }
    
    private func fieldLinesForChunk(chunkIdx: Int) throws -> (chunk: CSVChunk<[String]>, byteCount: Int) {
        let chunk = Chunk(index: chunkIdx, byteRange: chunkRanges[chunkIdx])
        let dataChunk = data[chunk.byteRange]
        var byteRange = chunk.byteRange
        if printUpdates {
            print("Chunking data for \(chunkIdx): \(chunk.byteRange) [\(Int((chunk.byteRange.upperBound - chunk.byteRange.lowerBound) / (1024 * 1000))) MB]")
        }
        var string: String? = nil
        if let utf8 = String(data: dataChunk, encoding: .utf8) {
            string = utf8
        } else {
            // so UTF-8 can consist of 1-2-3-4- or 8-byte characters, if this is encountered, we need to try shifting the boundary
            
            print("WARNING: Chunk \(chunkIdx) failed UTF-8 and required bit-shift strategy")
            let shifts = [1, 2, 3, 4, 8]
            // shift end
            for shift in shifts {
                let newRange = chunk.byteRange.lowerBound..<(chunk.byteRange.upperBound + shift)
                print("- attempt \(shift)-byte shift END... \(newRange)")
                let newDataChunk = data[newRange]
                if let newUtf8 = String(data: newDataChunk, encoding: .utf8) {
                    string = newUtf8
                    byteRange = newRange
                    print("  - success!")
                    // print the last 100 characters of the string
                    print(newUtf8[newUtf8.index(newUtf8.endIndex, offsetBy: -200)...])
                    break
                }
            }
            if string == nil {
                // shift start
                
                for shift in shifts {
                    let newRange = (chunk.byteRange.lowerBound + shift)..<chunk.byteRange.upperBound
                    print("- attempt \(shift)-byte shift START... \(newRange)")
                    let newDataChunk = data[newRange]
                    if let newUtf8 = String(data: newDataChunk, encoding: .utf8) {
                        string = newUtf8
                        byteRange = newRange
                        print("  - success!")
                        print(newUtf8[newUtf8.startIndex...newUtf8.index(newUtf8.startIndex, offsetBy: 200)])
                        break
                    }
                }
                
                if string == nil {
                    guard let asciiString = String(data: dataChunk, encoding: .ascii) else {
                        throw CSVFileParserError.unableToConvertDataToString
                    }
                    print("WARNING: using ASCII encoding to work")
                    string = asciiString
                }
            }
        }
        return (chunk: string!.parseCSVFromChunk(overrideDelimiter: delimiter, range: byteRange), byteCount: dataChunk.count)
    }
}

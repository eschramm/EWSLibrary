//
//  File.swift
//
//
//  Created by Eric Schramm on 11/22/23.
//

import Foundation

enum CSVFileParserError: Error {
    case unableToConvertDataToString
    case unableToDecodeChunkAsUTF8(byteRange: Range<Int>)
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
    public let peakMemory: Int
    public let wallTime: TimeInterval
    public let cpuTime: TimeInterval

    // for previews
    public init(totalBytes: Int, bytesProcessed: Int, linesProcessed: Int, modelsCreated: Int, peakMemory: Int, wallTime: TimeInterval, cpuTime: TimeInterval) {
        self.totalBytes = totalBytes
        self.bytesProcessed = bytesProcessed
        self.linesProcessed = linesProcessed
        self.modelsCreated = modelsCreated
        self.peakMemory = peakMemory
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

    private var resultsByIndex = [Int : [Result<T, CSVLineError>]]()
    var chunkStats = [CSVChunkStats]()
    // Track outstanding MainActor progress callbacks so callers can await them
    // instead of sleeping before tearing the coordinator down.
    private var progressTasks = [Task<Void, Never>]()

    init(totalBytes: Int, liveUpdatingProgress: (@Sendable (CSVRunProgress) -> Void)?) {
        self.totalBytes = totalBytes
        self.liveUpdatingProgress = liveUpdatingProgress
        if let liveUpdatingProgress {
            let runProgress = CSVRunProgress(totalBytes: totalBytes, bytesProcessed: 0, linesProcessed: 0, modelsCreated: 0, peakMemory: 0, wallTime: 0, cpuTime: 0)
            progressTasks.append(Task {
                await MainActor.run {
                    liveUpdatingProgress(runProgress)
                }
            })
        }
    }

    func add(stats: CSVChunkStats, for index: Int) {
        chunkStats.append(stats)
        if let liveUpdatingProgress {
            let runStats = runStats()
            let runProgress = CSVRunProgress(totalBytes: totalBytes, bytesProcessed: runStats.bytesProcessed, linesProcessed: runStats.linesProcessed, modelsCreated: runStats.modelsCreated, peakMemory: runStats.peakMemoryBytes, wallTime: runStats.wallTime, cpuTime: runStats.cpuTime)
            progressTasks.append(Task {
                await MainActor.run {
                    liveUpdatingProgress(runProgress)
                }
            })
        }
    }

    func add(results: [Result<T, CSVLineError>], for index: Int) {
        resultsByIndex[index] = results
    }

    /// Awaits any in-flight progress callbacks so they land before the coordinator goes out of scope.
    func waitForProgressUpdates() async {
        for task in progressTasks {
            await task.value
        }
        progressTasks.removeAll()
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

    func sortedKeys() -> [Int] {
        return resultsByIndex.keys.sorted()
    }

    func results(for index: Int) -> [Result<T, CSVLineError>] {
        return resultsByIndex[index] ?? []
    }

    /// Removes and returns a chunk's results so the coordinator's copy can be freed as the
    /// caller drains them — avoids holding the full result set twice at end-of-run.
    func takeResults(for index: Int) -> [Result<T, CSVLineError>] {
        return resultsByIndex.removeValue(forKey: index) ?? []
    }
}

/// maps file to memory, only loading when data requested for multi-threaded processing
/// Memory will balloon to about double the file size at peak
public actor CSVFileParser {

    private let data: Data
    private let printUpdates: Bool
    private let skipHeaderRow: Bool
    private let delimiter: Character
    private let restrictedChunkSizeSet: [Int]
    private let lineChunkSize: Int

    /// Serially scans the memory-mapped file and emits one batch of parsed lines at a time.
    ///
    /// The file cannot be chopped at arbitrary byte offsets (UTF-8 multi-byte sequences and
    /// newlines inside quoted fields would be split), so scanning is inherently serial. Each
    /// `next()` keeps reading variable-sized byte windows — re-feeding the trailing partial line
    /// (`prefix`) into the following window — until at least `lineChunkSize` lines accumulate or
    /// the file ends, then hands that batch off for parallel model conversion.
    private struct ChunkProducer {

        struct LineChunk {
            let index: Int
            let lines: [[String]]
            let chunkStart: Int
            let byteRange: Range<Int>
        }

        let data: Data
        let restrictedChunkSizeSet: [Int]
        let lineChunkSize: Int
        let skipHeaderRow: Bool
        let delimiter: Character
        let printUpdates: Bool

        private var startByte = 0
        private var prefix = ""
        private var firstSet = true
        private var chunkIndex = -1
        private var lastChunkStart = 0

        mutating func next() throws -> LineChunk? {
            guard startByte < data.count else { return nil }
            var lines = [[String]]()
            while startByte < data.count {
                let chunkSizeInMB = restrictedChunkSizeSet.randomElement() ?? 8
                let chunkSizeBytes = 1024 * 1000 * chunkSizeInMB
                var byteRange = startByte..<(min(startByte + chunkSizeBytes, data.count))
                let string = try decodeChunk(byteRange: &byteRange)
                let csvChunk = (prefix + string).parseCSVFromChunk(overrideDelimiter: delimiter, range: byteRange, forceFromStart: true)
                lines.append(contentsOf: csvChunk.lineModels)
                prefix = csvChunk.lastLine
                startByte = byteRange.upperBound

                if lines.count > lineChunkSize || startByte == data.count {
                    chunkIndex += 1
                    if startByte == data.count {
                        // grab the trailing suffix which holds the final line of the CSV
                        lines.append(contentsOf: prefix.parseCSV(overrideDelimiter: delimiter))
                    }
                    let linesToParse: [[String]]
                    if firstSet, skipHeaderRow {
                        linesToParse = Array(lines.dropFirst())
                        firstSet = false
                    } else {
                        linesToParse = lines
                    }
                    let lineChunk = LineChunk(index: chunkIndex, lines: linesToParse, chunkStart: lastChunkStart, byteRange: byteRange)
                    lastChunkStart = byteRange.upperBound
                    return lineChunk
                }
            }
            return nil
        }

        /// Decodes `byteRange` as UTF-8, nudging the upper bound forward by a few bytes if the
        /// window happens to split a multi-byte sequence. Mutates `byteRange` on a successful shift.
        private func decodeChunk(byteRange: inout Range<Int>) throws -> String {
            if let utf8 = String(data: data[byteRange], encoding: .utf8) {
                return utf8
            }
            // UTF-8 characters are 1-4 bytes; a window boundary may land mid-character. Shift the end.
            if printUpdates {
                print("WARNING: Chunk failed UTF-8 and required byte-shift strategy")
            }
            for shift in [1, 2, 3, 4, 8] {
                let newUpperBound = min(byteRange.upperBound + shift, data.count)
                guard newUpperBound > byteRange.upperBound else { continue }
                let newRange = byteRange.lowerBound..<newUpperBound
                if printUpdates {
                    print("- attempt \(shift)-byte shift END... \(newRange)")
                }
                if let newUtf8 = String(data: data[newRange], encoding: .utf8) {
                    byteRange = newRange
                    if printUpdates {
                        print("  - success!")
                    }
                    return newUtf8
                }
            }
            throw CSVFileParserError.unableToDecodeChunkAsUTF8(byteRange: byteRange)
        }
    }

    /// Cap on simultaneously-converting chunks. The serial scanner can run far ahead of the
    /// converters; without a cap, queued parsed-line batches (heavier per byte than the raw
    /// mmap'd data) accumulate unbounded. One in-flight task per core keeps cores busy while
    /// bounding peak memory to roughly `(cores + 1)` line-batches plus the mapped file.
    private var maxConcurrentChunks: Int {
        max(2, ProcessInfo.processInfo.activeProcessorCount)
    }

    /// Initializes the CSVFileParser
    /// - Parameters:
    ///   - url: file location
    ///   - chunkSizeInMBMin: default: 8 MB - will randomly choose base-2 amounts between 1 and 256, bounded to this minimum
    ///   - chunkSizeInMBMax: default: 64 MB - will randomly choose base-2 amounts between 1 and 256, bounded to this maximum
    ///   - lineChunkSize:  default: 60,000 - how often to chunk lines off to model converter operation
    ///   - printUpdates: send messages to console about progress
    ///   - skipHeaderRow: when processing, assume row 0 is headers and skip sending to modelConverter, default = true
    ///   - modelConverter: converts row of fields ([String]) to output model
    public init(url: URL, chunkSizeInMBMin: Int = 8, chunkSizeInMBMax: Int = 64, lineChunkSize: Int = 60_000, printUpdates: Bool = true, skipHeaderRow: Bool = true, overrideDelimiter: Character? = nil) throws {
        data = try Data(contentsOf: url, options: [.alwaysMapped, .uncached])

        let fullSet = [1, 2, 4, 8, 12, 16, 24, 36, 48, 64, 96, 128, 192, 256]
        self.restrictedChunkSizeSet = fullSet.filter({ $0 >= chunkSizeInMBMin && $0 <= chunkSizeInMBMax })
        self.lineChunkSize = lineChunkSize
        self.printUpdates = printUpdates
        self.skipHeaderRow = skipHeaderRow
        self.delimiter = overrideDelimiter ?? ","
    }

    private func makeChunkProducer() -> ChunkProducer {
        ChunkProducer(data: data, restrictedChunkSizeSet: restrictedChunkSizeSet, lineChunkSize: lineChunkSize, skipHeaderRow: skipHeaderRow, delimiter: delimiter, printUpdates: printUpdates)
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
        let endFrame = min(readBytes, data.count)
        guard let string = String(data: data[0..<endFrame], encoding: .utf8) else {
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
        let maxConcurrent = maxConcurrentChunks
        let printUpdates = self.printUpdates

        try await withThrowingTaskGroup(of: (Int, [Result<T, CSVLineError>]).self) { group in
            var producer = makeChunkProducer()
            var inFlight = 0
            while let lineChunk = try producer.next() {
                if inFlight >= maxConcurrent, let (idx, results) = try await group.next() {
                    await lineCoordinator.add(results: results, for: idx)
                    inFlight -= 1
                }
                group.addTask { [printUpdates] in
                    let startTime = Date()
                    if printUpdates, #available(iOS 15.0, *) {
                        print("Starting model conversion for chunk \(lineChunk.index) - \(lineChunk.lines.count.formatted()) lines")
                    }
                    let models = lineChunk.lines.map(modelConverter)
                    let endTime = Date()
                    if printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                        let interval = DateInterval(start: startTime, end: endTime)
                        print("Model conversion for chunk \(lineChunk.index) complete - \(lineChunk.lines.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(lineChunk.lines.count) / interval.duration).formatted()) / sec) [\(Int((lineChunk.byteRange.upperBound - lineChunk.byteRange.lowerBound) / (1024 * 1000))) MB]")
                    }
                    let stats = CSVChunkStats(chunk: lineChunk.index, linesProcessed: lineChunk.lines.count, modelsCreated: models.count, bytesProcessed: lineChunk.byteRange.upperBound - lineChunk.chunkStart, runInterval: .init(start: startTime, end: endTime), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: lineChunk.chunkStart..<lineChunk.byteRange.upperBound)
                    await lineCoordinator.add(stats: stats, for: lineChunk.index)
                    return (lineChunk.index, models)
                }
                inFlight += 1
            }

            for try await (idx, results) in group {
                await lineCoordinator.add(results: results, for: idx)
                if printUpdates {
                    print("Add \(results.count) models from chunk \(idx)")
                }
            }
        }

        let runStats = await lineCoordinator.runStats()
        let chunks = await lineCoordinator.chunkStats
        if printReport, #available(iOS 16.0, *), #available(macOS 13.0, *) {
            print(await lineCoordinator.statsReport(runStats: runStats, chunkStats: chunks))
        }
        await lineCoordinator.waitForProgressUpdates()

        var models = [T]()
        models.reserveCapacity(runStats.modelsCreated)
        var errors = [Error]()

        // Drain chunks in order, freeing each from the coordinator as we go, so we never hold
        // the full result set more than once.
        let indicies = await lineCoordinator.sortedKeys()
        for index in indicies {
            for result in await lineCoordinator.takeResults(for: index) {
                switch result {
                case .success(let model):
                    models.append(model)
                case .failure(let error):
                    errors.append(error)
                }
            }
        }

        return (models: models, errors: errors, stats: (run: runStats, chunks: chunks))
    }

    public func csvFileToModels<T : Sendable>(modelConverter: @escaping @Sendable ([String]) -> Result<T, CSVLineError>) async throws -> [T] {
        return try await csvFileToModelsWithStats(printReport: false, modelConverter: modelConverter, liveUpdatingProgress: nil).models
    }

    /// Allows for processing of the model/errors OUTSIDE of the CSVFileParser, yet awaits completion until complete. This can be useful to operate more in parallel instead of awaiting completion of this to do more work.
    /// - Parameters:
    ///   - printReport: print report to console at completion
    ///   - liveUpdatingProgress: an optional closure, called on MainActor, that provides updates of progress - can be used for updating UI
    ///   - processor: a Sendable async closure that takes the fields and chunkIndex and returns a count of completed models
    /// - Returns: a tuple of run stats and chunk stats
    public func csvFileWithStats(printReport: Bool, liveUpdatingProgress: (@Sendable (CSVRunProgress) -> ())?, processor: @escaping @Sendable ([[String]], Int) async -> Int) async throws -> (run: CSVRunStats, chunks: [CSVChunkStats]) {

        let lineCoordinator = LineCoordinator<[[String]]>(totalBytes: data.count, liveUpdatingProgress: liveUpdatingProgress)
        let maxConcurrent = maxConcurrentChunks
        let printUpdates = self.printUpdates

        try await withThrowingTaskGroup(of: Int.self) { group in
            var producer = makeChunkProducer()
            var inFlight = 0
            while let lineChunk = try producer.next() {
                if inFlight >= maxConcurrent {
                    _ = try await group.next()
                    inFlight -= 1
                }
                group.addTask { [printUpdates] in
                    let startTime = Date()
                    if printUpdates, #available(iOS 15.0, *) {
                        print("Starting model conversion for chunk \(lineChunk.index) - \(lineChunk.lines.count.formatted()) lines")
                    }
                    let modelsProcessed = await processor(lineChunk.lines, lineChunk.index)
                    let endTime = Date()
                    if printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                        let interval = DateInterval(start: startTime, end: endTime)
                        print("Model conversion for chunk \(lineChunk.index) complete - \(lineChunk.lines.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(lineChunk.lines.count) / interval.duration).formatted()) / sec) [\(Int((lineChunk.byteRange.upperBound - lineChunk.byteRange.lowerBound) / (1024 * 1000))) MB]")
                    }
                    let stats = CSVChunkStats(chunk: lineChunk.index, linesProcessed: lineChunk.lines.count, modelsCreated: modelsProcessed, bytesProcessed: lineChunk.byteRange.upperBound - lineChunk.chunkStart, runInterval: .init(start: startTime, end: endTime), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: lineChunk.chunkStart..<lineChunk.byteRange.upperBound)
                    await lineCoordinator.add(stats: stats, for: lineChunk.index)
                    return modelsProcessed
                }
                inFlight += 1
            }

            for try await _ in group { }
        }
        let runStats = await lineCoordinator.runStats()
        let chunks = await lineCoordinator.chunkStats
        if printReport, #available(iOS 16.0, *), #available(macOS 13.0, *) {
            print(await lineCoordinator.statsReport(runStats: runStats, chunkStats: chunks))
        }
        liveUpdatingProgress?(.init(totalBytes: runStats.bytesProcessed, bytesProcessed: runStats.bytesProcessed, linesProcessed: runStats.linesProcessed, modelsCreated: runStats.modelsCreated, peakMemory: runStats.peakMemoryBytes, wallTime: runStats.wallTime, cpuTime: runStats.cpuTime))

        // let any in-flight MainActor progress callbacks land before the coordinator is torn down
        await lineCoordinator.waitForProgressUpdates()

        return (run: runStats, chunks: chunks)
    }
}

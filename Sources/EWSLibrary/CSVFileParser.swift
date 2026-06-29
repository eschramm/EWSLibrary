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

    /// Serially scans the memory-mapped file to find safe record boundaries and emits byte ranges.
    ///
    /// A file cannot be chopped at arbitrary byte offsets — a newline inside a quoted field is not a
    /// record boundary. So we scan serially tracking quote parity and split only at newlines that are
    /// *not* inside quotes. That scan only looks at quote/newline bytes (~GB/s); the expensive field
    /// parsing then happens in parallel inside each chunk's task via `CSVByteParser`. Because each
    /// chunk starts on a record boundary, every chunk is independently parseable from a clean state,
    /// and byte-level scanning is inherently UTF-8 safe (delimiter/quote/newline are single bytes).
    private struct ChunkProducer {

        struct ByteChunk {
            let index: Int
            let isFirst: Bool
            let byteRange: Range<Int>
        }

        let data: Data
        let restrictedChunkSizeSet: [Int]

        private var startByte = 0
        private var chunkIndex = -1
        
        fileprivate init(data: Data, restrictedChunkSizeSet: [Int]) {
            self.data = data
            self.restrictedChunkSizeSet = restrictedChunkSizeSet
        }

        mutating func next() -> ByteChunk? {
            guard startByte < data.count else { return nil }
            let chunkSizeInMB = restrictedChunkSizeSet.randomElement() ?? 8
            let target = min(startByte + 1024 * 1000 * chunkSizeInMB, data.count)
            let boundary = data.withUnsafeBytes { raw -> Int in
                Self.recordBoundary(raw.bindMemory(to: UInt8.self), from: startByte, atLeast: target)
            }
            chunkIndex += 1
            let chunk = ByteChunk(index: chunkIndex, isFirst: chunkIndex == 0, byteRange: startByte..<boundary)
            startByte = boundary
            return chunk
        }

        /// Offset just past the first record-terminating newline at or after `atLeast` (a `\n` seen
        /// while not inside quotes), or `buffer.count` if none. Scans from `from` — itself a record
        /// boundary, so quote state starts even — so quote parity is tracked correctly.
        private static func recordBoundary(_ buffer: UnsafeBufferPointer<UInt8>, from: Int, atLeast: Int) -> Int {
            let quote: UInt8 = 0x22, lf: UInt8 = 0x0A
            let end = buffer.count
            var i = from
            var insideQuotes = false
            while i < end {
                let b = buffer[i]
                if b == quote {
                    insideQuotes.toggle()
                } else if b == lf, !insideQuotes, i >= atLeast {
                    return i + 1
                }
                i += 1
            }
            return end
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
        ChunkProducer(data: data, restrictedChunkSizeSet: restrictedChunkSizeSet)
    }

    private var delimiterByte: UInt8 {
        delimiter.asciiValue ?? UInt8(ascii: ",")
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
        let data = self.data
        let delimiterByte = self.delimiterByte
        let skipHeaderRow = self.skipHeaderRow

        try await withThrowingTaskGroup(of: (Int, [Result<T, CSVLineError>]).self) { group in
            var producer = makeChunkProducer()
            var inFlight = 0
            while let chunk = producer.next() {
                if inFlight >= maxConcurrent, let (idx, results) = try await group.next() {
                    await lineCoordinator.add(results: results, for: idx)
                    inFlight -= 1
                }
                group.addTask { [printUpdates] in
                    let startTime = Date()
                    let rows = data.withUnsafeBytes { raw -> [[String]] in
                        CSVByteParser.parse(raw.bindMemory(to: UInt8.self), range: chunk.byteRange, delimiter: delimiterByte)
                    }
                    let lines = (chunk.isFirst && skipHeaderRow) ? Array(rows.dropFirst()) : rows
                    if printUpdates, #available(iOS 15.0, *) {
                        print("Starting model conversion for chunk \(chunk.index) - \(lines.count.formatted()) lines")
                    }
                    let models = lines.map(modelConverter)
                    let endTime = Date()
                    if printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                        let interval = DateInterval(start: startTime, end: endTime)
                        print("Model conversion for chunk \(chunk.index) complete - \(lines.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(lines.count) / interval.duration).formatted()) / sec) [\(Int((chunk.byteRange.upperBound - chunk.byteRange.lowerBound) / (1024 * 1000))) MB]")
                    }
                    let stats = CSVChunkStats(chunk: chunk.index, linesProcessed: lines.count, modelsCreated: models.count, bytesProcessed: chunk.byteRange.count, runInterval: .init(start: startTime, end: endTime), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: chunk.byteRange)
                    await lineCoordinator.add(stats: stats, for: chunk.index)
                    return (chunk.index, models)
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
        let data = self.data
        let delimiterByte = self.delimiterByte
        let skipHeaderRow = self.skipHeaderRow

        try await withThrowingTaskGroup(of: Int.self) { group in
            var producer = makeChunkProducer()
            var inFlight = 0
            while let chunk = producer.next() {
                if inFlight >= maxConcurrent {
                    _ = try await group.next()
                    inFlight -= 1
                }
                group.addTask { [printUpdates] in
                    let startTime = Date()
                    let rows = data.withUnsafeBytes { raw -> [[String]] in
                        CSVByteParser.parse(raw.bindMemory(to: UInt8.self), range: chunk.byteRange, delimiter: delimiterByte)
                    }
                    let lines = (chunk.isFirst && skipHeaderRow) ? Array(rows.dropFirst()) : rows
                    if printUpdates, #available(iOS 15.0, *) {
                        print("Starting model conversion for chunk \(chunk.index) - \(lines.count.formatted()) lines")
                    }
                    let modelsProcessed = await processor(lines, chunk.index)
                    let endTime = Date()
                    if printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                        let interval = DateInterval(start: startTime, end: endTime)
                        print("Model conversion for chunk \(chunk.index) complete - \(lines.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(lines.count) / interval.duration).formatted()) / sec) [\(Int((chunk.byteRange.upperBound - chunk.byteRange.lowerBound) / (1024 * 1000))) MB]")
                    }
                    let stats = CSVChunkStats(chunk: chunk.index, linesProcessed: lines.count, modelsCreated: modelsProcessed, bytesProcessed: chunk.byteRange.count, runInterval: .init(start: startTime, end: endTime), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: chunk.byteRange)
                    await lineCoordinator.add(stats: stats, for: chunk.index)
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

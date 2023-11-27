//
//  File.swift
//  
//
//  Created by Eric Schramm on 11/22/23.
//

import Foundation

enum CSVFileParserError: Error {
    case indexRequestedBeyondRange(Int, Int)
    case unableToConvertDataToString
}

public struct CSVChunkStats {
    public let chunk: Int
    public let linesProcessed: Int
    public let modelsCreated: Int
    public let bytesProcessed: Int
    public let runInterval: DateInterval
    public let memoryAtCompletion: Int
}

public struct CSVRunStats {
    let wallTime: TimeInterval
    let cpuTime: TimeInterval
    let linesProcessed: Int
    let bytesProcessed: Int
    let modelsCreated: Int
    let peakMemoryBytes: Int
    let chunksCount: Int
}

public struct CSVRunProgress {
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
    
    let liveUpdatingProgress: ((CSVRunProgress) -> ())?
    let totalBytes: Int
    
    var chunkPrefixes = [Int : String]()
    var modelsByIndex = [Int : [T]]()
    var chunkSuffixes = [Int: String]()
    var chunkStats = [CSVChunkStats]()
    
    init(totalBytes: Int, liveUpdatingProgress: ((CSVRunProgress) -> Void)?) {
        self.totalBytes = totalBytes
        self.liveUpdatingProgress = liveUpdatingProgress
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
    
    func add(prefix: String, models: [T], suffix: String, for index: Int) {
        chunkPrefixes[index] = prefix
        modelsByIndex[index] = models
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
    
    func statsReport(runStats: CSVRunStats, chunkStats: [CSVChunkStats]) -> String {
        var output =   "CSVFileParser Statistics"
        output +=    "\n------------------------"
        output +=    "\nCPU Time       : \(runStats.cpuTime.formatted())"
        output +=    "\nWall Time      : \(runStats.wallTime.formatted())"
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
}

/// maps file to memory, only loading when data requested for multi-threaded processing
/// ASSUMES: all new line characters ARE new lines, so CSV content cannot have new lines inside the fields
/// Memory will balloon to about double the file size at peak
public class CSVFileParser<T> {
    
    struct Chunk {
        let index: Int
        let byteRange: Range<Int>
    }
    
    private let data: Data
    private let chunkSizeBytes: Int   // ((1024 * 1000) * 24) = 24 MB
    private let lastChunkIndex: Int
    private var lastLineByChunk = [Int : String]()
    private var lineCoordinator: LineCoordinator<T>?
    private let printUpdates: Bool
    private let skipHeaderRow: Bool
    private let profiler = TimeProfiler()
    
    private let modelConverter: ([String]) -> T?
    
    var totalChunks: Int {
        return lastChunkIndex + 1
    }
    
    /// Initializes the CSVFileParser
    /// - Parameters:
    ///   - url: file location
    ///   - chunkSizeInMB: default: 8 MB
    ///   - printUpdates: send messages to console about progress
    ///   - skipHeaderRow: when processing, assume row 0 is headers and skip sending to modelConverter, default = true
    ///   - modelConverter: converts row of fields ([String]) to output model
    public init(url: URL, chunkSizeInMB: Int = 8, printUpdates: Bool = true, skipHeaderRow: Bool = true, modelConverter: @escaping ([String]) -> T?) throws {
        data = try Data(contentsOf: url, options: [.alwaysMapped, .uncached])
        let chunkSize = 1024 * 1000 * chunkSizeInMB
        chunkSizeBytes = chunkSize
        self.printUpdates = printUpdates
        self.modelConverter = modelConverter
        self.skipHeaderRow = skipHeaderRow
        
        let fullChunks = Int(data.count / chunkSize)
        lastChunkIndex = fullChunks + (data.count % 1024 != 0 ? 1 : 0) - 1  // zero-indexed
        
        if printUpdates {
            print("Total Chunks (\(chunkSizeInMB) MB): \(totalChunks)")
        }
    }
    
    /// by default looks thru first 1 kB of data for headers, adjust if longer
    public func headers(readBytes: Int = 1024) throws -> [String] {
        let string = try headerChunk(readBytes: readBytes)
        return string.parseHeaders()
    }
    
    /// by default looks thru first 1 kB of data for headers, adjust if longer
    public func headersMayMap<E: RawRepresentable>(stringEnum: E.Type, readBytes: Int = 1024) -> [E : Int] where E.RawValue == String, E : CaseIterable {
        do {
            let string = try headerChunk(readBytes: readBytes)
            return string.headersMayMap(stringEnum: stringEnum)
        } catch {
            print("Unable to create string from data")
            return [:]
        }
    }
    
    /// by default looks thru first 1 kB of data for headers, adjust if longer
    public func headersMustMap<E: RawRepresentable>(stringEnum: E.Type, readBytes: Int = 1024) throws -> [E : Int] where E.RawValue == String, E : CaseIterable {
        let string = try headerChunk(readBytes: readBytes)
        return try string.headersMustMap(stringEnum: stringEnum)
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
    public func csvFileToModelsWithStats(printReport: Bool, liveUpdatingProgress: ((CSVRunProgress) -> ())?) async throws -> (models: [T], stats: (run: CSVRunStats, chunks: [CSVChunkStats])) {
        let lineCoordinator = LineCoordinator<T>(totalBytes: data.count, liveUpdatingProgress: liveUpdatingProgress)
        self.lineCoordinator = lineCoordinator
        try await parseCSVLines()
        var output = [T]()
        
        for chunkIndex in 0...lastChunkIndex {
            if chunkIndex == 0 {
                if !skipHeaderRow {
                    output += await lineCoordinator.chunkPrefixes[0]!
                        .parseCSV()
                        .compactMap({ modelConverter($0) })
                }
            } else {
                let firstLine = await lineCoordinator.chunkSuffixes[chunkIndex - 1]! + lineCoordinator.chunkPrefixes[chunkIndex]!
                output += firstLine
                    .parseCSV()
                    .compactMap({ modelConverter($0) })
            }
            output += await lineCoordinator.modelsByIndex[chunkIndex]!
            if chunkIndex == lastChunkIndex {
                output += await lineCoordinator.chunkSuffixes[lastChunkIndex]!
                    .parseCSV()
                    .compactMap({ modelConverter($0) })
            }
        }
        let runStats = await lineCoordinator.runStats()
        let chunks = await lineCoordinator.chunkStats
        if printReport {
            print(await lineCoordinator.statsReport(runStats: runStats, chunkStats: chunks))
        }
        return (models: output, stats: (run: runStats, chunks: chunks))
    }
    
    public func csvFileToModels() async throws -> [T] {
        return try await csvFileToModelsWithStats(printReport: false, liveUpdatingProgress: nil).models
    }
    
    private func parseCSVLines() async throws {
        return try await withThrowingTaskGroup(of: (Int, CSVChunk<T>).self) { group in
            for idx in 0..<totalChunks {
                group.addTask {
                    let startTime = Date()
                    let csvChunkModel = try self.fieldLinesForChunk(chunkIdx: idx)
                    let csvChunk = csvChunkModel.chunk
                    let models = csvChunk.lineModels.compactMap({ self.modelConverter($0) })
                    let stats = CSVChunkStats(chunk: idx, linesProcessed: csvChunk.lineModels.count, modelsCreated: models.count, bytesProcessed: csvChunkModel.byteCount, runInterval: .init(start: startTime, end: Date()), memoryAtCompletion: Process.currentMemory())
                    await self.lineCoordinator?.add(stats: stats, for: idx)
                    return (idx, .init(prefix: csvChunk.prefix, lineModels: models, lastLine: csvChunk.lastLine))
                }
            }
            for try await (chunkIndex, csvChunk) in group {
                await lineCoordinator?.add(prefix: csvChunk.prefix, models: csvChunk.lineModels, suffix: csvChunk.lastLine, for: chunkIndex)
                if printUpdates {
                    print("Add \(csvChunk.lineModels.count) models from chunk \(chunkIndex)")
                }
            }
        }
    }
    
    private func chunk(index: Int) throws -> Chunk {
        guard index <= totalChunks else {
            throw CSVFileParserError.indexRequestedBeyondRange(index, lastChunkIndex)
        }
        let chunkStart = index * chunkSizeBytes
        return .init(index: index, byteRange: chunkStart..<(min(chunkStart + chunkSizeBytes, data.count)))
    }
    
    private func fieldLinesForChunk(chunkIdx: Int) throws -> (chunk: CSVChunk<[String]>, byteCount: Int) {
        let chunk = try chunk(index: chunkIdx)
        let dataChunk = data[chunk.byteRange]
        if printUpdates {
            print("Chunking data for \(chunkIdx): \(chunk.byteRange)")
        }
        let string: String
        if let utf8 = String(data: dataChunk, encoding: .utf8) {
            string = utf8
        } else {
            print("WARNING: Chunk \(chunkIdx) failed UTF-8 an required ASCII encoding")
            guard let asciiString = String(data: dataChunk, encoding: .ascii) else {
                throw CSVFileParserError.unableToConvertDataToString
            }
            string = asciiString
        }
        return (chunk: string.parseCSVFromChunk(), byteCount: dataChunk.count)
    }
}

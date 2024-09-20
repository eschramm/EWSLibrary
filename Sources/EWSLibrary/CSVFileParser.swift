//
//  File.swift
//  
//
//  Created by Eric Schramm on 11/22/23.
//

import Foundation

enum CSVFileParserError: Error {
    case unableToConvertDataToString
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
    
    private var resultsByIndex = NSMutableDictionary()  //[Int : [Result<T, CSVLineError>]]()
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
    
    func add(results: [Result<T, CSVLineError>], for index: Int) {
        resultsByIndex[index] = results
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
        return (resultsByIndex.allKeys as! [Int]).sorted()
    }
    
    func results(for index: Int) -> [Result<T, CSVLineError>] {
        return resultsByIndex[index] as! [Result<T, CSVLineError>]
    }
}

/// maps file to memory, only loading when data requested for multi-threaded processing
/// Memory will balloon to about double the file size at peak
public actor CSVFileParser {
    
    struct Chunk {
        let index: Int
        let byteRange: Range<Int>
    }
    
    private let data: Data
    private let printUpdates: Bool
    private let skipHeaderRow: Bool
    private let delimiter: Character
    private let restrictedChunkSizeSet: [Int]
    private let lineChunkSize: Int
    
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
        
        try await withThrowingTaskGroup(of: (Int, CSVChunk<Result<T, CSVLineError>>).self) { group in
            var startByte = 0
            let lines = NSMutableArray()
            var prefix = ""
            var firstSet = true
            var chunkIndex = -1
            var lastChunkStart = 0
            while startByte < data.count {
                let chunkSizeInMB = restrictedChunkSizeSet.randomElement() ?? 8
                let chunkSizeBytes = 1024 * 1000 * chunkSizeInMB
                var byteRange = startByte..<(min(startByte + chunkSizeBytes, data.count))
                let dataChunk = data[byteRange]
                var string: String!
                if let utf8 = String(data: dataChunk, encoding: .utf8) {
                    string = utf8
                } else {
                    // so UTF-8 can consist of 1-2-3-4- or 8-byte characters, if this is encountered, we need to try shifting the boundary
                    
                    print("WARNING: Chunk failed UTF-8 and required bit-shift strategy")
                    let shifts = [1, 2, 3, 4, 8]
                    // shift end
                    for shift in shifts {
                        let newRange = byteRange.lowerBound..<(byteRange.upperBound + shift)
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
                }
                let csvChunk = (prefix + string).parseCSVFromChunk(overrideDelimiter: delimiter, range: byteRange, forceFromStart: true)
                lines.addObjects(from: csvChunk.lineModels)
                prefix = csvChunk.lastLine
                startByte = byteRange.upperBound
                
                if lines.count > lineChunkSize || startByte == data.count {
                    chunkIndex += 1
                    if startByte == data.count {
                        // need to grab the last suffix which has the last line from the CSV
                        lines.addObjects(from: prefix.parseCSV())
                    }
                    let linesToParse: [[String]]
                    
                    if firstSet, skipHeaderRow {
                        linesToParse = Array((lines as! [[String]]).dropFirst())
                        firstSet = false
                    } else {
                        linesToParse = lines as! [[String]]
                    }
                    
                    // need to ensure we're not carrying any vars into the group task
                    let chunkStart = lastChunkStart
                    let chunkByteRange = byteRange
                    let thisChunkIndex = chunkIndex
                    
                    group.addTask {
                        let startTime = Date()
                        if self.printUpdates, #available(iOS 15.0, *) {
                            print("Starting model conversion for chunk \(thisChunkIndex) - \(linesToParse.count.formatted()) lines")
                        }
                        let models = linesToParse.map({ modelConverter($0) })
                        if self.printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                            let interval = DateInterval(start: startTime, end: Date())
                            print("Model conversion for chunk \(thisChunkIndex) complete - \(linesToParse.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(linesToParse.count) / interval.duration).formatted()) / sec) [\(Int((chunkByteRange.upperBound - chunkByteRange.lowerBound) / (1024 * 1000))) MB]")
                        }
                        // adding one to the counts due to partial records at the ends of chunks?
                        let stats = CSVChunkStats(chunk: thisChunkIndex, linesProcessed: linesToParse.count + 1, modelsCreated: models.count + 1, bytesProcessed: chunkByteRange.upperBound - chunkStart, runInterval: .init(start: startTime, end: Date()), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: chunkStart..<chunkByteRange.upperBound)
                        await lineCoordinator.add(stats: stats, for: thisChunkIndex)
                        return (thisChunkIndex, .init(prefix: csvChunk.prefix, lineModels: models, lastLine: csvChunk.lastLine, range: csvChunk.range))
                    }
                    
                    lines.removeAllObjects()
                    lastChunkStart = byteRange.upperBound
                }
            }
            
            for try await (chunkIndex, csvChunk) in group {
                await lineCoordinator.add(results: csvChunk.lineModels, for: chunkIndex)
                if printUpdates {
                    print("Add \(csvChunk.lineModels.count) models from chunk \(chunkIndex)")
                }
            }
        }
        
        var output = [Result<T, CSVLineError>]()
        let indicies = await lineCoordinator.sortedKeys()
        for index in indicies {
            output += await lineCoordinator.results(for: index)
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
        
        await withThrowingTaskGroup(of: Int.self) { group in
            var startByte = 0
            let lines = NSMutableArray()
            var prefix = ""
            var firstSet = true
            var chunkIndex = -1
            var lastChunkStart = 0

            while startByte < data.count {
                let chunkSizeInMB = restrictedChunkSizeSet.randomElement() ?? 8
                let chunkSizeBytes = 1024 * 1000 * chunkSizeInMB
                var byteRange = startByte..<(min(startByte + chunkSizeBytes, data.count))
                let dataChunk = data[byteRange]
                var string: String!
                if let utf8 = String(data: dataChunk, encoding: .utf8) {
                    string = utf8
                } else {
                    // so UTF-8 can consist of 1-2-3-4- or 8-byte characters, if this is encountered, we need to try shifting the boundary
                    
                    print("WARNING: Chunk failed UTF-8 and required bit-shift strategy")
                    let shifts = [1, 2, 3, 4, 8]
                    // shift end
                    for shift in shifts {
                        let newRange = byteRange.lowerBound..<(byteRange.upperBound + shift)
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
                }
                let csvChunk = (prefix + string).parseCSVFromChunk(overrideDelimiter: delimiter, range: byteRange, forceFromStart: true)
                lines.addObjects(from: csvChunk.lineModels)
                prefix = csvChunk.lastLine
                startByte = byteRange.upperBound
                
                if lines.count > lineChunkSize || startByte == data.count {
                    chunkIndex += 1
                    if startByte == data.count {
                        // need to grab the last suffix which has the last line from the CSV
                        lines.addObjects(from: prefix.parseCSV())
                    }
                    let linesToParse: [[String]]
                    
                    if firstSet, skipHeaderRow {
                        linesToParse = Array((lines as! [[String]]).dropFirst())
                        firstSet = false
                    } else {
                        linesToParse = lines as! [[String]]
                    }
                    
                    // need to ensure we're not carrying any vars into the group task
                    let chunkStart = lastChunkStart
                    let chunkByteRange = byteRange
                    let thisChunkIndex = chunkIndex
                    
                    group.addTask {
                        let startTime = Date()
                        if self.printUpdates, #available(iOS 15.0, *) {
                            print("Starting model conversion for chunk \(thisChunkIndex) - \(linesToParse.count.formatted()) lines")
                        }
                        let modelsProcessed = await processor(linesToParse, thisChunkIndex)
                        if self.printUpdates, #available(iOS 16.0, *), #available(macOS 13.0, *) {
                        let interval = DateInterval(start: startTime, end: Date())
                        print("Model conversion for chunk \(thisChunkIndex) complete - \(linesToParse.count.formatted()) lines in \(Duration.seconds(interval.duration).formatted()) (\(Int(Double(linesToParse.count) / interval.duration).formatted()) / sec) [\(Int((chunkByteRange.upperBound - chunkByteRange.lowerBound) / (1024 * 1000))) MB]")
                        }
                        // adding one to the counts due to partial records at the ends of chunks?
                        let stats = CSVChunkStats(chunk: thisChunkIndex, linesProcessed: linesToParse.count + 1, modelsCreated: modelsProcessed + 1, bytesProcessed: chunkByteRange.upperBound - chunkStart, runInterval: .init(start: startTime, end: Date()), memoryAtCompletion: AppInfo.currentMemory(), chunkRange: chunkStart..<chunkByteRange.upperBound)
                        await lineCoordinator.add(stats: stats, for: thisChunkIndex)
                        return modelsProcessed
                    }
                    lines.removeAllObjects()
                    lastChunkStart = byteRange.upperBound
                }
            }
        }
        let runStats = await lineCoordinator.runStats()
        let chunks = await lineCoordinator.chunkStats
        if printReport, #available(iOS 16.0, *), #available(macOS 13.0, *) {
            print(await lineCoordinator.statsReport(runStats: runStats, chunkStats: chunks))
        }
        liveUpdatingProgress?(.init(totalBytes: runStats.bytesProcessed, bytesProcessed: runStats.bytesProcessed, linesProcessed: runStats.linesProcessed, modelsCreated: runStats.modelsCreated, peakMemeory: runStats.peakMemoryBytes, wallTime: runStats.wallTime, cpuTime: runStats.cpuTime))
        
        // to let any progress updates complete before cleanup of lineCoordinator
        if #available(macOS 13.0, *), #available(iOS 16.0, *) {
            try await Task.sleep(for: .seconds(1))
        }
        
        return (run: runStats, chunks: chunks)
    }
}

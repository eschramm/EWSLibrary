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

actor LineCoordinator<T> {
    var chunkPrefixes = [Int : String]()
    var modelsByIndex = [Int : [T]]()
    var chunkSuffixes = [Int: String]()
    func addPrefix(_ prefix: String, for index: Int) {
        chunkPrefixes[index] = prefix
    }
    func add(models: [T], for index: Int) {
        modelsByIndex[index] = models
    }
    func addSuffix(_ suffix: String, for index: Int) {
        chunkSuffixes[index] = suffix
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
    private let lineCoordinator: LineCoordinator<T> = LineCoordinator()
    private let printUpdates: Bool
    private let skipHeaderRow: Bool
    private let profiler = TimeProfiler()
    private let modelConverter: ([String]) -> T?
    
    var totalChunks: Int {
        return lastChunkIndex + 1
    }
    
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
        let endFrame = max(1024, data.count)
        guard let string = String(data: data[0...endFrame], encoding: .utf8) else {
            throw CSVFileParserError.unableToConvertDataToString
        }
        return string
    }
    
    public func csvFileToModels() async throws -> [T] {
        try await parseCSVLines()
        var output = [T]()
        profiler.stamp(tag: "start assembly")
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
        profiler.stamp(tag: "end assembly")
        print(profiler.report())
        return output
    }
    
    private func parseCSVLines() async throws {
        profiler.stamp(tag: "Start")
        return try await withThrowingTaskGroup(of: (Int, CSVChunk<T>).self) { group in
            for idx in 0..<totalChunks {
                group.addTask {
                    let csvChunk = try self.fieldLinesForChunk(chunkIdx: idx)
                    let models = csvChunk.lineModels.compactMap({ self.modelConverter($0) })
                    return (idx, .init(prefix: csvChunk.prefix, lineModels: models, lastLine: csvChunk.lastLine))
                }
            }
            for try await (chunkIndex, csvChunk) in group {
                await lineCoordinator.addPrefix(csvChunk.prefix, for: chunkIndex)
                await lineCoordinator.add(models: csvChunk.lineModels, for: chunkIndex)
                await lineCoordinator.addSuffix(csvChunk.lastLine, for: chunkIndex)
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
    
    private func fieldLinesForChunk(chunkIdx: Int) throws -> CSVChunk<[String]> {
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
        return string.parseCSVFromChunk()
    }
}

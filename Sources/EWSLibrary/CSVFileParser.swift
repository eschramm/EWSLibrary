//
//  File.swift
//  
//
//  Created by Eric Schramm on 11/22/23.
//

import Foundation

enum FileCSVLineChunkerError: Error {
    case indexRequestedBeyondRange(Int, Int)
    case unableToConvertDataToString
}

actor LineCoordinator {
    var chunkPrefixes = [Int : String]()
    var linesByIndex = [Int : [[String]]]()
    var chunkSuffixes = [Int: String]()
    func addPrefix(_ prefix: String, for index: Int) {
        chunkPrefixes[index] = prefix
    }
    func add(lines: [[String]], for index: Int) {
        linesByIndex[index] = lines
    }
    func addSuffix(_ suffix: String, for index: Int) {
        chunkSuffixes[index] = suffix
    }
}

/// maps file to memory, only loading when data requested for multi-threaded processing
/// ASSUMES: all new line characters ARE new lines, so CSV content cannot have new lines inside the fields
/// Memory will balloon to about double the file size at peak
public class CSVFileParser {
    
    struct Chunk {
        let index: Int
        let byteRange: Range<Int>
    }
    
    private let data: Data
    private let chunkSizeBytes: Int   // ((1024 * 1000) * 24) = 24 MB
    private let lastChunkIndex: Int
    private var lastLineByChunk = [Int : String]()
    private let lineCoordinator = LineCoordinator()
    private let printUpdates: Bool
    private let profiler = TimeProfiler()
    
    var totalChunks: Int {
        return lastChunkIndex + 1
    }
    
    public init(url: URL, chunkSizeInMB: Int = 8, printUpdates: Bool = true) throws {
        data = try Data(contentsOf: url, options: [.alwaysMapped, .uncached])
        let chunkSize = 1024 * 1000 * chunkSizeInMB
        chunkSizeBytes = chunkSize
        self.printUpdates = printUpdates
        
        let fullChunks = Int(data.count / chunkSize)
        lastChunkIndex = fullChunks + (data.count % 1024 != 0 ? 1 : 0) - 1  // zero-indexed
        
        if printUpdates {
            print("Total Chunks (\(chunkSizeInMB) MB): \(totalChunks)")
        }
    }
    
    public func csvLines() async throws -> [[String]] {
        try await parseCSVLines()
        var output = [[String]]()
        profiler.stamp(tag: "start assembly")
        for chunkIndex in 0...lastChunkIndex {
            if chunkIndex == 0 {
                output += await lineCoordinator.chunkPrefixes[0]!.parseCSV()
            } else {
                let firstLine = await lineCoordinator.chunkSuffixes[chunkIndex - 1]! + lineCoordinator.chunkPrefixes[chunkIndex]!
                output += firstLine.parseCSV()
            }
            output += await lineCoordinator.linesByIndex[chunkIndex]!
            if chunkIndex == lastChunkIndex {
                output += await lineCoordinator.chunkSuffixes[lastChunkIndex]!.parseCSV()
            }
        }
        profiler.stamp(tag: "end assembly")
        print(profiler.report())
        return output
    }
    
    private func parseCSVLines() async throws {
        profiler.stamp(tag: "Start")
        return try await withThrowingTaskGroup(of: (Int, CSVChunk).self) { group in
            for idx in 0..<totalChunks {
                group.addTask {
                    let lines = try self.fieldLinesForChunk(chunkIdx: idx)
                    return (idx, lines)
                }
            }
            for try await (chunkIndex, csvChunk) in group {
                await lineCoordinator.addPrefix(csvChunk.prefix, for: chunkIndex)
                await lineCoordinator.add(lines: csvChunk.lineOfFields, for: chunkIndex)
                await lineCoordinator.addSuffix(csvChunk.lastLine, for: chunkIndex)
                if printUpdates {
                    print("Add \(csvChunk.lineOfFields.count) lines from chunk \(chunkIndex)")
                }
            }
        }
    }
    
    private func chunk(index: Int) throws -> Chunk {
        guard index <= totalChunks else {
            throw FileCSVLineChunkerError.indexRequestedBeyondRange(index, lastChunkIndex)
        }
        let chunkStart = index * chunkSizeBytes
        return .init(index: index, byteRange: chunkStart..<(min(chunkStart + chunkSizeBytes, data.count)))
    }
    
    private func fieldLinesForChunk(chunkIdx: Int) throws -> CSVChunk {
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
                throw FileCSVLineChunkerError.unableToConvertDataToString
            }
            string = asciiString
        }
        return string.parseCSVFromChunk()
    }
}

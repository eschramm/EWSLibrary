//
//  CSVByteParser.swift
//  EWSLibrary
//
//  A byte-level CSV parser that operates directly on a UTF-8 buffer (e.g. an
//  mmap'd file) instead of going through Foundation's `Scanner`. It is a faithful
//  translation of the `Scanner`-based `String.parseCSV` state machine in CSV.swift
//  — same field semantics, including the bespoke doubled-quote handling — but
//  ~16x faster single-threaded because it avoids String<->NSString bridging,
//  per-character `CharacterSet` membership tests, and millions of tiny String
//  interpolations.
//
//  Delimiter/quote/newline are single ASCII bytes and can never appear inside a
//  UTF-8 multi-byte sequence, so scanning raw bytes is UTF-8 safe.
//

import Foundation

public enum CSVByteParser {

    private static let quote: UInt8 = 0x22   // "
    private static let lf: UInt8 = 0x0A      // \n
    private static let cr: UInt8 = 0x0D      // \r

    /// Parses `range` of `buffer` into rows of string fields.
    ///
    /// Semantics match `String.parseCSV`:
    /// - a lone `"` toggles "inside quotes" (so delimiters/newlines become literal),
    /// - `""` is an escaped quote when the field already has content, but a standalone
    ///   `""` immediately followed by a delimiter/newline is an empty field,
    /// - newlines inside quotes are normalized to `\n`,
    /// - a trailing delimiter yields a final empty field.
    ///
    /// `\r\n` and lone `\r` are treated as a single record terminator (the `Scanner`
    /// version only handled `\n` cleanly; this is a strict improvement and identical
    /// for LF-only input).
    public static func parse(_ buffer: UnsafeBufferPointer<UInt8>, range: Range<Int>, delimiter: UInt8) -> [[String]] {
        var lines = [[String]]()
        var fields = [String]()
        var field = [UInt8]()
        field.reserveCapacity(64)
        var insideQuotes = false

        var i = range.lowerBound
        let end = range.upperBound

        // Skip a leading UTF-8 BOM (EF BB BF), matching the Scanner's FEFF skip.
        if end - i >= 3, buffer[i] == 0xEF, buffer[i + 1] == 0xBB, buffer[i + 2] == 0xBF {
            i += 3
        }

        @inline(__always) func isSpecial(_ b: UInt8) -> Bool {
            return b == delimiter || b == quote || b == lf || b == cr
        }
        @inline(__always) func flushField() {
            fields.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }

        while i < end {
            let runStart = i
            while i < end, !isSpecial(buffer[i]) { i += 1 }

            guard i < end else {
                // trailing run with no terminator — final line without a newline
                if i > runStart { field.append(contentsOf: buffer[runStart..<i]) }
                break
            }

            let sepPos = i
            let sep = buffer[sepPos]
            i = sepPos + 1
            let textRange = runStart..<sepPos

            if sep == delimiter {
                field.append(contentsOf: buffer[textRange])
                if insideQuotes {
                    field.append(delimiter)
                } else {
                    flushField()
                    if i >= end {
                        // trailing delimiter -> final empty field
                        fields.append("")
                    }
                }
            } else if sep == quote {
                if i < end, buffer[i] == quote {
                    // doubled quote
                    i += 1   // consume the second quote
                    if field.isEmpty && i < end {
                        if buffer[i] == lf || buffer[i] == cr || buffer[i] == delimiter {
                            // standalone "" before a delimiter/newline -> empty field (text discarded, as in Scanner version)
                        } else {
                            field.append(contentsOf: buffer[textRange])
                            field.append(quote)
                        }
                    } else if i >= end {
                        flushField()
                    } else {
                        field.append(contentsOf: buffer[textRange])
                        field.append(quote)
                    }
                } else {
                    insideQuotes.toggle()
                    field.append(contentsOf: buffer[textRange])
                }
            } else {
                // newline (LF, CR, or CRLF)
                if sep == cr, i < end, buffer[i] == lf { i += 1 }
                field.append(contentsOf: buffer[textRange])
                if insideQuotes {
                    field.append(lf)   // normalize embedded newline
                } else {
                    flushField()
                    lines.append(fields)
                    fields = []
                }
            }
        }

        if !field.isEmpty {
            flushField()
        }
        if !fields.isEmpty {
            lines.append(fields)
        }
        return lines
    }

    /// Convenience for `Data` (e.g. an mmap'd file).
    public static func parse(_ data: Data, range: Range<Int>? = nil, delimiter: Character = ",") -> [[String]] {
        guard let ascii = delimiter.asciiValue else {
            preconditionFailure("CSVByteParser requires a single-byte ASCII delimiter")
        }
        return data.withUnsafeBytes { raw -> [[String]] in
            let buffer = raw.bindMemory(to: UInt8.self)
            return parse(buffer, range: range ?? 0..<buffer.count, delimiter: ascii)
        }
    }
}

public extension String {
    /// Byte-level equivalent of `parseCSV`, used for testing equivalence and for callers
    /// that want the faster path on an in-memory string.
    func parseCSVFast(overrideDelimiter: Character? = nil) -> [[String]] {
        let delimiter = overrideDelimiter ?? ","
        guard let ascii = delimiter.asciiValue else {
            preconditionFailure("CSVByteParser requires a single-byte ASCII delimiter")
        }
        let utf8 = Array(self.utf8)
        return utf8.withUnsafeBufferPointer { buffer in
            CSVByteParser.parse(buffer, range: 0..<buffer.count, delimiter: ascii)
        }
    }
}

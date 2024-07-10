//
//  File.swift
//  
//
//  Created by Eric Schramm on 9/17/22.
//

import Foundation

public struct CSVChunk<T> {
    public let prefix: String
    public let lineModels: [T]
    public let lastLine: String
}

public enum CSVError: Error {
    case cannotMakeUTF8StringFromData
    case expectedHeaderNotFound(String)
}

public extension String {
    
    func csvScanner() -> Scanner {
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = ["\u{FEFF}"]  // otherwise skips whitespace by default, but exclude nonBreakingSpace! ARGH
        return scanner
    }
    
    func parseCSV(overrideDelimiter: Character? = nil) -> [[String]] {
        let delimiter = overrideDelimiter ?? ","
        var scanner = csvScanner()
        return parseCSV(scanner: &scanner, quitAfterLines: nil, overrideDelimiter: delimiter).0
    }
    
    func parseCSVFromChunk(overrideDelimiter: Character?) -> CSVChunk<[String]> {
        let delimiter = overrideDelimiter ?? ","
        var scanner = csvScanner()
        let prefix = scanner.scanUpToCharacters(from: .newlines) ?? ""
        _ = scanner.scanCharacter()
        let (linesOfFields, lastLine) = parseCSV(scanner: &scanner, quitAfterLines: nil, overrideDelimiter: delimiter)
        return .init(prefix: prefix, lineModels: linesOfFields.dropLast(), lastLine: lastLine)
    }
    
    func parseHeaders(overrideDelimiter: Character?) -> [String] {
        let delimiter = overrideDelimiter ?? ","
        var scanner = csvScanner()
        return parseCSV(scanner: &scanner, quitAfterLines: 1, overrideDelimiter: delimiter).0[0]
    }
    
    func headersMayMap<E: RawRepresentable>(stringEnum: E.Type, overrideDelimiter: Character?) -> [E : Int] where E.RawValue == String, E : CaseIterable {
        let delimiter = overrideDelimiter ?? ","
        let headersDict = parseHeaders(overrideDelimiter: delimiter).reduce([String : Int]()) { partialResult, header in
            var dict = partialResult
            dict[header] = partialResult.count
            return dict
        }
        var output = [E : Int]()
        for expectedHeader in E.allCases {
            guard let index = headersDict[expectedHeader.rawValue] else {
                print("\(expectedHeader.rawValue) not found in headers")
                continue
            }
            output[expectedHeader] = index
        }
        return output
    }
    
    func headersMustMap<E: RawRepresentable>(stringEnum: E.Type, overrideDelimiter: Character?) throws -> [E : Int] where E.RawValue == String, E : CaseIterable {
        let delimiter = overrideDelimiter ?? ","
        let headersDict = parseHeaders(overrideDelimiter: delimiter).reduce([String : Int]()) { partialResult, header in
            var dict = partialResult
            dict[header] = partialResult.count
            return dict
        }
        var output = [E : Int]()
        for expectedHeader in E.allCases {
            guard let index = headersDict[expectedHeader.rawValue] else {
                throw CSVError.expectedHeaderNotFound(expectedHeader.rawValue)
            }
            output[expectedHeader] = index
        }
        return output
    }
    
    fileprivate func parseCSV(scanner: inout Scanner, quitAfterLines: Int?, overrideDelimiter: Character?) -> ([[String]], lastLine: String) {
        var lines = [[String]]()
        
        let delimiter = overrideDelimiter ?? ","
        let characterSet = CharacterSet([delimiter.unicodeScalars.first!, "\""]).union(.newlines)  // comma, quote, CRLF

        var insideQuotes = false
        var fields = [String]()
        var currentField = ""
        var lastLine = ""

        while !scanner.isAtEnd {
            let text = scanner.scanUpToCharacters(from: characterSet) ?? ""
            let separator = scanner.scanCharacter()
            lastLine += text
            if let separator {
                lastLine += "\(separator)"
            }
            if separator == delimiter {
                if insideQuotes == false {
                    // new field
                    currentField += text
                    fields.append(currentField)
                    currentField = ""
                } else {
                    currentField += "\(text),"
                }
                if scanner.isAtEnd {
                    fields.append("")
                }
            } else if separator == "\"" {
                // scanner item at current index is the next character
                if !scanner.isAtEnd, self[scanner.currentIndex] == "\"" {
                    _ = scanner.scanCharacter()  // consume next quote
                    lastLine += "\(separator!)"
                    if currentField.isEmpty && !scanner.isAtEnd {
                        if self[scanner.currentIndex] == "\n" || self[scanner.currentIndex] == delimiter {
                            // empty string - do nothing
                        } else {
                            currentField = "\(text)\""
                        }
                    } else if scanner.isAtEnd {
                        fields.append(currentField)
                    } else {
                        // escaped quote
                        currentField += "\(text)\""
                    }
                } else {
                    insideQuotes.toggle()
                    currentField += text
                }
            } else {  // CRLF
                if insideQuotes {
                    currentField += "\(text)\n"
                } else {
                    currentField += text
                    fields.append(currentField)
                    lines.append(fields)
                    if let quitAfterLines, lines.count >= quitAfterLines {
                        break
                    }
                    fields = []
                    currentField = ""
                    if !scanner.isAtEnd {
                        lastLine = ""
                    }
                }
            }
        }
        if !currentField.isEmpty {
            fields.append(currentField)
        }
        if !fields.isEmpty {
            lines.append(fields)
        }

        return (lines, lastLine: lastLine)
    }

    func makeCSVsafe(carriageReturnReplacement: String? = nil, overrideDelimiter: Character? = nil) -> String {
        // https://tools.ietf.org/html/rfc4180 - CRs should be allowed in-line if enclosed in outer quotes, double-quotes to escape quotes, Excel abides by this
        let delimiter = overrideDelimiter ?? Character(",")
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil  // otherwise skips whitespace by default
        let characterSet = CharacterSet([delimiter.unicodeScalars.first!, "\""]).union(.newlines)
        var hasCharactersRequiringQuotes = false
        var output = ""
        while !scanner.isAtEnd {
            let text = scanner.scanUpToCharacters(from: characterSet)
            if !scanner.isAtEnd {
                let separator = scanner.scanCharacter()!
                if separator == "\"" {  // add another double-quote
                    output += "\(text ?? "")\"\(separator)"
                    hasCharactersRequiringQuotes = true
                } else if CharacterSet.newlines.contains(separator.unicodeScalars.first!), let crReplacement = carriageReturnReplacement {
                    output += "\(text ?? "")\(crReplacement)"
                } else {
                    output += "\(text ?? "")\(separator)"
                    hasCharactersRequiringQuotes = true
                }
            } else {
                output += (text ?? "")
            }
        }
        if hasCharactersRequiringQuotes {
            return "\"\(output)\""
        } else {
            return output
        }
    }

    @available(*, deprecated, message: "Don't parse CSV by line, use parseCSV() on file string")
    func parseCSVLine() -> [String] {
        var lineFields = [String]()

        let characterSet = CharacterSet([",", "\""])

        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil

        var insideParens = false
        var line = ""
        var lastCharWasQuote = false

        while !scanner.isAtEnd {
            let text = scanner.scanUpToCharacters(from: characterSet)
            let separator = scanner.scanCharacter()

            if separator == "," {
                line += text ?? ""
                if insideParens {
                    line += ","
                } else {
                    lineFields.append(line.scrubFieldForOuterQuotes())
                    line = ""
                }
                lastCharWasQuote = false
            } else if separator == "\"" {
                if lastCharWasQuote {  // escaped
                    line += (text ?? "")
                    lastCharWasQuote = false
                } else {
                    line += "\(text ?? "")\""
                    lastCharWasQuote = true
                }
                insideParens.toggle()
            } else if separator == nil {
                // end of string
                line += text ?? ""
                lineFields.append(line.scrubFieldForOuterQuotes())
                lastCharWasQuote = false
            } else {
                assert(true, "Should never reach this if Scanner is working as expected")
            }
        }
        if !line.isEmpty, lastCharWasQuote {
            lineFields.append(line.scrubFieldForOuterQuotes())
        }
        return lineFields
    }

    func scrubFieldForOuterQuotes() -> String {
        if hasPrefix("\""), hasSuffix("\"") {
            let start = index(startIndex, offsetBy: 1)
            let end = index(endIndex, offsetBy: -1)
            let range = start..<end

            let substring = self[range]

            return String(substring)
        } else {
            return self
        }
    }
}

public extension Array where Element == String {
    mutating func linesAppendingCSVFields(fields: [String], overrideDelimiter: Character? = nil) {
        let delimiter = overrideDelimiter ?? ","
        self.append(fields.map({ $0.makeCSVsafe(overrideDelimiter: overrideDelimiter) }).joined(separator: String(delimiter)))
    }

    func flattenFieldsToCSVLine(overrideDelimiter: Character? = nil) -> String {
        let delimiter = overrideDelimiter ?? ","
        return self.map({ $0.makeCSVsafe(overrideDelimiter: delimiter) }).joined(separator: String(delimiter))
    }
}

//
//  File.swift
//  
//
//  Created by Eric Schramm on 9/17/22.
//

import Foundation

public struct CSVChunk {
    public let prefix: String
    public let lineOfFields: [[String]]
    public let lastLine: String
}

public extension String {
    
    func parseCSV() -> [[String]] {
        var scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = ["\u{FEFF}"]  // otherwise skips whitespace by default, but exclude nonBreakingSpace! ARGH
        return parseCSV(scanner: &scanner).0
    }
    
    func parseCSVFromChunk() -> CSVChunk {
        var scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = ["\u{FEFF}"]  // otherwise skips whitespace by default, but exclude nonBreakingSpace! ARGH
        let prefix = scanner.scanUpToCharacters(from: .newlines) ?? ""
        _ = scanner.scanCharacter()
        let (linesOfFields, lastLine) = parseCSV(scanner: &scanner)
        return .init(prefix: prefix, lineOfFields: linesOfFields.dropLast(), lastLine: lastLine)
    }
    
    fileprivate func parseCSV(scanner: inout Scanner) -> ([[String]], lastLine: String) {
        var lines = [[String]]()
        
        let characterSet = CharacterSet([",", "\""]).union(.newlines)  // comma, quote, CRLF

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
            if separator == "," {
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
                        if self[scanner.currentIndex] == "\n" || self[scanner.currentIndex] == "," {
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

    func makeCSVsafe(carriageReturnReplacement: String? = nil) -> String {
        // https://tools.ietf.org/html/rfc4180 - CRs should be allowed in-line if enclosed in outer quotes, double-quotes to escape quotes, Excel abides by this
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil  // otherwise skips whitespace by default
        let characterSet = CharacterSet([",", "\""]).union(.newlines)
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
    mutating func linesAppendingCSVFields(fields: [String]) {
        self.append(fields.map({ $0.makeCSVsafe() }).joined(separator: ","))
    }

    func flattenFieldsToCSVLine() -> String {
        return self.map({ $0.makeCSVsafe() }).joined(separator: ",")
    }
}

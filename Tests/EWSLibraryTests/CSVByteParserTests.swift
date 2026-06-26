import XCTest
@testable import EWSLibrary

final class CSVByteParserTests: XCTestCase {

    // MARK: - Byte parser equivalence with the Scanner parser

    func testEquivalenceWithScannerCorpus() throws {
        let quadQuotes = "\"\"\"\""
        for separator in [",", "\t"] {
            let csv = """
            this line starts with no quote\(separator)"safely escaped \(separator) comma"\(separator)plain\(separator)""quotes around me in output""\(separator)line ending without quotes
            "this line starts with a quote"\(separator)"safely escaped \(separator) comma"\(separator)plain\(separator)""quotes around me in output""\(separator)"line ending with quotes"
            field1\(separator)"field2 contains a CRLF here
            should still be in field"\(separator)"testing"\(separator)lineEnd
            some empty fields\(separator)""\(separator)\(separator)""
            now test\(separator)last\(separator)""
            test\(separator)end\(separator)ofline\(separator)
            19608\(separator)9816babc\(separator)\(separator)Eric\(separator)\(separator)Schramm\(separator)W\(separator)\(separator)x\(separator)\(separator)2021-08-23T15:29:47Z\(separator){}\(separator)"{""BreatheDayOfWeek"":\(quadQuotes),""CoupleID"":""C127""}"
            """
            let d = Character(separator)
            XCTAssertEqual(csv.parseCSVFast(overrideDelimiter: d), csv.parseCSV(overrideDelimiter: d))
        }
    }

    func testEquivalenceRandomDifferential() throws {
        var rng = SystemRandomNumberGenerator()
        let cells = ["plain", "", "with,comma", "\"quoted\"", "embedded\nnewline", "a\"b", "tab\there", "café", "😀emoji", "  spaces  "]
        for _ in 0..<1000 {
            var rows = [String]()
            for _ in 0..<Int.random(in: 1...8, using: &rng) {
                var fields = [String]()
                for _ in 0..<Int.random(in: 1...6, using: &rng) {
                    fields.append(cells.randomElement(using: &rng)!.makeCSVsafe())
                }
                rows.append(fields.joined(separator: ","))
            }
            let csv = rows.joined(separator: "\n")
            XCTAssertEqual(csv.parseCSVFast(), csv.parseCSV(), "differential mismatch on:\n\(csv)")
        }
    }

    /// Documents a known divergence: the Scanner parser double-emits a field made only of escaped
    /// quotes at EOF (it appends `currentField` in the isAtEnd branch and again post-loop without
    /// clearing it). The byte parser emits it once, which is correct.
    func testByteParserFixesScannerDoubleEmitBug() throws {
        let csv = "a,\"\"\"\"\"\""
        XCTAssertEqual(csv.parseCSV(), [["a", "\"\"", "\"\""]])      // Scanner: buggy duplicate
        XCTAssertEqual(csv.parseCSVFast(), [["a", "\"\""]])          // byte parser: correct
    }

    // MARK: - Fast UTC date parser

    func testFastDateMatchesFormatter() throws {
        for str in ["2025-10-22 14:56:45.000", "1971-01-01 00:00:00.000", "2024-02-29 23:59:59.999", "2000-06-15 09:05:07.123"] {
            let fast = Date.fromExportExplorerUTC(str)
            let df = DateFormatter.exportExplorer.date(from: str)
            XCTAssertNotNil(fast)
            XCTAssertEqual(fast!.timeIntervalSince1970, df!.timeIntervalSince1970, accuracy: 0.0005, "mismatch for \(str)")
        }
    }

    func testFastDateRejectsOffFormat() {
        XCTAssertNil(Date.fromExportExplorerUTC("2021-08-23T15:29:47Z"))
        XCTAssertNil(Date.fromExportExplorerUTC("2025-10-22 14:56:45"))
        XCTAssertNil(Date.fromExportExplorerUTC(""))
        XCTAssertNil(Date.fromExportExplorerUTC("2025-13-22 14:56:45.000"))  // bad month
    }
}

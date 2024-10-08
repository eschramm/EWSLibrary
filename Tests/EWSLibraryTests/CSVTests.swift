//
//  CSVTests.swift
//  RKStudioExportParserTests
//
//  Created by Eric Schramm on 2/23/21.
//  Copyright © 2021 careevolution. All rights reserved.
//

import XCTest
@testable import EWSLibrary

class CSVTests: XCTestCase {

    func testCSVcreation() throws {
        let testSimple = "make me CSV safe"
        XCTAssertEqual(testSimple, testSimple.makeCSVsafe())
        
        let testComma = "make me, CSV safe"
        XCTAssertEqual("\"\(testComma)\"", testComma.makeCSVsafe())
        
        let testCR = "make me\nCSV safe"
        XCTAssertEqual("\"\(testCR)\"", testCR.makeCSVsafe())
        XCTAssertEqual("make me<CR>CSV safe", testCR.makeCSVsafe(carriageReturnReplacement: "<CR>"))
        
        let testSimpleTab = "make me CSV safe"
        XCTAssertEqual(testSimpleTab, testSimple.makeCSVsafe(overrideDelimiter: "\t"))
        
        let testTab = "make me\t CSV safe"
        XCTAssertEqual("\"\(testTab)\"", testTab.makeCSVsafe(overrideDelimiter: "\t"))
        
        XCTAssertEqual("\"\(testCR)\"", testCR.makeCSVsafe(overrideDelimiter: "\t"))
        XCTAssertEqual("make me<CR>CSV safe", testCR.makeCSVsafe(carriageReturnReplacement: "<CR>", overrideDelimiter: "\t"))
    }
    
    func testCSVLineParsing() throws {
        let testSimple = "foo,bar"
        XCTAssertEqual(["foo", "bar"], testSimple.parseCSVLine())
        let testQuotedComma = "foo,\"bar, tavern, pub\""
        XCTAssertEqual(["foo", "bar, tavern, pub"], testQuotedComma.parseCSVLine())
        /*
        let testEtsyFailCase =
        """
        "Sale Date","Order ID",Status,"Buyer User ID",SKU
        """
        XCTAssertEqual(["Sale Date", "Order ID", "Status", "Buyer User ID", "SKU"], testEtsyFailCase.parseCSVLine())
        */
    }
    
    func testCSVParsing() throws {
        let quadQuotes = "\"\"\"\""
        var separator = ","
        let csvString =
        """
        this line starts with no quote\(separator)"safely escaped \(separator) comma"\(separator)plain\(separator)""quotes around me in output""\(separator)line ending without quotes
        "this line starts with a quote"\(separator)"safely escaped \(separator) comma"\(separator)plain\(separator)""quotes around me in output""\(separator)"line ending with quotes"
        field1\(separator)"field2 contains a CRLF here
        should still be in field"\(separator)"testing"\(separator)lineEnd
        some empty fields\(separator)""\(separator)\(separator)""
        now test\(separator)last\(separator)""
        test\(separator)end\(separator)ofline\(separator)
        ParticipantIdentifier\(separator)GlobalKey\(separator)EmailAddress\(separator)FirstName\(separator)MiddleName\(separator)LastName\(separator)Gender\(separator)DateOfBirth\(separator)SecondaryIdentifier\(separator)PostalCode\(separator)EnrollmentDate\(separator)EventDates\(separator)CustomFields
        19608\(separator)9816babc\(separator)\(separator)Eric\(separator)\(separator)Schramm\(separator)W\(separator)\(separator)x\(separator)\(separator)2021-08-23T15:29:47Z\(separator){}\(separator)"{""BreatheDayOfWeek"":\(quadQuotes),""BreatheHourOfDay"":\(quadQuotes),""BreatheLastPush"":\(quadQuotes),""CurrentStepGoal"":\(quadQuotes),""LastDateWithStandHours"":\(quadQuotes),""LastDateWithSteps"":\(quadQuotes),""CoupleID"":""C127"",""LivesWithAnotherParticipant"":""False"",""Over75"":""False"",""SurveyDevice"":""iPhone"",""HasAppleWatch"":""True"",""ParticipatingAsCouple"":""True""}"
        """
        
        separator = "\t"
        let csvStringTab =
        """
        this line starts with no quote\(separator)"safely escaped \(separator) comma"\(separator)plain\(separator)""quotes around me in output""\(separator)line ending without quotes
        "this line starts with a quote"\(separator)"safely escaped \(separator) comma"\(separator)plain\(separator)""quotes around me in output""\(separator)"line ending with quotes"
        field1\(separator)"field2 contains a CRLF here
        should still be in field"\(separator)"testing"\(separator)lineEnd
        some empty fields\(separator)""\(separator)\(separator)""
        now test\(separator)last\(separator)""
        test\(separator)end\(separator)ofline\(separator)
        ParticipantIdentifier\(separator)GlobalKey\(separator)EmailAddress\(separator)FirstName\(separator)MiddleName\(separator)LastName\(separator)Gender\(separator)DateOfBirth\(separator)SecondaryIdentifier\(separator)PostalCode\(separator)EnrollmentDate\(separator)EventDates\(separator)CustomFields
        19608\(separator)9816babc\(separator)\(separator)Eric\(separator)\(separator)Schramm\(separator)W\(separator)\(separator)x\(separator)\(separator)2021-08-23T15:29:47Z\(separator){}\(separator)"{""BreatheDayOfWeek"":\(quadQuotes),""BreatheHourOfDay"":\(quadQuotes),""BreatheLastPush"":\(quadQuotes),""CurrentStepGoal"":\(quadQuotes),""LastDateWithStandHours"":\(quadQuotes),""LastDateWithSteps"":\(quadQuotes),""CoupleID"":""C127"",""LivesWithAnotherParticipant"":""False"",""Over75"":""False"",""SurveyDevice"":""iPhone"",""HasAppleWatch"":""True"",""ParticipatingAsCouple"":""True""}"
        """
        
        var parsedFields = csvString.parseCSV()
        
        // overall check
        XCTAssertEqual(parsedFields.count, 8)
        XCTAssertEqual(parsedFields[0].count, 5)
        XCTAssertEqual(parsedFields[1].count, 5)
        XCTAssertEqual(parsedFields[2].count, 4)
        
        var line1fields = parsedFields[0]
        XCTAssertEqual(line1fields[0], "this line starts with no quote")
        var line2fields = parsedFields[1]
        XCTAssertEqual(line2fields[0], "this line starts with a quote")
        
        XCTAssertEqual(line1fields[1], "safely escaped , comma")
        XCTAssertEqual(line2fields[1], "safely escaped , comma")
        
        XCTAssertEqual(line1fields[2], "plain")
        XCTAssertEqual(line2fields[2], "plain")
        
        XCTAssertEqual(line1fields[3], "\"quotes around me in output\"")
        XCTAssertEqual(line2fields[3], "\"quotes around me in output\"")
        
        XCTAssertEqual(line1fields[4], "line ending without quotes")
        XCTAssertEqual(line2fields[4], "line ending with quotes")
        
        var line3fields = parsedFields[2]
        XCTAssertEqual(line3fields[1], "field2 contains a CRLF here\nshould still be in field")
        
        var line4fields = parsedFields[3]
        XCTAssertEqual(line4fields[1], "")
        XCTAssertEqual(line4fields[2], "")
        XCTAssertEqual(line4fields[3], "")
        
        var line5fields = parsedFields[4]
        XCTAssertEqual(line5fields[2], "")
        XCTAssertEqual(line5fields.count, 3)
        
        var line6fields = parsedFields[5]
        XCTAssertEqual(line6fields.count, 4)
        
        var line8fields = parsedFields[7]
        XCTAssert(line8fields[12].hasPrefix("{"))
        
        // repeat
        
        parsedFields = csvStringTab.parseCSV(overrideDelimiter: "\t")
        
        // overall check
        XCTAssertEqual(parsedFields.count, 8)
        XCTAssertEqual(parsedFields[0].count, 5)
        XCTAssertEqual(parsedFields[1].count, 5)
        XCTAssertEqual(parsedFields[2].count, 4)
        
        line1fields = parsedFields[0]
        XCTAssertEqual(line1fields[0], "this line starts with no quote")
        line2fields = parsedFields[1]
        XCTAssertEqual(line2fields[0], "this line starts with a quote")
        
        print(line1fields)
        XCTAssertEqual(line1fields[1], "safely escaped , comma")
        XCTAssertEqual(line2fields[1], "safely escaped , comma")
        
        XCTAssertEqual(line1fields[2], "plain")
        XCTAssertEqual(line2fields[2], "plain")
        
        XCTAssertEqual(line1fields[3], "\"quotes around me in output\"")
        XCTAssertEqual(line2fields[3], "\"quotes around me in output\"")
        
        XCTAssertEqual(line1fields[4], "line ending without quotes")
        XCTAssertEqual(line2fields[4], "line ending with quotes")
        
        line3fields = parsedFields[2]
        XCTAssertEqual(line3fields[1], "field2 contains a CRLF here\nshould still be in field")
        
        line4fields = parsedFields[3]
        XCTAssertEqual(line4fields[1], "")
        XCTAssertEqual(line4fields[2], "")
        XCTAssertEqual(line4fields[3], "")
        
        line5fields = parsedFields[4]
        XCTAssertEqual(line5fields[2], "")
        XCTAssertEqual(line5fields.count, 3)
        
        line6fields = parsedFields[5]
        XCTAssertEqual(line6fields.count, 4)
        
        line8fields = parsedFields[7]
        XCTAssert(line8fields[12].hasPrefix("{"))
    }
    
    func testCSVChunk() throws {
        let sampleOneLine = """
                         "sensorkit-ambient-light-sensor","AppleWatch","MDH-6315-8983","57152181-62DC-463C-AB4B-91ABB7F89235","2023-11-07 21:51:31.000","-0600","2023-11-08 21:25:27.000","-0600","{""name"": ""Eric\\u2019s Apple\\u00a0Watch Series 8"", ""productType"": ""Watch6,15"", ""systemVersion"": ""10.1"", ""model"": ""Apple Watch"", ""systemName"": ""Watch OS""}","{""timestamp"":1699471879000,""sample"":{""lux"":71,""chromaticity"":{""x"":0,""y"":0},""placement"":""FrontTopRight""}}","sensorkit-ambient-light-sensor/AppleWatch/MDH-6315-8983/57152181-62DC-463C-AB4B-91ABB7F89235/2023-11-07T155131-0600_2023-11-08T152527-0600","{exportstartdate=2023-10-01T00:00:00+00:00, s3key=RK.95853084.SK Low Data/4daa074c-b5d8-4286-bb30-e6be5c2f4ef0, updatedate=2023-11-16T17:43:55.361631+00:00, s3bucket=pep-rkstudio-export, appversion=1.0.0, exportenddate=2023-11-17T00:00:00+00:00}"
                         """
        
        let sample = [sampleOneLine, sampleOneLine, sampleOneLine].joined(separator: "\n")
        let output = sample.parseCSVFromChunk(overrideDelimiter: ",", range: nil)
        XCTAssertEqual(output.prefix, sampleOneLine)
        XCTAssertEqual(output.lineModels, sampleOneLine.parseCSV())
        XCTAssertEqual(output.lastLine, sampleOneLine)
    }
    
    func testHeaders() throws {
        
        let csvString = """
                        "Mailing Address",First,Last,"Dumb, but legal",this is also legal
                        "371 Oak St",Eric,Schramm,myself,"butthead face"
                        """
        XCTAssertEqual(csvString.parseHeaders(overrideDelimiter: ","),["Mailing Address", "First" , "Last", "Dumb, but legal", "this is also legal"])
        
        enum TestFields: String, CaseIterable {
            case first = "First"
            case thisIsAlsoLegal = "this is also legal"
            case mailingAddress = "Mailing Address"
            case dumbButLegal = "Dumb, but legal"
            case notInHeader = "not in header"
        }
        
        let expectedOutput: [TestFields : Int] = [
            .mailingAddress: 0,
            .first: 1,
            .dumbButLegal: 3,
            .thisIsAlsoLegal: 4
        ]
        
        XCTAssertEqual(csvString.headersMayMap(stringEnum: TestFields.self, overrideDelimiter: ","), expectedOutput)
        
        XCTAssertThrowsError(try csvString.headersMustMap(stringEnum: TestFields.self, overrideDelimiter: ","))
    }

    static var allTests = [
        ("testCSVcreation", testCSVcreation),
        ("testCSVLineParsing", testCSVLineParsing),
        ("testCSVParsing", testCSVParsing)
    ]
}


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
        let csvString =
        """
        this line starts with no quote,"safely escaped , comma",plain,""quotes around me in output"",line ending without quotes
        "this line starts with a quote","safely escaped , comma",plain,""quotes around me in output"","line ending with quotes"
        field1,"field2 contains a CRLF here
        should still be in field","testing",lineEnd
        some empty fields,"",,""
        now test,last,""
        test,end,ofline,
        ParticipantIdentifier,GlobalKey,EmailAddress,FirstName,MiddleName,LastName,Gender,DateOfBirth,SecondaryIdentifier,PostalCode,EnrollmentDate,EventDates,CustomFields
        19608,9816babc,,Eric,,Schramm,W,,x,,2021-08-23T15:29:47Z,{},"{""BreatheDayOfWeek"":\(quadQuotes),""BreatheHourOfDay"":\(quadQuotes),""BreatheLastPush"":\(quadQuotes),""CurrentStepGoal"":\(quadQuotes),""LastDateWithStandHours"":\(quadQuotes),""LastDateWithSteps"":\(quadQuotes),""CoupleID"":""C127"",""LivesWithAnotherParticipant"":""False"",""Over75"":""False"",""SurveyDevice"":""iPhone"",""HasAppleWatch"":""True"",""ParticipatingAsCouple"":""True""}"
        """
        
        let parsedFields = csvString.parseCSV()
        
        // overall check
        XCTAssertEqual(parsedFields.count, 8)
        XCTAssertEqual(parsedFields[0].count, 5)
        XCTAssertEqual(parsedFields[1].count, 5)
        XCTAssertEqual(parsedFields[2].count, 4)
        
        let line1fields = parsedFields[0]
        XCTAssertEqual(line1fields[0], "this line starts with no quote")
        let line2fields = parsedFields[1]
        XCTAssertEqual(line2fields[0], "this line starts with a quote")
        
        XCTAssertEqual(line1fields[1], "safely escaped , comma")
        XCTAssertEqual(line2fields[1], "safely escaped , comma")
        
        XCTAssertEqual(line1fields[2], "plain")
        XCTAssertEqual(line2fields[2], "plain")
        
        XCTAssertEqual(line1fields[3], "\"quotes around me in output\"")
        XCTAssertEqual(line2fields[3], "\"quotes around me in output\"")
        
        XCTAssertEqual(line1fields[4], "line ending without quotes")
        XCTAssertEqual(line2fields[4], "line ending with quotes")
        
        let line3fields = parsedFields[2]
        XCTAssertEqual(line3fields[1], "field2 contains a CRLF here\nshould still be in field")
        
        let line4fields = parsedFields[3]
        XCTAssertEqual(line4fields[1], "")
        XCTAssertEqual(line4fields[2], "")
        XCTAssertEqual(line4fields[3], "")
        
        let line5fields = parsedFields[4]
        XCTAssertEqual(line5fields[2], "")
        XCTAssertEqual(line5fields.count, 3)
        
        let line6fields = parsedFields[5]
        XCTAssertEqual(line6fields.count, 4)
        
        let line8fields = parsedFields[7]
        XCTAssert(line8fields[12].hasPrefix("{"))
    }

    static var allTests = [
        ("testCSVcreation", testCSVcreation),
        ("testCSVLineParsing", testCSVLineParsing),
        ("testCSVParsing", testCSVParsing)
    ]
}


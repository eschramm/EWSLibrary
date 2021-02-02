//
//  EWSLibraryiOSTestAppUITests.swift
//  EWSLibraryiOSTestAppUITests
//
//  Created by Eric Schramm on 9/2/19.
//  Copyright © 2019 eware. All rights reserved.
//

import XCTest

class EWSLibraryiOSTestAppUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTagCloudFunctionality() {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
                        app.launch()
        
        let tablesQuery = XCUIApplication().tables
        let oneButton = app.staticTexts["One"]
        let threeHundredButton = app.staticTexts["Three Hundred"]
        let twentyOneButton = app.staticTexts["Twenty-one"]
        
        XCTAssertEqual(oneButton.exists, true)
        XCTAssertEqual(threeHundredButton.exists, false)
        
        // add Three Hundred
        tablesQuery.cells.children(matching: .button).element.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Three Hundred"]/*[[".cells.staticTexts[\"Three Hundred\"]",".staticTexts[\"Three Hundred\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        XCTAssertEqual(oneButton.exists, true)
        XCTAssertEqual(threeHundredButton.exists, true)
        XCTAssertEqual(twentyOneButton.exists, false)
        
        // remove One
        oneButton.tap()
        XCTAssertEqual(oneButton.exists, false)
        XCTAssertEqual(threeHundredButton.exists, true)
        XCTAssertEqual(twentyOneButton.exists, false)
        
        // search 'th'
        tablesQuery.cells.children(matching: .button).element.tap()
        
        let twentyButton = app.staticTexts["Twenty"]
        let fourThousandButton = app.staticTexts["Four Thousand"]
        let fiftyThousandButton = app.staticTexts["Fifty Thousand"]
        let sixHundredThousandButton = app.staticTexts["Six Hundred Thousand"]
        let sevenMillionButton = app.staticTexts["Seven Million"]
        let eightyMillionButton = app.staticTexts["Eighty Million"]
        
        XCTAssertEqual(twentyButton.exists, true)
        XCTAssertEqual(fourThousandButton.exists, true)
        XCTAssertEqual(fiftyThousandButton.exists, true)
        XCTAssertEqual(sixHundredThousandButton.exists, true)
        XCTAssertEqual(sevenMillionButton.exists, true)
        XCTAssertEqual(eightyMillionButton.exists, true)
        
        let searchField: XCUIElement
        if #available(iOS 13.0, *) {
            searchField = tablesQuery.children(matching: .other).element.children(matching: .other).element.children(matching: .searchField).element
        } else {
            searchField = tablesQuery.children(matching: .other).element.children(matching: .searchField).element
        }
        searchField.tap()
        searchField.typeText("th")
        
        XCTAssertEqual(twentyButton.exists, false)
        XCTAssertEqual(fourThousandButton.exists, true)
        XCTAssertEqual(fiftyThousandButton.exists, true)
        XCTAssertEqual(sixHundredThousandButton.exists, true)
        XCTAssertEqual(sevenMillionButton.exists, false)
        XCTAssertEqual(eightyMillionButton.exists, false)
        
        // add new tag Twenty-one
        
        searchField.tap()
        searchField.buttons["Clear text"].tap()
        searchField.typeText("Twenty-one")
        app.buttons["Add \"Twenty-one\""].tap()
        XCTAssertEqual(oneButton.exists, false)
        XCTAssertEqual(threeHundredButton.exists, true)
        XCTAssertEqual(twentyOneButton.exists, true)
    }

    func testLaunchPerformance() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
                XCUIApplication().launch()
            }
        }
    }
}

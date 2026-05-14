//
//  TokenReplacementTests.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 5/14/26.
//

import XCTest
@testable import EWSLibrary

final class TokenReplacementTests: XCTestCase {
    
    // MARK: - Simple Token Tests
    
    func testSimpleTokenReplacement() {
        let template = "Hello {{name}}!"
        let dict = ["name": "Alice"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Hello Alice!")
    }
    
    func testMultipleSimpleTokens() {
        let template = "{{greeting}} {{name}}, welcome to {{place}}!"
        let dict = [
            "greeting": "Hello",
            "name": "Bob",
            "place": "Wonderland"
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Hello Bob, welcome to Wonderland!")
    }
    
    func testMissingToken() {
        let template = "Hello {{name}}!"
        let dict = ["otherKey": "value"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Hello !")
    }
    
    func testEmptyTemplate() {
        let template = ""
        let dict = ["name": "Alice"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "")
    }
    
    func testNoTokens() {
        let template = "This is a plain string with no tokens."
        let dict = ["name": "Alice"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "This is a plain string with no tokens.")
    }
    
    func testEmptyDictionary() {
        let template = "Hello {{name}}!"
        let dict: [String: Any] = [:]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Hello !")
    }
    
    // MARK: - Nested Dictionary Tests
    
    func testNestedDictionaryAccess() {
        let template = "City: {{address.city}}"
        let dict: [String: Any] = [
            "address": ["city": "San Francisco"]
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "City: San Francisco")
    }
    
    func testDeeplyNestedDictionaryAccess() {
        let template = "{{user.profile.location.city}}"
        let dict: [String: Any] = [
            "user": [
                "profile": [
                    "location": [
                        "city": "New York"
                    ]
                ]
            ]
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "New York")
    }
    
    func testMultipleNestedTokens() {
        let template = "{{user.name}} lives in {{user.address.city}}, {{user.address.state}}"
        let dict: [String: Any] = [
            "user": [
                "name": "Charlie",
                "address": [
                    "city": "Boston",
                    "state": "MA"
                ]
            ]
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Charlie lives in Boston, MA")
    }
    
    func testMissingNestedKey() {
        let template = "City: {{address.city}}"
        let dict: [String: Any] = [
            "address": ["street": "123 Main St"]
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "City: ")
    }
    
    func testMissingParentKey() {
        let template = "City: {{address.city}}"
        let dict: [String: Any] = [
            "name": "Alice"
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "City: ")
    }
    
    // MARK: - Date Formatting Tests
    
    func testDateFormatted() {
        let template = "Date: {{eventDate|formatted}}"
        let date = Date(timeIntervalSince1970: 1620000000) // May 2, 2021, 10:40:00 PM (GMT)
        let dict: [String: Any] = ["eventDate": date]
        let result = template.replacingTokens(dict: dict)
        // Result will vary based on locale, but should not be empty
        XCTAssertTrue(result.hasPrefix("Date: "))
        XCTAssertNotEqual(result, "Date: ")
    }
    
    func testDateFormattedShort() {
        let template = "Date: {{eventDate|formattedDateShort}}"
        let date = Date(timeIntervalSince1970: 1620000000)
        let dict: [String: Any] = ["eventDate": date]
        let result = template.replacingTokens(dict: dict)
        XCTAssertTrue(result.hasPrefix("Date: "))
        XCTAssertNotEqual(result, "Date: ")
        // Should be numeric date without time
        XCTAssertFalse(result.contains("PM") || result.contains("AM"))
    }
    
    func testTimeFormattedShort() {
        let template = "Time: {{eventDate|formattedTimeShort}}"
        let date = Date(timeIntervalSince1970: 1620000000)
        let dict: [String: Any] = ["eventDate": date]
        let result = template.replacingTokens(dict: dict)
        XCTAssertTrue(result.hasPrefix("Time: "))
        XCTAssertNotEqual(result, "Time: ")
    }
    
    func testDateFormattingWithNonDate() {
        let template = "Date: {{value|formatted}}"
        let dict: [String: Any] = ["value": "not a date"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Date: ")
    }
    
    // MARK: - Number Formatting Tests
    
    func testDoubleFormatted() {
        let template = "Value: {{amount|formatted}}"
        let dict: [String: Any] = ["amount": 1234.56]
        let result = template.replacingTokens(dict: dict)
        XCTAssertTrue(result.hasPrefix("Value: "))
        XCTAssertTrue(result.contains("1234") || result.contains("1,234"))
    }
    
    func testCurrencyFormattedDouble() {
        let template = "Price: {{amount|formattedCurrency}}"
        let dict: [String: Any] = ["amount": 1234.56]
        let result = template.replacingTokens(dict: dict)
        XCTAssertTrue(result.hasPrefix("Price: "))
        // Should contain currency symbol and formatted number
        XCTAssertNotEqual(result, "Price: ")
        XCTAssertTrue(result.contains("1234") || result.contains("1,234"))
    }
    
    func testCurrencyFormattedDecimal() {
        let template = "Price: {{amount|formattedCurrency}}"
        let dict: [String: Any] = ["amount": Decimal(99.99)]
        let result = template.replacingTokens(dict: dict)
        XCTAssertTrue(result.hasPrefix("Price: "))
        XCTAssertNotEqual(result, "Price: ")
        XCTAssertTrue(result.contains("99"))
    }
    
    func testCurrencyFormattingWithNonNumber() {
        let template = "Price: {{value|formattedCurrency}}"
        let dict: [String: Any] = ["value": "not a number"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Price: ")
    }
    
    // MARK: - Mixed Type Tests
    
    func testMixedTypes() {
        let template = "{{name}} has {{count}} items"
        let dict: [String: Any] = [
            "name": "Alice",
            "count": 42
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Alice has 42 items")
    }
    
    func testBooleanValue() {
        let template = "Active: {{isActive}}"
        let dict: [String: Any] = ["isActive": true]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Active: true")
    }
    
    // MARK: - Edge Cases
    
    func testAdjacentTokens() {
        let template = "{{first}}{{second}}"
        let dict = ["first": "Hello", "second": "World"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "HelloWorld")
    }
    
    func testTokenWithSpaces() {
        let template = "Hello {{ name }}!"
        let dict = [" name ": "Alice"]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "Hello Alice!")
    }
    
    func testPartialTokenSyntax() {
        let template = "This has {{incomplete"
        let dict = ["incomplete": "value"]
        let result = template.replacingTokens(dict: dict)
        // Scanner should handle this gracefully
        XCTAssertTrue(result.contains("This has"))
    }
    
    func testSingleBraces() {
        let template = "This {has} single {braces}"
        let dict: [String: Any] = [:]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "This {has} single {braces}")
    }
    
    func testNestedBraces() {
        let template = "{{outer{{inner}}}}"
        let dict = ["inner": "value"]
        let result = template.replacingTokens(dict: dict)
        // This is an edge case - behavior may vary
        // Just ensure it doesn't crash
        XCTAssertNotNil(result)
    }
    
    // MARK: - Real-World Examples
    
    func testEmailTemplate() {
        let template = """
        Dear {{user.name}},
        
        Your order #{{order.id}} has been shipped!
        
        Items: {{order.itemCount}}
        Total: {{order.total|formattedCurrency}}
        
        Estimated delivery: {{delivery.date|formattedDateShort}}
        
        Thank you for your order!
        """
        
        let dict: [String: Any] = [
            "user": ["name": "Alice"],
            "order": [
                "id": "12345",
                "itemCount": 3,
                "total": 149.97
            ],
            "delivery": [
                "date": Date(timeIntervalSince1970: 1620000000)
            ]
        ]
        
        let result = template.replacingTokens(dict: dict)
        XCTAssertTrue(result.contains("Dear Alice"))
        XCTAssertTrue(result.contains("order #12345"))
        XCTAssertTrue(result.contains("Items: 3"))
        XCTAssertTrue(result.contains("Total:"))
        XCTAssertTrue(result.contains("149") || result.contains("150"))
    }
    
    func testRecipeInstruction() {
        let template = "You made {{proportion.itemCount|formattedInt}} items at {{proportion.ratio}}x proportion!"
        let dict: [String: Any] = [
            "proportion": [
                "itemCount": 12,
                "ratio": 1.5
            ]
        ]
        let result = template.replacingTokens(dict: dict)
        XCTAssertEqual(result, "You made 12 items at 1.5x proportion!")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceLargeTemplate() {
        let template = String(repeating: "{{token}}", count: 1000)
        let dict = ["token": "value"]
        
        measure {
            _ = template.replacingTokens(dict: dict)
        }
    }
    
    func testPerformanceLargeDictionary() {
        let template = "Hello {{name}}!"
        var dict: [String: Any] = [:]
        for i in 0..<1000 {
            dict["key\(i)"] = "value\(i)"
        }
        dict["name"] = "Alice"
        
        measure {
            _ = template.replacingTokens(dict: dict)
        }
    }
}

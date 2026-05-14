//
//  TokenContextTests.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 5/14/26.
//

import XCTest
@testable import EWSLibrary

@MainActor
final class TokenContextTests: XCTestCase {
    
    var tokenContext: TokenContext!
    
    override func setUp() async throws {
        tokenContext = TokenContext()
    }
    
    override func tearDown() async throws {
        tokenContext = nil
    }
    
    // MARK: - Basic Operations
    
    func testSetAndGetValue() {
        tokenContext.setValue("Alice", forKey: "name")
        XCTAssertEqual(tokenContext.values["name"] as? String, "Alice")
    }
    
    func testSetMultipleValues() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue(25, forKey: "age")
        tokenContext.setValue(true, forKey: "active")
        
        XCTAssertEqual(tokenContext.values["name"] as? String, "Alice")
        XCTAssertEqual(tokenContext.values["age"] as? Int, 25)
        XCTAssertEqual(tokenContext.values["active"] as? Bool, true)
    }
    
    func testOverwriteValue() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue("Bob", forKey: "name")
        
        XCTAssertEqual(tokenContext.values["name"] as? String, "Bob")
    }
    
    func testRemoveValue() {
        tokenContext.setValue("Alice", forKey: "name")
        XCTAssertNotNil(tokenContext.values["name"])
        
        tokenContext.removeValue(forKey: "name")
        XCTAssertNil(tokenContext.values["name"])
    }
    
    func testClear() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue(25, forKey: "age")
        tokenContext.setValue(true, forKey: "active")
        
        XCTAssertEqual(tokenContext.values.count, 3)
        
        tokenContext.clear()
        XCTAssertEqual(tokenContext.values.count, 0)
    }
    
    // MARK: - Flat Dictionary Tests
    
    func testFlatDictionary() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue(25, forKey: "age")
        
        let flat = tokenContext.flatDictionary
        XCTAssertEqual(flat["name"] as? String, "Alice")
        XCTAssertEqual(flat["age"] as? Int, 25)
    }
    
    func testFlatDictionaryWithDotNotation() {
        tokenContext.setValue("San Francisco", forKey: "address.city")
        tokenContext.setValue("CA", forKey: "address.state")
        
        let flat = tokenContext.flatDictionary
        XCTAssertEqual(flat["address.city"] as? String, "San Francisco")
        XCTAssertEqual(flat["address.state"] as? String, "CA")
    }
    
    // MARK: - Token Dictionary Tests
    
    func testTokenDictionarySimpleKeys() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue(25, forKey: "age")
        
        let dict = tokenContext.tokenDictionary()
        XCTAssertEqual(dict["name"] as? String, "Alice")
        XCTAssertEqual(dict["age"] as? Int, 25)
    }
    
    func testTokenDictionaryNestedKeys() {
        tokenContext.setValue("San Francisco", forKey: "address.city")
        tokenContext.setValue("CA", forKey: "address.state")
        tokenContext.setValue("94102", forKey: "address.zipCode")
        
        let dict = tokenContext.tokenDictionary()
        
        guard let address = dict["address"] as? [String: Any] else {
            XCTFail("address should be a nested dictionary")
            return
        }
        
        XCTAssertEqual(address["city"] as? String, "San Francisco")
        XCTAssertEqual(address["state"] as? String, "CA")
        XCTAssertEqual(address["zipCode"] as? String, "94102")
    }
    
    func testTokenDictionaryDeeplyNestedKeys() {
        tokenContext.setValue("Alice", forKey: "user.profile.name")
        tokenContext.setValue("alice@example.com", forKey: "user.profile.email")
        tokenContext.setValue("premium", forKey: "user.subscription.tier")
        
        let dict = tokenContext.tokenDictionary()
        
        guard let user = dict["user"] as? [String: Any],
              let profile = user["profile"] as? [String: Any],
              let subscription = user["subscription"] as? [String: Any] else {
            XCTFail("Nested structure should be created")
            return
        }
        
        XCTAssertEqual(profile["name"] as? String, "Alice")
        XCTAssertEqual(profile["email"] as? String, "alice@example.com")
        XCTAssertEqual(subscription["tier"] as? String, "premium")
    }
    
    func testTokenDictionaryMixedSimpleAndNested() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue("San Francisco", forKey: "address.city")
        tokenContext.setValue(25, forKey: "age")
        
        let dict = tokenContext.tokenDictionary()
        
        XCTAssertEqual(dict["name"] as? String, "Alice")
        XCTAssertEqual(dict["age"] as? Int, 25)
        
        guard let address = dict["address"] as? [String: Any] else {
            XCTFail("address should be a nested dictionary")
            return
        }
        
        XCTAssertEqual(address["city"] as? String, "San Francisco")
    }
    
    // MARK: - Integration with String Token Replacement
    
    func testIntegrationWithSimpleTokenReplacement() {
        tokenContext.setValue("Alice", forKey: "name")
        tokenContext.setValue(25, forKey: "age")
        
        let template = "Hello {{name}}, you are {{age}} years old."
        let result = template.replacingTokens(dict: tokenContext.tokenDictionary())
        
        XCTAssertEqual(result, "Hello Alice, you are 25 years old.")
    }
    
    func testIntegrationWithNestedTokenReplacement() {
        tokenContext.setValue("San Francisco", forKey: "address.city")
        tokenContext.setValue("CA", forKey: "address.state")
        
        let template = "Location: {{address.city}}, {{address.state}}"
        let result = template.replacingTokens(dict: tokenContext.tokenDictionary())
        
        XCTAssertEqual(result, "Location: San Francisco, CA")
    }
    
    func testIntegrationWithFormattedValues() {
        let date = Date(timeIntervalSince1970: 1620000000)
        tokenContext.setValue(date, forKey: "eventDate")
        tokenContext.setValue(1234.56, forKey: "price")
        
        let template = "Event on {{eventDate|formattedDateShort}} - Price: {{price|formattedCurrency}}"
        let result = template.replacingTokens(dict: tokenContext.tokenDictionary())
        
        XCTAssertTrue(result.contains("Event on"))
        XCTAssertTrue(result.contains("Price:"))
        XCTAssertTrue(result.contains("1234") || result.contains("1,234"))
    }
    
    func testIntegrationComplexScenario() {
        // Recipe proportions scenario
        tokenContext.setValue(1.5, forKey: "proportion.ratio")
        tokenContext.setValue(12, forKey: "proportion.itemCount")
        tokenContext.setValue("cookies", forKey: "recipe.name")
        tokenContext.setValue(350, forKey: "recipe.temperature")
        
        let template = """
        Recipe: {{recipe.name}}
        You made {{proportion.itemCount}} items at {{proportion.ratio}}x proportion!
        Bake at {{recipe.temperature}}°F.
        """
        
        let result = template.replacingTokens(dict: tokenContext.tokenDictionary())
        
        XCTAssertTrue(result.contains("Recipe: cookies"))
        XCTAssertTrue(result.contains("You made 12 items at 1.5x proportion!"))
        XCTAssertTrue(result.contains("Bake at 350°F."))
    }
    
    // MARK: - Type Tests
    
    func testVariousTypes() {
        tokenContext.setValue("string", forKey: "string")
        tokenContext.setValue(42, forKey: "int")
        tokenContext.setValue(3.14, forKey: "double")
        tokenContext.setValue(true, forKey: "bool")
        tokenContext.setValue(Date(), forKey: "date")
        tokenContext.setValue(Decimal(99.99), forKey: "decimal")
        
        XCTAssertEqual(tokenContext.values.count, 6)
        
        XCTAssertTrue(tokenContext.values["string"] is String)
        XCTAssertTrue(tokenContext.values["int"] is Int)
        XCTAssertTrue(tokenContext.values["double"] is Double)
        XCTAssertTrue(tokenContext.values["bool"] is Bool)
        XCTAssertTrue(tokenContext.values["date"] is Date)
        XCTAssertTrue(tokenContext.values["decimal"] is Decimal)
    }
    
    func testArrayValue() {
        let array = ["item1", "item2", "item3"]
        tokenContext.setValue(array, forKey: "items")
        
        XCTAssertNotNil(tokenContext.values["items"])
        
        let template = "Items: {{items}}"
        let result = template.replacingTokens(dict: tokenContext.tokenDictionary())
        
        // Array should be converted to string representation
        XCTAssertTrue(result.contains("Items:"))
    }
    
    func testDictionaryValue() {
        let nestedDict = ["key": "value"]
        tokenContext.setValue(nestedDict, forKey: "data")
        
        XCTAssertNotNil(tokenContext.values["data"])
    }
    
    // MARK: - Edge Cases
    
    func testEmptyKey() {
        tokenContext.setValue("value", forKey: "")
        XCTAssertEqual(tokenContext.values[""] as? String, "value")
    }
    
    func testKeyWithSpecialCharacters() {
        tokenContext.setValue("value", forKey: "key!@#$%")
        XCTAssertEqual(tokenContext.values["key!@#$%"] as? String, "value")
    }
    
    func testMultipleDotsInKey() {
        tokenContext.setValue("value", forKey: "a.b.c.d.e")
        
        let dict = tokenContext.tokenDictionary()
        
        guard let a = dict["a"] as? [String: Any],
              let b = a["b"] as? [String: Any],
              let c = b["c"] as? [String: Any],
              let d = c["d"] as? [String: Any] else {
            XCTFail("Deep nesting should be created")
            return
        }
        
        XCTAssertEqual(d["e"] as? String, "value")
    }
    
    func testTrailingDot() {
        tokenContext.setValue("value", forKey: "key.")
        
        let dict = tokenContext.tokenDictionary()
        
        // Should handle gracefully - exact behavior may vary
        XCTAssertNotNil(dict["key"])
    }
    
    func testLeadingDot() {
        tokenContext.setValue("value", forKey: ".key")
        
        let dict = tokenContext.tokenDictionary()
        
        // Should handle gracefully
        XCTAssertTrue(dict.count > 0)
    }
    
    // MARK: - ObservableObject Tests
    
    func testPublishedValuesUpdate() async throws {
        let expectation = XCTestExpectation(description: "Published value changed")
        
        var receivedValue = false
        let cancellable = tokenContext.objectWillChange.sink { _ in
            receivedValue = true
            expectation.fulfill()
        }
        
        tokenContext.setValue("test", forKey: "key")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedValue)
        
        cancellable.cancel()
    }
    
    func testMultipleUpdatesPublish() async throws {
        var updateCount = 0
        let expectation = XCTestExpectation(description: "Multiple updates")
        expectation.expectedFulfillmentCount = 3
        
        let cancellable = tokenContext.objectWillChange.sink { _ in
            updateCount += 1
            expectation.fulfill()
        }
        
        tokenContext.setValue("value1", forKey: "key1")
        tokenContext.setValue("value2", forKey: "key2")
        tokenContext.setValue("value3", forKey: "key3")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(updateCount, 3)
        
        cancellable.cancel()
    }
    
    // MARK: - Real-World Use Cases
    
    func testRecipeProportionScenario() {
        // Simulate a recipe scaling scenario
        tokenContext.setValue(2.0, forKey: "proportion.ratio")
        tokenContext.setValue(24, forKey: "proportion.itemCount")
        tokenContext.setValue("Chocolate Chip Cookies", forKey: "recipe.name")
        tokenContext.setValue(4.0, forKey: "ingredients.flour.cups")
        tokenContext.setValue(2.0, forKey: "ingredients.sugar.cups")
        
        let instructionTemplate = """
        {{recipe.name}}
        Makes {{proportion.itemCount}} cookies at {{proportion.ratio}}x the original recipe.
        You'll need {{ingredients.flour.cups}} cups of flour and {{ingredients.sugar.cups}} cups of sugar.
        """
        
        let result = instructionTemplate.replacingTokens(dict: tokenContext.tokenDictionary())
        
        XCTAssertTrue(result.contains("Chocolate Chip Cookies"))
        XCTAssertTrue(result.contains("Makes 24 cookies at 2.0x"))
        XCTAssertTrue(result.contains("4.0 cups of flour"))
        XCTAssertTrue(result.contains("2.0 cups of sugar"))
    }
    
    func testUserProfileScenario() {
        tokenContext.setValue("Alice Johnson", forKey: "user.name")
        tokenContext.setValue("alice@example.com", forKey: "user.email")
        tokenContext.setValue("Premium", forKey: "subscription.tier")
        tokenContext.setValue(Date(timeIntervalSince1970: 1620000000), forKey: "subscription.renewalDate")
        
        let template = """
        User: {{user.name}} ({{user.email}})
        Subscription: {{subscription.tier}}
        Renews: {{subscription.renewalDate|formattedDateShort}}
        """
        
        let result = template.replacingTokens(dict: tokenContext.tokenDictionary())
        
        XCTAssertTrue(result.contains("User: Alice Johnson"))
        XCTAssertTrue(result.contains("alice@example.com"))
        XCTAssertTrue(result.contains("Subscription: Premium"))
        XCTAssertTrue(result.contains("Renews:"))
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceSetManyValues() {
        measure {
            let context = TokenContext()
            for i in 0..<1000 {
                context.setValue("value\(i)", forKey: "key\(i)")
            }
        }
    }
    
    func testPerformanceTokenDictionaryConversion() {
        for i in 0..<100 {
            tokenContext.setValue("value\(i)", forKey: "level1.level2.key\(i)")
        }
        
        measure {
            _ = tokenContext.tokenDictionary()
        }
    }
    
    func testPerformanceIntegrationWithReplacement() {
        tokenContext.setValue("Alice", forKey: "user.name")
        tokenContext.setValue(25, forKey: "user.age")
        tokenContext.setValue("San Francisco", forKey: "user.address.city")
        
        let template = "{{user.name}} ({{user.age}}) lives in {{user.address.city}}"
        
        measure {
            _ = template.replacingTokens(dict: tokenContext.tokenDictionary())
        }
    }
}

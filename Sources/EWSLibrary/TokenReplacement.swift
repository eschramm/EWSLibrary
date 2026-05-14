//
//  TokenReplacement.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 5/14/26.
//

import Foundation

public extension String {
    /// Replaces tokens in a string with values from a dictionary.
    ///
    /// This method scans the string for tokens enclosed in double curly braces `{{token}}`
    /// and replaces them with corresponding values from the provided dictionary.
    ///
    /// ## Token Formats
    ///
    /// ### Simple Tokens
    /// ```
    /// "Hello {{name}}!"
    /// ```
    /// Replaces `{{name}}` with the value of `dict["name"]`.
    ///
    /// ### Nested Dictionary Access
    /// ```
    /// "City: {{address.city}}"
    /// ```
    /// Supports dot notation to drill down into nested dictionaries.
    ///
    /// ### Formatted Values
    /// ```
    /// "Date: {{eventDate|formatted}}"
    /// "Price: {{amount|formattedCurrency}}"
    /// ```
    /// Applies formatting to values:
    /// - `|formatted` - Default date/time format for `Date` values
    /// - `|formattedDateShort` - Short date format (numeric, no time)
    /// - `|formattedTimeShort` - Short time format (no date)
    /// - `|formattedCurrency` - Currency format for `Double` or `Decimal` values
    /// - `|formattedInt` - Truncated int value
    ///
    /// ## Example Usage
    /// ```swift
    /// let template = "Hello {{user.name}}, your balance is {{balance|formattedCurrency}}."
    /// let data: [String: Any] = [
    ///     "user": ["name": "Alice"],
    ///     "balance": 1234.56
    /// ]
    /// let result = template.replacingTokens(dict: data)
    /// // "Hello Alice, your balance is $1,234.56."
    /// ```
    ///
    /// - Parameter dict: A dictionary containing the replacement values. Keys should match
    ///   the token names in the string. Values can be any type and will be converted to strings.
    /// - Returns: A new string with all tokens replaced by their corresponding values. Unmatched
    ///   tokens are replaced with empty strings.
    func replacingTokens(dict: [String : Any]) -> String {
        var output = ""

        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = []

        while !scanner.isAtEnd {
            let text = scanner.scanUpToString("{{")
            output += text ?? ""
            _ = scanner.scanCharacter()
            _ = scanner.scanCharacter()
            let token = scanner.scanUpToString("}}") ?? ""
            output += String.tokenFromDict(token: token, dict: dict) ?? ""
            _ = scanner.scanCharacter()
            _ = scanner.scanCharacter()
        }

        return output
    }
    
    static func tokenFromDict(token: String, dict: [String : Any]) -> String? {
        // Check for formatting first (handles both simple and nested paths)
        if token.contains("|formatted") {
            let pathComponents = token.components(separatedBy: "|formatted")
            let keyPath = pathComponents[0]
            let formatType = pathComponents[1]
            
            // Resolve the value (could be simple or nested)
            let unformattedValue = resolveValue(forKeyPath: keyPath, in: dict)
            
            guard let value = unformattedValue else {
                return ""
            }
            
            switch (formatType, value) {
            case ("", is Date):  // Date Time - M/d/yyyy, hh:mm PM
                return (value as! Date).formatted()
            case ("DateShort", is Date):
                return (value as! Date).formatted(date: .numeric, time: .omitted)
            case ("TimeShort", is Date):
                return (value as! Date).formatted(date: .omitted, time: .shortened)
            case ("", is Double):
                return (value as! Double).formatted()
            case ("Currency", is Double):
                return (value as! Double).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
            case ("Currency", is Decimal):
                return (value as! Decimal).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
            case ("Int", is Int):
                return (value as! Int).formatted(.number)
            case ("Int", is Int64):
                return (value as! Int64).formatted(.number)
            case ("Int", is Double):
                return Int(value as! Double).formatted(.number)
            default:
                return ""
            }
        }
        
        // Direct token match
        if let replacementValue = dict[token] {
            return "\(replacementValue)"
        }
        
        // Check for nested path (drill down)
        if token.contains(".") {
            if let value = resolveValue(forKeyPath: token, in: dict) {
                return "\(value)"
            }
            return ""
        }
        
        return ""
    }
    
    /// Helper method to resolve a value from a key path (supports nested dictionaries)
    private static func resolveValue(forKeyPath keyPath: String, in dict: [String: Any]) -> Any? {
        let pathComponents = keyPath.components(separatedBy: ".")
        
        // Simple key
        if pathComponents.count == 1 {
            return dict[keyPath]
        }
        
        // Nested path - drill down
        var current: Any? = dict
        for component in pathComponents {
            guard let currentDict = current as? [String: Any] else {
                return nil
            }
            current = currentDict[component]
        }
        
        return current
    }
}

//
//  TokenContext.swift
//  The Weigh 2
//
//  Created by Eric Schramm on 5/14/26.
//

import Foundation
import SwiftUI

/// A container for global token replacement values that can be used throughout the SwiftUI flow.
///
/// TokenContext stores key-value pairs that can be referenced in instruction markdown using
/// the token replacement syntax `{{key}}`. Values are automatically updated as the recipe
/// progresses and can include calculated values like proportions, counts, and formatted quantities.
///
/// ## Usage
/// ```swift
/// // In RouteStore or other coordinator:
/// tokenContext.setValue(1.5, forKey: "proportion.ratio")
/// tokenContext.setValue(12, forKey: "proportion.itemCount")
///
/// // In InstructionStep markdown:
/// "You made {{proportion.itemCount}} items at {{proportion.ratio}}x proportion!"
/// ```
@MainActor
public final class TokenContext: ObservableObject {
    @Published private(set) var values: [String: Any] = [:]
    
    public init() { }
    
    /// Sets a value for a given key in the token context
    /// - Parameters:
    ///   - value: The value to store (can be String, Double, Int, Date, or any type)
    ///   - key: The key to use for token replacement (supports dot notation for organization)
    public func setValue(_ value: Any, forKey key: String) {
        values[key] = value
    }
    
    /// Removes a value for a given key
    /// - Parameter key: The key to remove
    public func removeValue(forKey key: String) {
        values.removeValue(forKey: key)
    }
    
    /// Clears all values from the context
    public func clear() {
        values.removeAll()
    }
    
    /// Returns the token dictionary for use with String.replacingTokens(dict:)
    /// This converts the flat key structure into a nested dictionary structure
    /// for proper dot-notation support.
    public func tokenDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in values {
            // Filter out empty components from leading/trailing dots
            let components = key.components(separatedBy: ".").filter { !$0.isEmpty }
            
            if components.isEmpty {
                // Skip empty keys
                continue
            } else if components.count == 1 {
                // Simple key
                result[components[0]] = value
            } else {
                // Nested key - build nested dictionary
                setNestedValue(in: &result, components: components, value: value)
            }
        }
        
        return result
    }
    
    /// Helper method to set a value in a nested dictionary structure
    private func setNestedValue(in dict: inout [String: Any], components: [String], value: Any) {
        guard !components.isEmpty else { return }
        
        if components.count == 1 {
            // Base case: set the value
            dict[components[0]] = value
        } else {
            // Recursive case: ensure nested dictionary exists and recurse
            let key = components[0]
            var nestedDict = dict[key] as? [String: Any] ?? [String: Any]()
            setNestedValue(in: &nestedDict, components: Array(components.dropFirst()), value: value)
            dict[key] = nestedDict
        }
    }
    
    /// Convenience method to get the flattened dictionary (without nesting)
    /// Use this if you prefer simple token names without dot notation
    public var flatDictionary: [String: Any] {
        return values
    }
}

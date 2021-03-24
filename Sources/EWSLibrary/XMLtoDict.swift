//
//  File.swift
//  
//
//  Created by Eric Schramm on 3/24/21.
//

import Foundation


class XMLtoDictionary: NSObject {
    
    let xmlData: Data
    
    // parser state
    var elementStack = [String]()
    var currentValue = ""
    var leaves = [String : Any]()
    var attributes = [String : [String : String]]()
    
    var dictStack = [NSMutableDictionary]()
    var rootDict = NSMutableDictionary()
    
    var output = [[String : Any]]()
    
    init(xmlData: Data) {
        self.xmlData = xmlData
        rootDict["elements"] = [NSMutableDictionary]()
        super.init()
    }
    
    func dictionary() -> NSDictionary {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.parse()
        return rootDict
    }
    
    func buildOutput() -> [[String : Any]] {
        var output = [[String : Any]]()
        let keys = leaves.keys.sorted()
        print(keys)
        return output
    }
}

extension XMLtoDictionary: XMLParserDelegate {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let prefix = elementStack.joined(separator: ">") + ((!elementStack.isEmpty) ? ">" : "")
        var index = 0
        while let _ = leaves["\(prefix)\(elementName)|\(index)"] {
            index += 1
        }
        elementStack.append("\(elementName)|\(index)")
        if !attributeDict.isEmpty {
            attributes["\(prefix)\(elementName)|\(index)"] = attributeDict
        }
        
        let dict = NSMutableDictionary()
        dict["elements"] = [NSMutableDictionary]()
        dict["name"] = elementName
        if !attributeDict.isEmpty {
            dict["attributes"] = attributeDict
        }
        dictStack.append(dict)
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        leaves[elementStack.joined(separator: ">")] = currentValue
        elementStack.removeLast()
        
        let currentDict = dictStack.last!
        currentDict["value"] = currentValue
        dictStack.removeLast()
        let superDict = dictStack.last ?? rootDict
        var superElements = superDict["elements"] as! [NSMutableDictionary]
        superElements.append(currentDict)
        superDict["elements"] = superElements
        currentValue = ""
    }
    /*
    func leafKey() -> String {
        let prefix = elementStack.joined(separator: ">")
        var index = 0
        while let _ = leaves["\(prefix)|\(index)"] {
            index += 1
        }
        return "\(prefix)|\(index)"
    }*/
    
    func parserDidEndDocument(_ parser: XMLParser) {
        print("HERE")
    }
}

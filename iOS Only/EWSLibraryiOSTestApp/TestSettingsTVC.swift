//
//  File.swift
//  EWSLibraryiOSTestApp
//
//  Created by Eric Schramm on 4/13/20.
//  Copyright © 2020 eware. All rights reserved.
//

import UIKit
import EWSLibrary


class TestSettingsTVC: SettingsTVC {
    
    var stateDict: NSMutableDictionary  // reference semantics
    
    let iapCoordinator = IAPCoordinator(productIdentifiers: ["IAPsnapGPSfix"],
    productPackage: IAPProductPackage(identifier: "IAPsnapGPSfix",
                                      title: "Save GPS Fix at Stroke",
                                      description: "By saving a GPS fix for a stroke, you are able to calculate distance for strokes and add another attribute to your statistics",
                                      pngTitle: "IAPGPSLock"))
    let numberFormatter = NumberFormatter()
    let tagCloudDelegate = TagCloudExampleDelegate()
    
    init() {
        let stateDict = NSMutableDictionary()
        let sections = [
            SettingsSection(title: "Bool Switch", type: .standard([
                Self.switchTVC(stateDict: stateDict),
                Self.switchWrapTVC(stateDict: stateDict)
            ])),
            SettingsSection(title: "Right Selection", type: .standard([
                Self.rightSelection(),
                Self.rightSelectionWrap()
            ])),
            SettingsSection(title: "Button", type: .standard([
                Self.buttonCenteredCell(),
                Self.buttonLeftDisplayViewControllerCell()
            ])),
            SettingsSection(title: "Ratings Cell", type: .standard([
                Self.ratingsCell()
            ])),
            SettingsSection(title: "In App Purchase Cell", type: .standard([
                Self.iapGPSSnapFixCell(iapCoordinator: iapCoordinator)
            ])),
            SettingsSection(title: "Text Field", type: .standard([
                Self.textFieldCell(numberFormatter: numberFormatter, stateDict: stateDict),
                Self.textFieldWrapCell(stateDict: stateDict)
            ])),
            SettingsSection(title: "Date Cell", type: .standard([
                Self.dateCell()
            ])),
            SettingsSection(title: "Tag Cell", type: .standard([
                Self.tagCell(tagCloudDelegate: tagCloudDelegate)
            ])),
            SettingsSection(title: "Photo Cell", type: .standard([
                Self.photoCell()
            ])),
            SettingsSection(title: "Text View", type: .standard([
                Self.textViewCell(stateDict: stateDict),
                Self.textViewCellNoTitle(stateDict: stateDict)
            ]))
        ]
        self.stateDict = stateDict
        super.init(sections: sections)
        tagCloudDelegate.trampoline = trampoline
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func switchTVC(stateDict: NSMutableDictionary) -> SettingsCellModel {
        
        let getBoolHander: () -> (Bool) = {
            if let boolValue = stateDict["switch"] as? Bool {
                return boolValue
            } else {
                return false
            }
        }
        
        let setBoolHander: (Bool) -> () = { boolValue in
            stateDict["switch"] = boolValue
        }
        
        return SettingsCellModel(cellType: .boolSwitch(title: "Short Switch", getBoolHandler: getBoolHander, setBoolHandler: setBoolHander), selectionType: .handledByCell)
    }
    
    static func switchWrapTVC(stateDict: NSMutableDictionary) -> SettingsCellModel {
        
        let getBoolHander: () -> (Bool) = {
            if let boolValue = stateDict["longSwitch"] as? Bool {
                return boolValue
            } else {
                return false
            }
        }
        
        let setBoolHander: (Bool) -> () = { boolValue in
            stateDict["longSwitch"] = boolValue
        }
        
        return SettingsCellModel(cellType: .boolSwitch(title: "Long Switch with long text to ensure word wrapping occurs, check the layout on this one", getBoolHandler: getBoolHander, setBoolHandler: setBoolHander), selectionType: .handledByCell)
    }
    
    static func rightSelection() -> SettingsCellModel {
        let getStringHandler: CellDetailGetStringHandler = {
            return ("Detail in blue", .systemBlue)
        }
        return SettingsCellModel(cellType: .rightSelection(title: "Simple Right Selection", getStringHandler: getStringHandler), selectionType: .cellButtonAction(action: { (_) in
            print("Would present something")
        }))
    }
    
    static func rightSelectionWrap() -> SettingsCellModel {
        let getStringHandler: CellDetailGetStringHandler = {
            return ("Detail in blue with a lotta length to see what happens", .systemBlue)
        }
        return SettingsCellModel(cellType: .rightSelection(title: "Simple Right Selection with a lot of text to create pression and cause wrapping", getStringHandler: getStringHandler), selectionType: .cellButtonAction(action: { (_) in
            print("Would present something")
        }))
    }
    
    static func buttonCenteredCell() -> SettingsCellModel {
        if #available(iOS 13.0, *) {
            return SettingsCellModel(cellType: .buttonCell(type: .centered(titleColor: .systemBackground, backgroundColor: .label), title: "Button Centered With a whole ton of text to see what happens with wrapping"), selectionType: .handledByCell)
        } else {
            return SettingsCellModel(cellType: .buttonCell(type: .centered(titleColor: .white, backgroundColor: .black), title: "Button Centered"), selectionType: .handledByCell)
        }
    }
    
    static func buttonLeftDisplayViewControllerCell() -> SettingsCellModel {
        if #available(iOS 13.0, *) {
            return SettingsCellModel(cellType: .buttonCell(type: .leftDisplayViewController(backgroundColor: .systemOrange, accessory: .checkmark), title: "Button LeftDisplayViewController Style with a lot of text to see how it responds"), selectionType: .handledByCell)
        } else {
            return SettingsCellModel(cellType: .buttonCell(type: .leftDisplayViewController(backgroundColor: .orange, accessory: .checkmark), title: "Button LeftDisplayViewController Style with a lot of text to see how it responds"), selectionType: .handledByCell)
        }
    }
    
    static func ratingsCell() -> SettingsCellModel {
        let initialTitle = "Many users have reviewed iQIF so far with only a few reviewing the current version. We'd love to hear from you! Tap to rate."
        let updateTitleHandler: (_ appInfoDict: [AnyHashable : Any]) -> (String) = { appInfoDict in
            if let dict = appInfoDict["results"] as? [[AnyHashable : Any]],
                let result = dict.first, let totalReviewsCount = result["userRatingCount"] as? NSNumber,
                let versionReviewsCount = result["userRatingCountForCurrentVersion"] as? NSNumber {
                var currentUsers = "only a few users"
                if versionReviewsCount.intValue == 0 {
                    currentUsers = "no one"
                } else if versionReviewsCount == 1 {
                    currentUsers = "only 1 user"
                } else {
                    currentUsers = "only \(totalReviewsCount) users"
                }
                let updatedRatings = "\(currentUsers) have reviewed iQIF so far with \(versionReviewsCount) reviewing the current version. We'd love to hear from you! Tap to rate. Adding more text to make sure it wraps a lot."
                
                return updatedRatings
            }
            return initialTitle
        }
        
        return SettingsCellModel(cellType: .ratingsCell(initialTitle: initialTitle, titleColor: .systemGray, appStoreID: "386493543", updateTitleHandler: updateTitleHandler), selectionType: SettingsRatingCell.defaultSelectAction())
    }
    
    static func iapGPSSnapFixCell(iapCoordinator: IAPCoordinator) -> SettingsCellModel {
        let initialTitle = "Add option to save GPS fix on a stroke - but making this very long to watch wrapping"
        let purchasedTitle = "GPS fix on a stroke enabled - Thank You"
        
        let selectionType = SettingsIAPCell.defaultSelectAction(iapCoordinator: iapCoordinator, productIdentifier: "IAPsnapGPSfix")
        
        return SettingsCellModel(cellType: .iapCell(initialTitle: initialTitle, purchasedTitle: purchasedTitle, iapKey: "Constants.IAPsnapGPSfix"), selectionType: selectionType)
    }
    
    static func textFieldCell(numberFormatter: NumberFormatter, stateDict: NSMutableDictionary) -> SettingsCellModel {
        let selectionType = SettingsCellSelectionType.helpText(title: "Honing Delay",
                                                               message: "How long StattyCaddy should wait until a GPS fix is attempted with the GPS button is hit.  This is to combat GPS lag which can occur if the device was moving just prior to getting a fix.")
        let getStringHandler: () -> (String, UIColor?) = {
            let number = stateDict["honingDelay"] as? NSNumber ?? NSNumber(value: 2)
            return (numberFormatter.string(from: number) ?? "2", nil)
        }
        let setStringHandler: (String) -> () = { updatedString in
            if let number = numberFormatter.number(from: updatedString) {
                stateDict["honingDelay"] = number.doubleValue
            }
        }
        let isValidHandler: (String) -> (Bool) = { string in
            let nf = NumberFormatter()
            if let number = nf.number(from: string), number.floatValue > 0 {
                return true
            } else {
                return false
            }
        }
        let attributes = TextFieldAttributes(title: "Honing delay (sec)", fieldPlaceHolder: "2", fieldMaximumWidthPercent: nil, fieldKeyboard: nil, getStringHandler: getStringHandler, setStringHandler: setStringHandler, isValidHandler: isValidHandler)
        return SettingsCellModel(cellType: .textFieldCell(attributes: attributes), selectionType: selectionType)
    }
    
    static func textFieldWrapCell(stateDict: NSMutableDictionary) -> SettingsCellModel {
        let selectionType = SettingsCellSelectionType.helpText(title: "Honing Delay",
                                                               message: "How long StattyCaddy should wait until a GPS fix is attempted with the GPS button is hit.  This is to combat GPS lag which can occur if the device was moving just prior to getting a fix.")
        let getStringHandler: () -> (String, UIColor?) = {
            return (stateDict["honingDelayWrap"] as? String ?? "", nil)
        }
        let setStringHandler: (String) -> () = { updatedString in
            stateDict["honingDelayWrap"] = updatedString
        }
        let isValidHandler: (String) -> (Bool) = { string in
            let nf = NumberFormatter()
            if let number = nf.number(from: string), number.floatValue > 0 {
                return true
            } else {
                return false
            }
        }
        let attributes = TextFieldAttributes(title: "Honing delay (sec) but let's make some pressure for wrapping text here", fieldPlaceHolder: "long text to start out with", fieldMaximumWidthPercent: nil, fieldKeyboard: nil, getStringHandler: getStringHandler, setStringHandler: setStringHandler, isValidHandler: isValidHandler)
        return SettingsCellModel(cellType: .textFieldCell(attributes: attributes), selectionType: selectionType)
    }
    
    static func dateCell() -> SettingsCellModel {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let getDateHandler: () -> (Date?, UIColor?) = {
            return (Date(), nil)
        }
        let setDateHandler: (Date?) -> () = { _ in
            
        }
        
        let attributes = DateCellAttributes(title: "Date but I want to make it really long in the title, maybe even 3 lines worth", fieldPlaceholder: nil, datePickerMode: .date, dateFormatter: dateFormatter, dismissalSetsDateToPickerDate: true, getDateHandler: getDateHandler, setDateHandler: setDateHandler)
        
        return SettingsCellModel(cellType: .dateCell(attributes: attributes), selectionType: .handledByCell)
    }
    
    static func tagCell(tagCloudDelegate: TagCloudDelegate) -> SettingsCellModel {
        let tagCloudParameters = TagCloudParameters(tagTitleColor: UIColor.dynamicBackground(), tagTitleFont: UIFont.boldSystemFont(ofSize: 14), verticalPadding: 15, horizontalPadding: 15)
        return SettingsCellModel(cellType: .tagCloudCell(cloudID: "TagCloudExample", tagCloudDelegate: tagCloudDelegate, parameters: tagCloudParameters), selectionType: .handledByCell)
    }
    
    static func photoCell() -> SettingsCellModel {
        let image = UIImage(named: "sample.jpg")
        let imageUpdateTitleHandler: (UIImage?) -> (String?) = { image in
            if let image = image {
                print("Updated image: \(image)")
            }
            return "Image Updated"
        }
        return SettingsCellModel(cellType: .photoCell(maxCellHeight: 150, getImageTitleHandler: { (image, "Set Image") }, setImageUpdateTitleHandler: imageUpdateTitleHandler), selectionType: .handledByCell)
    }
    
    static func textViewCell(stateDict: NSMutableDictionary) -> SettingsCellModel {
        let selectionType = SettingsCellSelectionType.helpText(title: "Testing Help",
                                                               message: "This is where you can put notes about this item.")
        let getStringHandler: () -> (String, UIColor?) = {
            return (stateDict["textView"] as? String ?? "This is a longer piece of text. Long so it can force some word wrapping. But this cell is intended for a notes section where a larger chunk of user-editable text can be stored", nil)
        }
        let setStringHandler: (String) -> () = { updatedString in
            stateDict["textView"] = updatedString
        }
        let attributes = TextViewAttributes(title: "Notes about this item:", fieldKeyboard: nil, getStringHandler: getStringHandler, setStringHandler: setStringHandler)
        return SettingsCellModel(cellType: .textViewCell(attributes: attributes), selectionType: selectionType)
    }
    
    static func textViewCellNoTitle(stateDict: NSMutableDictionary) -> SettingsCellModel {
        let selectionType = SettingsCellSelectionType.helpText(title: "Testing Help",
                                                               message: "This is where you can put notes about this item.")
        let getStringHandler: () -> (String, UIColor?) = {
            return (stateDict["textView"] as? String ?? "This is a longer piece of text. Long so it can force some word wrapping. But this cell is intended for a notes section where a larger chunk of user-editable text can be stored", .lightGray)
        }
        let setStringHandler: (String) -> () = { updatedString in
            stateDict["textView"] = updatedString
        }
        let attributes = TextViewAttributes(title: "", fieldKeyboard: nil, getStringHandler: getStringHandler, setStringHandler: setStringHandler)
        return SettingsCellModel(cellType: .textViewCell(attributes: attributes), selectionType: selectionType)
    }
}

class TagCloudExampleDelegate : TagCloudDelegate {
    
    var allTags = ["One", "Twenty", "Three Hundred", "Four Thousand", "Fifty Thousand", "Six Hundred Thousand", "Seven Million", "Eighty Million"]
    var filteredAllTags = [String]()
    var addedTags = ["One"]
    
    var trampoline: Trampoline!
    
    func updatedFilteredAllTags() {
        filteredAllTags = allTags.filter({ (tag) -> Bool in
            !addedTags.contains(tag)
        })
    }
    
    func tagCount(cloudID: String, context: TagContext) -> Int {
        switch context {
        case .item:
            return addedTags.count
        case .all:
            updatedFilteredAllTags()
            return filteredAllTags.count
        }
    }
    
    func tag(cloudID: String, context: TagContext, for index: Int) -> Tag {
        switch context {
        case .item:
            return addedTags[index]
        case .all:
            return filteredAllTags[index]
        }
    }
    
    func removeTag(at index: Int) {
        self.addedTags.remove(at: index)
        updatedFilteredAllTags()
    }
    
    func didAddTag(from index: Int) -> Bool {
        let tagToAdd = self.filteredAllTags[index]
        if !self.addedTags.contains(tagToAdd) {
            self.addedTags.append(self.filteredAllTags[index])
            updatedFilteredAllTags()
            return true
        } else {
            return false
        }
    }
    
    func presentTagAddingViewController(tagAddingViewController: UIViewController) {
        trampoline.settingsTVC?.present(tagAddingViewController, animated: true, completion: nil)
    }
    
    func dismissTagAddingViewController() {
        trampoline.settingsTVC?.dismiss(animated: true, completion: nil)
    }
    
    func shouldCreateTag(with title: String) -> Bool {
        return !(allTags.contains(title))
    }
    
    func indexForCreatedTag(with title: String) -> Int {
        allTags.append(title)
        updatedFilteredAllTags()
        return filteredAllTags.count - 1
    }
}

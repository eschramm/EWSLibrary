//
//  SettingsPickerCell.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/5/20.
//  Copyright © 2020 eware. All rights reserved.
//

#if os(iOS)
import UIKit


public protocol PickerDelegate: AnyObject {
    func pickerDidSelect(picker: PickerDelegate, selectedTitle: String)
}

public protocol PickerPresenterItem {
    func displayTitle() -> String
}

public struct PickerPresenterSelectionHandler {
    let sortPriority: Int
    let itemSelectedHandler: (PickerPresenterItem?) -> ()
    public init(sortPriority: Int, itemSelectedHandler: @escaping (PickerPresenterItem?) -> ()) {
        self.sortPriority = sortPriority
        self.itemSelectedHandler = itemSelectedHandler
    }
}

public protocol PickerPresenter {
    var handlers: [PickerPresenterSelectionHandler] { get set }
    func summonPicker(presentingViewController: UIViewController)
    func removeDefault()
}

public extension PickerPresenter {
    mutating func add(pickerPresenterSelectionHandler: PickerPresenterSelectionHandler) {
        handlers.append(pickerPresenterSelectionHandler)
    }
    
    func processHandlers(updatedItem: PickerPresenterItem?) {
        for handler in handlers.sorted(by: { (handler1, handler2) -> Bool in
            handler1.sortPriority < handler2.sortPriority
        }) {
            handler.itemSelectedHandler(updatedItem)
        }
    }
}
#endif

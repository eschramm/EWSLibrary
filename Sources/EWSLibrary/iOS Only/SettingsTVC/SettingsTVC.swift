//
//  SettingsCells.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/1/19.
//  Copyright © 2019 eware. All rights reserved.
//

#if os(iOS)
import UIKit


public struct SettingsSection {
    public enum SectionType {
        case standard([SettingsCellModel])
        case dynamic(dataSource: UITableViewDataSource, tableViewDelegate: UITableViewDelegate)
    }
    let title: String?
    let type: SectionType
    public init(title: String?, type: SectionType) {
        self.title = title
        self.type = type
    }
}

public extension Notification.Name {
    static let SettingsTVCCheckForVisibilityChanges = Notification.Name(rawValue: "SettingsTVCCheckForVisibilityChanges")
    static let SettingsTVCTableviewBeginUpdates = Notification.Name(rawValue: "SettingsTVCTableviewBeginUpdates")
    static let SettingsTVCTableviewEndUpdates = Notification.Name(rawValue: "SettingsTVCTableviewEndUpdates")
}

// Trampoline is a way to inject a weak reference to the SettingsTVC for situations where the cell needs to communicate back to the SettingsTVC
// If needed for static cell creation, create the Trampoline in the init and pass thru.

public class Trampoline {
    public weak var settingsTVC: SettingsTVC?
    public init() { }
}

open class SettingsTVC: UITableViewController {
    
    var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer!
    var sections = [SettingsSection]()
    var textFields = [UIResponder]()
    var indexPathsForHidableCells = [IndexPath]()
    var indexPathsForRefreshOnViewWillAppear = [IndexPath]()
    public let trampoline: Trampoline
    
    public init(sections: [SettingsSection], trampoline: Trampoline? = nil) {  // or ensure sections are populated before tableView attempts to load
        self.sections = sections
        self.trampoline = trampoline ?? Trampoline()
        super.init(style: .grouped)
        self.gestureRecognizerToDismissFirstResponder = UITapGestureRecognizer(target: self, action: #selector(handleGesture(gestureRecognizer:)))
        self.trampoline.settingsTVC = self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        tableView.estimatedRowHeight = 44
        gestureRecognizerToDismissFirstResponder.numberOfTapsRequired = 1
        gestureRecognizerToDismissFirstResponder.numberOfTouchesRequired = 1
        gestureRecognizerToDismissFirstResponder.isEnabled = false
        tableView.addGestureRecognizer(gestureRecognizerToDismissFirstResponder)
        super.viewDidLoad()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(checkVisibilityChanges), name: .SettingsTVCCheckForVisibilityChanges, object: nil)
        if let tableView = tableView {
            NotificationCenter.default.addObserver(tableView, selector: #selector(UITableView.beginUpdates), name: .SettingsTVCTableviewBeginUpdates, object: nil)
            NotificationCenter.default.addObserver(tableView, selector: #selector(UITableView.endUpdates), name: .SettingsTVCTableviewEndUpdates, object: nil)
            tableView.reloadRows(at: indexPathsForRefreshOnViewWillAppear, with: .none)
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: .SettingsTVCCheckForVisibilityChanges, object: nil)
        if let tableView = tableView {
            NotificationCenter.default.removeObserver(tableView, name: .SettingsTVCTableviewBeginUpdates, object: nil)
            NotificationCenter.default.removeObserver(tableView, name: .SettingsTVCTableviewEndUpdates, object: nil)
        }
        super.viewWillDisappear(animated)
    }
    
    open override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let settingsSection = sections[section]
        switch settingsSection.type {
        case .standard(let cellModels):
            return cellModels.count
        case .dynamic(dataSource: let dataSource, _):
            return dataSource.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        guard case .standard(let cellModels) = section.type else {
            if case .dynamic(dataSource: let dataSource, _) = section.type {
                return dataSource.tableView(tableView, cellForRowAt: indexPath)
            } else {
                fatalError("Unhandled case")
            }
        }
        let model = cellModels[indexPath.row]
        let cellIdentifier = "\(indexPath.section)-\(indexPath.row)"
        if let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) {
            configure(cell: cell, model: model)
            return cell
        }
        switch model.cellType {
        case .boolSwitch(_,_,_):
            if let cell = SettingsSwitchCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .rightSelection(_,_, let refreshOnViewWillAppear):
            if let cell = SettingsRightSelectionCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                if refreshOnViewWillAppear {
                    indexPathsForRefreshOnViewWillAppear.append(indexPath)
                }
                return cell
            }
        case .buttonCell(_,_):
            if let cell = SettingsButtonCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .ratingsCell(_,_,_,_):
            if let cell = SettingsRatingCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .iapCell(_,_,_):
            if let cell = SettingsIAPCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .textFieldCell(_):
            if let cell = SettingsTextFieldCell(model: model, identifier: cellIdentifier) {
                textFields.append(cell.textField)
                cell.gestureRecognizerToDismissFirstResponder = gestureRecognizerToDismissFirstResponder
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .dateCell(_):
            if let cell = SettingsDateCell(model: model, identifier: cellIdentifier) {
                textFields.append(cell.textField)
                cell.gestureRecognizerToDismissFirstResponder = gestureRecognizerToDismissFirstResponder
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .tagCloudCell(let cloudID, let tagCloudDelegate, let parameters):
            let cell = SettingsTagCloudCell(cloudID: cloudID, tagCloudDelegate: tagCloudDelegate, reuseIdentifier: cellIdentifier, parameters: parameters)
            configure(cell: cell, model: model)
            if let _ = model.visibilityHandler {
                indexPathsForHidableCells.append(indexPath)
            }
            return cell
        case .photoCell:
            let cell = SettingsPhotoCell(model: model, identifier: cellIdentifier)!
            return cell
        case .textViewCell(_):
            if let cell = SettingsTextViewCell(model: model, identifier: cellIdentifier) {
                textFields.append(cell.textView)
                cell.gestureRecognizerToDismissFirstResponder = gestureRecognizerToDismissFirstResponder
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        }
        // failed
        print("Failed to create a cell for \(model) at \(indexPath)")
        return UITableViewCell(style: .default, reuseIdentifier: "errorCase")
    }
    
    func configure(cell: UITableViewCell, model: SettingsCellModel) {
        var showCell = true
        if let visibilityHandler = model.visibilityHandler {
            showCell = visibilityHandler()
        }
        cell.isHidden = !showCell
        for additionalProperty in model.additionalProperties {
            additionalProperty.addProperties(cell: cell)
        }
    }
    
    open override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = sections[indexPath.section]
        switch section.type {
        case .standard(let cellModels):
            let model = cellModels[indexPath.row]
            var showCell = true
            if let visibilityHandler = model.visibilityHandler {
                showCell = visibilityHandler()
            }
            return showCell ? UITableView.automaticDimension : 0
        case .dynamic(_, tableViewDelegate: let tableViewDelegate):
            return tableViewDelegate.tableView?(tableView, heightForRowAt: indexPath) ?? UITableView.automaticDimension
        }
    }
    
    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[indexPath.section]
        switch section.type {
        case .standard(_):
            if let cell = tableView.cellForRow(at: indexPath) as? SettingsCell {
                if let cell = cell as? SettingsDateCell {
                    tableView.beginUpdates()
                    cell.selectAction(presentingViewController: self)
                    tableView.endUpdates()
                } else {
                    cell.selectAction(presentingViewController: self)
                }
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .dynamic(_, tableViewDelegate: let tableViewDelegate):
            tableViewDelegate.tableView?(tableView, didSelectRowAt: indexPath)
        }
    }
    
    open override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section = sections[indexPath.section]
        guard case .dynamic(dataSource: _, tableViewDelegate: let tableViewDelegate) = section.type else { return nil }
        return tableViewDelegate.tableView?(tableView, leadingSwipeActionsConfigurationForRowAt: indexPath)
    }
    
    open override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section = sections[indexPath.section]
        guard case .dynamic(dataSource: _, tableViewDelegate: let tableViewDelegate) = section.type else { return nil }
        return tableViewDelegate.tableView?(tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
    }
    
    open override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let section = sections[indexPath.section]
        guard case .dynamic(dataSource: let tableViewDataSource, tableViewDelegate: _) = section.type else { return false }
        return tableViewDataSource.tableView?(tableView, canEditRowAt: indexPath) ?? false
    }
    
    open override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let section = sections[indexPath.section]
        guard case .dynamic(dataSource: let tableViewDataSource, tableViewDelegate: _) = section.type else { return false }
        return tableViewDataSource.tableView?(tableView, canMoveRowAt: indexPath) ?? false
    }
    
    open override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let section = sections[sourceIndexPath.section]
        guard case .dynamic(dataSource: let tableViewDataSource, tableViewDelegate: _) = section.type else { return }
        tableViewDataSource.tableView?(tableView, moveRowAt: sourceIndexPath, to: destinationIndexPath)
    }

    
    @objc func handleGesture(gestureRecognizer: UIGestureRecognizer) {
        for textField in textFields {
            textField.resignFirstResponder()
        }
        gestureRecognizerToDismissFirstResponder.isEnabled = false
    }
    
    @objc open func checkVisibilityChanges() {
        var indexPathsToReload = [IndexPath]()
        for indexPath in indexPathsForHidableCells {
            let section = sections[indexPath.section]
            guard case .standard(let cellModels) = section.type else { continue }
            let model = cellModels[indexPath.row]
            if let cell = tableView.cellForRow(at: indexPath), let visibilityHandler = model.visibilityHandler {
                if cell.isHidden == visibilityHandler() {
                    indexPathsToReload.append(indexPath)
                }
            }
        }
        if !indexPathsToReload.isEmpty {
            tableView.reloadRows(at: indexPathsToReload, with: .automatic)
        }
    }
}
#endif

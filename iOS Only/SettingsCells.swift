//
//  SettingsCells.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/1/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit
import StoreKit

let kLeadingPaddingToMatchSystemCellLabel: CGFloat = 20.0

enum SettingsCellType {
    
    enum ButtonCellType {
        case centered(titleColor: UIColor, backgroundColor: UIColor)
        case leftDisplayViewController
    }
    
    case boolSwitch(title: String, getBoolHandler: () -> (Bool), setBoolHandler: (Bool) -> ())
    case rightSelection(title: String, getStringHandler: () -> (String, UIColor?))
    case buttonCell(type: ButtonCellType, title: String)
    case ratingsCell(initialTitle: String, titleColor: UIColor, appStoreID: String, updateTitleHandler: (_ appInfoDict: [AnyHashable : Any]) -> (String))
    case textFieldCell(title: String?, fieldPlaceholder: String?, fieldMinimumWidth: CGFloat?, fieldMaximumWidthPercent: CGFloat?, fieldKeyboard: UIKeyboardType, getStringHandler: () -> (String?, UIColor?), setStringHandler: (String) -> ())
}

protocol PickerDelegate: class {
    func pickerDidSelect(picker: PickerDelegate, selectedTitle: String)
}

protocol PickerPresenterItem {
    func displayTitle() -> String
}

struct PickerPresenterSelectionHandler {
    let sortPriority: Int
    let itemSelectedHandler: (PickerPresenterItem?) -> ()
}

protocol PickerPresenter {
    var handlers: [PickerPresenterSelectionHandler] { get set }
    func summonPicker(presentingViewController: UIViewController)
    func removeDefault()
}

extension PickerPresenter {
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

enum SettingsCellSelectionType {
    
    case helpText(title: String, message: String)
    case helpTextPresentPicker(title: String, message: String, actionString: String, pickerPresenter: PickerPresenter, allowRemoveDefaultAction: Bool)
    case cellButtonAction(action: (_ presentingViewController: UIViewController)->())
    
    func action() -> (_ presentingViewController: UIViewController) -> () {
        switch self {
        case .helpText(let title, let message):
            return { (presentingViewController) in
                let helpText = UIAlertController(title: title, message: message, preferredStyle: .alert)
                helpText.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                presentingViewController.present(helpText, animated: true, completion: nil)
            }
        case .helpTextPresentPicker(let title, let message, let actionString, let pickerPresenter, let allowRemoveDefaultAction):
            return { (presentingViewController) in
                let helpText = UIAlertController(title: title, message: message, preferredStyle: .alert)
                helpText.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                helpText.addAction(UIAlertAction(title: actionString, style: .default, handler: { (alertAction) in
                    pickerPresenter.summonPicker(presentingViewController: presentingViewController)
                }))
                if allowRemoveDefaultAction {
                    helpText.addAction(UIAlertAction(title: "Remove Default", style: .destructive, handler: { (alertAction) in
                        pickerPresenter.removeDefault()
                    }))
                }
                presentingViewController.present(helpText, animated: true, completion: nil)
            }
        case .cellButtonAction(let action):
            return { (presentingViewController) in
                action(presentingViewController)
            }
        }
    }
}

struct SettingsCellModel {
    let cellType: SettingsCellType
    let selectionType: SettingsCellSelectionType
}

protocol SettingsCell {
    func selectAction(presentingViewController: UIViewController)
}

class SwitchCell: UITableViewCell, SettingsCell {
    
    let title: String
    let getBoolHandler: () -> (Bool)
    let setBoolHandler: (Bool) -> ()
    let selectAction: (_ presentingViewController: UIViewController) -> ()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .boolSwitch(let title, let getBoolHandler, let setBoolHandler) = model.cellType {
            self.title = title
            self.getBoolHandler = getBoolHandler
            self.setBoolHandler = setBoolHandler
            self.selectAction = model.selectionType.action()
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    func buildCell() {
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.text = title
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(label)
        
        let cellSwitch = UISwitch()
        cellSwitch.translatesAutoresizingMaskIntoConstraints = false
        cellSwitch.isOn = getBoolHandler()
        cellSwitch.addTarget(self, action: #selector(switchToggled(_:)), for: .valueChanged)
        contentView.addSubview(cellSwitch)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: kLeadingPaddingToMatchSystemCellLabel),
            label.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            label.heightAnchor.constraint(lessThanOrEqualToConstant: 44),
            cellSwitch.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -8),
            cellSwitch.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            cellSwitch.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8)
            ])
    }
    
    @objc func switchToggled(_ cellSwitch: UISwitch) {
        setBoolHandler(cellSwitch.isOn)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAction(presentingViewController: UIViewController) {
        selectAction(presentingViewController)
    }
}

class RightSelectionCell: UITableViewCell, SettingsCell {
    
    let title: String
    let getStringHandler: () -> (String, UIColor?)
    var pickerPresenter: PickerPresenter?
    let selectionAction: ((UIViewController) -> ())
    
    let rightSelectionLabel = UILabel()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .rightSelection(let title, let getStringHandler) = model.cellType {
            if case SettingsCellSelectionType.helpTextPresentPicker(_,_,_, let pickerPresenter,_) = model.selectionType {
                self.title = title
                self.getStringHandler = getStringHandler
                self.pickerPresenter = pickerPresenter
                self.selectionAction = model.selectionType.action()
                super.init(style: .default, reuseIdentifier: identifier)
                buildCell()
            } else if case SettingsCellSelectionType.cellButtonAction(action: let selectionAction) = model.selectionType {
                self.title = title
                self.getStringHandler = getStringHandler
                self.pickerPresenter = nil
                self.selectionAction = selectionAction
                super.init(style: .default, reuseIdentifier: identifier)
                buildCell()
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func buildCell() {
        
        accessoryType = .disclosureIndicator
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.text = title
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(label)
        
        rightSelectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rightSelectionLabel)
        
        updateSelection()
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: kLeadingPaddingToMatchSystemCellLabel),
            label.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            label.heightAnchor.constraint(lessThanOrEqualToConstant: 44),
            rightSelectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            rightSelectionLabel.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            rightSelectionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8)
            ])
        
        pickerPresenter?.add(pickerPresenterSelectionHandler: PickerPresenterSelectionHandler(sortPriority: 5, itemSelectedHandler: { [weak self] (updatedItem) in
            self?.rightSelectionLabel.text = updatedItem?.displayTitle()
            self?.updateSelection()
        }))
    }
    
    func updateSelection() {
        let (rightSelectionText, rightSelectionColor) = getStringHandler()
        rightSelectionLabel.text = rightSelectionText
        rightSelectionLabel.textColor = rightSelectionColor ?? .blue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAction(presentingViewController: UIViewController) {
        selectionAction(presentingViewController)
    }
}

class ButtonCell: UITableViewCell, SettingsCell {
    
    let type: SettingsCellType.ButtonCellType
    let title: String
    let selectActionHandler: (_ presentingViewController: UIViewController) -> ()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .buttonCell(let type, let title) = model.cellType {
            self.type = type
            self.title = title
            self.selectActionHandler = model.selectionType.action()
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    func buildCell() {
        
        switch type {
        case .centered(titleColor: let titleColor, backgroundColor: let backgroundColor):
            let label = UILabel()
            contentView.backgroundColor = backgroundColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 2
            label.lineBreakMode = .byWordWrapping
            label.text = title
            label.textColor = titleColor
            label.font = UIFont.boldSystemFont(ofSize: label.font.pointSize)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            contentView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
                label.heightAnchor.constraint(lessThanOrEqualToConstant: 44)
                ])
        case .leftDisplayViewController:
            textLabel?.text = title
            accessoryType = .disclosureIndicator
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAction(presentingViewController: UIViewController) {
        selectActionHandler(presentingViewController)
    }
}

class RatingCell : UITableViewCell, SettingsCell {
    
    let initialText: String
    let ratingsTextColor: UIColor
    let updateTitleHandler: (_ appInfoDict: [AnyHashable : Any]) -> (String)
    let appStoreID: String
    let selectAction: (_ presentingViewController: UIViewController) -> ()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .ratingsCell(let initialText, let textColor, let appStoreID, let updateTitleHandler) = model.cellType,
            case .cellButtonAction(action: let selectAction) = model.selectionType {
            self.initialText = initialText
            self.ratingsTextColor = textColor
            self.appStoreID = appStoreID
            self.updateTitleHandler = updateTitleHandler
            self.selectAction = selectAction
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.text = initialText
        label.textColor = ratingsTextColor
        label.font = UIFont.systemFont(ofSize: 12)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: kLeadingPaddingToMatchSystemCellLabel),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
            label.heightAnchor.constraint(lessThanOrEqualToConstant: 44)
            ])
        
        let appInfo = AppInfo(with: appStoreID)
        appInfo.getData { (dataDict : [AnyHashable : Any]) in
            DispatchQueue.main.async {
                label.text = self.updateTitleHandler(dataDict)
            }
        }
    }
    
    static func defaultSelectAction() -> SettingsCellSelectionType {
        return .cellButtonAction(action: { (_) in
            SKStoreReviewController.requestReview()
        })
    }
    
    func selectAction(presentingViewController: UIViewController) {
        selectAction(presentingViewController)
    }
}

class TextFieldCell: UITableViewCell, SettingsCell {
    
    let title: String
    let fieldMinimumWidth: CGFloat
    let fieldMaximumWidthPercent: CGFloat?
    let getStringHandler: () -> (String?, UIColor?)
    let setStringHandler: (String) -> ()
    let selectActionHandler: (_ presentingViewController: UIViewController) -> ()
    
    let textField = UITextField()
    
    weak var gestureRecognizer: UITapGestureRecognizer?
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .textFieldCell(title: let title, fieldPlaceholder: let fieldPlaceholder, let fieldMinimumWidth, let fieldMaximumWidthPercent, let fieldKeyboardType, let getStringHandler, let setStringHandler) = model.cellType {
            self.title = title ?? ""
            self.fieldMinimumWidth = fieldMinimumWidth ?? 50
            self.fieldMaximumWidthPercent = fieldMaximumWidthPercent
            textField.placeholder = fieldPlaceholder
            textField.keyboardType = fieldKeyboardType
            self.getStringHandler = getStringHandler
            self.setStringHandler = setStringHandler
            self.selectActionHandler = model.selectionType.action()
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    func buildCell() {
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        textField.delegate = self
        
        let (fieldText, fieldTextColor) = getStringHandler()
        textField.text = fieldText
        textField.textColor = fieldTextColor ?? .blue
        
        if title.isEmpty {
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: kLeadingPaddingToMatchSystemCellLabel),
                textField.heightAnchor.constraint(lessThanOrEqualToConstant: 44),
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
                textField.widthAnchor.constraint(greaterThanOrEqualToConstant: fieldMinimumWidth)
                ])
        } else {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 2
            label.lineBreakMode = .byWordWrapping
            label.text = title
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            contentView.addSubview(label)
            
            var constraints = [NSLayoutConstraint]()
            
            constraints = [
                label.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: kLeadingPaddingToMatchSystemCellLabel),
                label.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
                label.heightAnchor.constraint(lessThanOrEqualToConstant: 44),
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
                textField.widthAnchor.constraint(greaterThanOrEqualToConstant: fieldMinimumWidth),
                textField.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8)
            ]
            
            if let fieldMaximumWidthPercent = fieldMaximumWidthPercent {
                constraints.append(textField.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: fieldMaximumWidthPercent / 100))
            }
            
            NSLayoutConstraint.activate(constraints)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAction(presentingViewController: UIViewController) {
        self.selectActionHandler(presentingViewController)
    }
}

extension TextFieldCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        gestureRecognizer?.isEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        setStringHandler(textField.text ?? "")
    }
}

struct SettingsSection {
    let title: String?
    let cellModels: [SettingsCellModel]
}

class SettingsTVC: UITableViewController {
    
    let defaults = StandardUserDefaults()
    var gestureRecognizer: UITapGestureRecognizer!
    var sections = [SettingsSection]()
    var textFields = [UITextField]()
    
    init(sections: [SettingsSection]) {  // or ensure sections are populated before tableView attempts to load
        self.sections = sections
        super.init(style: .grouped)
        self.gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(gestureRecognizer:)))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        tableView.rowHeight = 44
        gestureRecognizer.numberOfTapsRequired = 1
        gestureRecognizer.numberOfTouchesRequired = 1
        gestureRecognizer.isEnabled = false
        tableView.addGestureRecognizer(gestureRecognizer)
        super.viewDidLoad()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cellModels.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = sections[indexPath.section].cellModels[indexPath.row]
        let cellIdentifier = "\(indexPath.section)-\(indexPath.row)"
        if let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) {
            return cell
        }
        switch model.cellType {
        case .boolSwitch(_,_,_):
            if let cell = SwitchCell(model: model, identifier: cellIdentifier) {
                return cell
            }
        case .rightSelection(_,_):
            if let cell = RightSelectionCell(model: model, identifier: cellIdentifier) {
                return cell
            }
        case .buttonCell(_,_):
            if let cell = ButtonCell(model: model, identifier: cellIdentifier) {
                return cell
            }
        case .ratingsCell(_,_,_,_):
            if let cell = RatingCell(model: model, identifier: cellIdentifier) {
                return cell
            }
        case .textFieldCell(_,_,_,_,_,_,_):
            if let cell = TextFieldCell(model: model, identifier: cellIdentifier) {
                textFields.append(cell.textField)
                cell.gestureRecognizer = gestureRecognizer
                return cell
            }
        }
        // failed
        print("Failed to create a cell for \(model) at \(indexPath)")
        return UITableViewCell(style: .default, reuseIdentifier: "errorCase")
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? SettingsCell {
            cell.selectAction(presentingViewController: self)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    @objc func handleGesture(gestureRecognizer: UIGestureRecognizer) {
        for textField in textFields {
            textField.resignFirstResponder()
        }
        gestureRecognizer.isEnabled = false
    }
}


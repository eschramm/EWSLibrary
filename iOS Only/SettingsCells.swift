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

public typealias CellDetailGetStringHandler = () -> (String, UIColor?)

public enum SettingsCellType {
    
    public enum ButtonCellType {
        case centered(titleColor: UIColor, backgroundColor: UIColor)
        case leftDisplayViewController(backgroundColor: UIColor?, accessory: UITableViewCell.AccessoryType?)
    }
    
    case boolSwitch(title: String, getBoolHandler: () -> (Bool), setBoolHandler: (Bool) -> ())
    case rightSelection(title: String, getStringHandler: CellDetailGetStringHandler? = nil)
    case buttonCell(type: ButtonCellType, title: String)
    case ratingsCell(initialTitle: String, titleColor: UIColor, appStoreID: String, updateTitleHandler: (_ appInfoDict: [AnyHashable : Any]) -> (String))
    case iapCell(initialTitle: String, purchasedTitle: String, iapKey: String)
    case textFieldCell(title: String?, fieldPlaceholder: String?, fieldMinimumWidth: CGFloat?, fieldMaximumWidthPercent: CGFloat?, fieldKeyboard: UIKeyboardType, getStringHandler: () -> (String?, UIColor?), setStringHandler: (String) -> ())
    case dateCell(attributes: DateCellAttributes)
    case tagCloudCell(cloudID: String, tagCloudDelegate: TagCloudDelegate, parameters: TagCloudParameters = TagCloudParameters())
}

public struct DateCellAttributes {
    let title: String?
    let fieldPlaceholder: String?
    let datePickerMode: UIDatePicker.Mode
    let dateFormatter: DateFormatter
    let getDateHandler: () -> (Date?, UIColor?)
    let setDateHandler: (Date?) -> ()
    
    public init(title: String?, fieldPlaceholder: String?, datePickerMode: UIDatePicker.Mode, dateFormatter: DateFormatter, getDateHandler: @escaping () -> (Date?, UIColor?), setDateHandler: @escaping (Date?) -> ()) {
        self.title = title
        self.fieldPlaceholder = fieldPlaceholder
        self.datePickerMode = datePickerMode
        self.dateFormatter = dateFormatter
        self.getDateHandler = getDateHandler
        self.setDateHandler = setDateHandler
    }
}

public protocol PickerDelegate: class {
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

public enum SettingsCellSelectionType {
    
    case helpText(title: String, message: String)
    case helpTextPresentPicker(titleMessage: String, message: String, actionString: String, pickerPresenter: PickerPresenter, allowRemoveDefaultAction: Bool)
    case presentPicker(pickerPresenter: PickerPresenter)
    case cellButtonAction(action: (_ presentingViewController: UIViewController)->())
    case handledByCell
    
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
        case .presentPicker(let pickerPresenter):
            return { (presentingViewController) in
                pickerPresenter.summonPicker(presentingViewController: presentingViewController)
            }
        case .cellButtonAction(let action):
            return { (presentingViewController) in
                action(presentingViewController)
            }
        case .handledByCell:
            return { (_) in }
        }
    }
}

public struct SettingsCellModel {
    let cellType: SettingsCellType
    let selectionType: SettingsCellSelectionType
    let visibilityHandler: (() -> Bool)?
    public init(cellType: SettingsCellType, selectionType: SettingsCellSelectionType, visibilityHandler: (() -> Bool)? = nil) {
        self.cellType = cellType
        self.selectionType = selectionType
        self.visibilityHandler = visibilityHandler
    }
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
        label.numberOfLines = 0
        label.text = title
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)  // ensures on doesn't push switch off view on rotation and back
        contentView.addSubview(label)
        
        let cellSwitch = UISwitch()
        cellSwitch.translatesAutoresizingMaskIntoConstraints = false
        cellSwitch.isOn = getBoolHandler()
        cellSwitch.addTarget(self, action: #selector(switchToggled(_:)), for: .valueChanged)
        contentView.addSubview(cellSwitch)
        
        let marginGuide = contentView.layoutMarginsGuide
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
            label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor),
            cellSwitch.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
            cellSwitch.centerYAnchor.constraint(equalTo: marginGuide.centerYAnchor),
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
    let getStringHandler: CellDetailGetStringHandler?
    var pickerPresenter: PickerPresenter?
    let selectionAction: ((UIViewController) -> ())
    
    let rightSelectionLabel = UILabel()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .rightSelection(let title, let getStringHandler) = model.cellType {
            self.title = title
            self.getStringHandler = getStringHandler
            if case SettingsCellSelectionType.helpTextPresentPicker(_,_,_, let pickerPresenter,_) = model.selectionType {
                self.pickerPresenter = pickerPresenter
                self.selectionAction = model.selectionType.action()
                super.init(style: .default, reuseIdentifier: identifier)
                buildCell()
            } else if case SettingsCellSelectionType.cellButtonAction(action: let selectionAction) = model.selectionType {
                self.pickerPresenter = nil
                self.selectionAction = selectionAction
                super.init(style: .default, reuseIdentifier: identifier)
                buildCell()
            } else if case SettingsCellSelectionType.presentPicker(pickerPresenter: let pickerPresenter) = model.selectionType {
                self.pickerPresenter = pickerPresenter
                self.selectionAction = model.selectionType.action()
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
        label.numberOfLines = 0
        label.text = title
        contentView.addSubview(label)
        
        rightSelectionLabel.translatesAutoresizingMaskIntoConstraints = false
        rightSelectionLabel.numberOfLines = 0
        contentView.addSubview(rightSelectionLabel)
        
        updateSelection()
        
        let marginGuide = contentView.layoutMarginsGuide
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
            label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualTo: marginGuide.widthAnchor, multiplier: 0.4),
            rightSelectionLabel.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor, constant: -8),
            rightSelectionLabel.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            rightSelectionLabel.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor),
            rightSelectionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            rightSelectionLabel.widthAnchor.constraint(greaterThanOrEqualTo: marginGuide.widthAnchor, multiplier: 0.4),
        ])
        
        pickerPresenter?.add(pickerPresenterSelectionHandler: PickerPresenterSelectionHandler(sortPriority: 5, itemSelectedHandler: { [weak self] (updatedItem) in
            self?.rightSelectionLabel.text = updatedItem?.displayTitle()
            self?.updateSelection()
        }))
    }
    
    func updateSelection() {
        guard let getStringHandler = getStringHandler else { return }
        let (rightSelectionText, rightSelectionColor) = getStringHandler()
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
        rightSelectionLabel.text = rightSelectionText
        
        #if swift(>=5.1)
            if #available(iOS 13, *) {
                rightSelectionLabel.textColor = rightSelectionColor ?? .systemBlue
            } else {
                rightSelectionLabel.textColor = rightSelectionColor ?? .blue
            }
        #else
            rightSelectionLabel.textColor = rightSelectionColor ?? .blue
        #endif
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
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
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.text = title
        contentView.addSubview(label)
        
        let marginGuide = contentView.layoutMarginsGuide
        
        switch type {
        case .centered(titleColor: let titleColor, backgroundColor: let backgroundColor):
            label.textColor = titleColor
            label.font = UIFont.boldSystemFont(ofSize: label.font.pointSize)
            label.textAlignment = .center
            contentView.backgroundColor = backgroundColor
        case .leftDisplayViewController(backgroundColor: let backgroundColor, accessory: let accessory):
            label.textAlignment = .natural
            if let backgroundColor = backgroundColor {
                contentView.superview?.backgroundColor = backgroundColor
            }
            accessoryType = accessory ?? .disclosureIndicator
        }
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAction(presentingViewController: UIViewController) {
        selectActionHandler(presentingViewController)
    }
}

public class RatingCell : UITableViewCell, SettingsCell {
    
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
        label.numberOfLines = 0
        label.text = initialText
        label.textColor = ratingsTextColor
        label.font = UIFont.systemFont(ofSize: 12)
        contentView.addSubview(label)
        
        let marginGuide = contentView.layoutMarginsGuide
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        ])
        
        let appInfo = AppInfo(with: appStoreID)
        appInfo.getData { (dataDict : [AnyHashable : Any]) in
            DispatchQueue.main.async { [weak self] in
                NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
                label.text = self?.updateTitleHandler(dataDict)
                NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
            }
        }
    }
    
    public static func defaultSelectAction() -> SettingsCellSelectionType {
        return .cellButtonAction(action: { (_) in
            SKStoreReviewController.requestReview()
        })
    }
    
    func selectAction(presentingViewController: UIViewController) {
        selectAction(presentingViewController)
    }
}

public class IAPCell : UITableViewCell, SettingsCell {
    
    let initialTitle: String
    let purchasedTitle: String
    let iapKey: String
    let selectAction: (_ presentingViewController: UIViewController) -> ()
    let label = UILabel()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .iapCell(let initialTitle, let purchasedTitle, let iapKey) = model.cellType.self,
            case .cellButtonAction(action: let selectAction) = model.selectionType {
            self.initialTitle = initialTitle
            self.purchasedTitle = purchasedTitle
            self.iapKey = iapKey
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
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        contentView.addSubview(label)
        
        let marginGuide = contentView.layoutMarginsGuide
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        ])
        
        update()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(IAPCell.update),
            name: NSNotification.Name("IAPHelperProductPurchasedNotification"),
            object: nil)
    }
    
    @objc func update() {
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
        selectionStyle = UserDefaults.standard.bool(forKey: iapKey) ? .none : .default
        label.text = UserDefaults.standard.bool(forKey: iapKey) ? purchasedTitle : initialTitle
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
    }
    
    public static func defaultSelectAction(iapCoordinator: IAPCoordinator, productIdentifier: String) -> SettingsCellSelectionType {
        return .cellButtonAction(action: { (presentingController) in
            if UserDefaults.standard.bool(forKey: iapCoordinator.productPackage.identifier) {
                // already purchased
                return
            }
            let presentHandler: (UIViewController) -> () = { (viewController) in
                let navigationController = UINavigationController(rootViewController: viewController)
                presentingController.present(navigationController, animated: true, completion: nil)
                viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: iapCoordinator, action: #selector(IAPCoordinator.dismiss))
            }
            let dismissHandler: (UIViewController) -> () = { _ in
                presentingController.dismiss(animated: true, completion: nil)
            }
            iapCoordinator.present(for: productIdentifier, presentHandler: presentHandler, dismissHandler: dismissHandler)
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
    
    weak var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer?
    
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
        
        #if swift(>=5.1)
            if #available(iOS 13, *) {
                textField.textColor = fieldTextColor ?? .systemBlue
            } else {
                textField.textColor = fieldTextColor ?? .blue
            }
        #else
            textField.textColor = fieldTextColor ?? .blue
        #endif
        
        let marginGuide = contentView.layoutMarginsGuide
        
        if title.isEmpty {
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
                textField.topAnchor.constraint(equalTo: marginGuide.topAnchor),
                textField.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
            ])
        } else {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.text = title
            contentView.addSubview(label)
            
            var constraints = [NSLayoutConstraint]()
            
            constraints = [
                label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
                label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
                label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor),
                textField.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor, constant: -8),
                textField.topAnchor.constraint(equalTo: marginGuide.topAnchor),
                textField.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor),
                textField.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8)
            ]
            
            if let fieldMaximumWidthPercent = fieldMaximumWidthPercent {
                constraints.append(textField.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: fieldMaximumWidthPercent / 100))
            } else {
                constraints.append(contentsOf: [
                    label.widthAnchor.constraint(greaterThanOrEqualTo: marginGuide.widthAnchor, multiplier: 0.4),
                    textField.widthAnchor.constraint(greaterThanOrEqualTo: marginGuide.widthAnchor, multiplier: 0.4)
                ])
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
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        setStringHandler(textField.text ?? "")
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
    }
}

class DateCell: UITableViewCell, SettingsCell {
    
    let title: String
    let dateFormatter: DateFormatter
    let getDateHandler: () -> (Date?, UIColor?)
    let setDateHandler: (Date?) -> ()
    var noPickerVerticalConstraints = [NSLayoutConstraint]()
    var pickerVerticalConstraints = [NSLayoutConstraint]()
    
    var datePicker = UIDatePicker()
    let textField = UITextField()
    
    let fieldMinimumWidth: CGFloat = 100
    
    weak var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer?
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .dateCell(let attributes) = model.cellType {
            self.title = attributes.title ?? ""
            textField.placeholder = attributes.fieldPlaceholder
            textField.keyboardType = .numbersAndPunctuation
            self.dateFormatter = attributes.dateFormatter
            self.getDateHandler = attributes.getDateHandler
            self.setDateHandler = attributes.setDateHandler
            datePicker.datePickerMode = attributes.datePickerMode
            
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    func buildCell() {
        
        accessoryType = .disclosureIndicator
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        textField.delegate = self
        textField.textAlignment = .right
        
        let (date, fieldTextColor) = getDateHandler()
        if let date = date {
            textField.text = dateFormatter.string(from: date)
            datePicker.date = date
        }
        
        #if swift(>=5.1)
            if #available(iOS 13, *) {
                textField.textColor = fieldTextColor ?? .systemBlue
            } else {
                textField.textColor = fieldTextColor ?? .blue
            }
        #else
            textField.textColor = fieldTextColor ?? .blue
        #endif
        
        datePicker.addTarget(self, action: #selector(pickerChanged), for: .valueChanged)
        
        let marginGuide = contentView.layoutMarginsGuide
        
        noPickerVerticalConstraints = [
            textField.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            textField.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        ]
        let bottomConstraint = datePicker.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        bottomConstraint.priority = UILayoutPriority(rawValue: 999)
        pickerVerticalConstraints = [
            textField.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            datePicker.centerXAnchor.constraint(equalTo: marginGuide.centerXAnchor),
            bottomConstraint
        ]
        
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        
        var constraints = [NSLayoutConstraint]()
        
        if title.isEmpty {
            constraints = [
                textField.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: kLeadingPaddingToMatchSystemCellLabel),
                textField.heightAnchor.constraint(lessThanOrEqualToConstant: 44),
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                textField.widthAnchor.constraint(greaterThanOrEqualToConstant: fieldMinimumWidth)
                ]
            pickerVerticalConstraints.append(datePicker.topAnchor.constraint(equalTo: textField.bottomAnchor))
        } else {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.text = title
            contentView.addSubview(label)
            
            noPickerVerticalConstraints.append(contentsOf: [
                label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
                label.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
            ])
            pickerVerticalConstraints.append(contentsOf: [
                label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
                datePicker.topAnchor.constraint(equalTo: label.bottomAnchor)
            ])
            
            constraints = [
                label.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor, constant: -8),
                textField.widthAnchor.constraint(greaterThanOrEqualToConstant: fieldMinimumWidth),
                textField.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            ]
        }
        
        constraints.append(contentsOf: noPickerVerticalConstraints)
        NSLayoutConstraint.activate(constraints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAction(presentingViewController: UIViewController) {
        if let _ = datePicker.superview {
            removePicker()
        } else {
            addPicker()
        }
    }
    
    func addPicker() {
        guard datePicker.superview == nil else { return }
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
        contentView.addSubview(datePicker)
        NSLayoutConstraint.deactivate(noPickerVerticalConstraints)
        NSLayoutConstraint.activate(pickerVerticalConstraints)
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
    }
    
    func removePicker() {
        guard let _ = datePicker.superview else { return }
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
        NSLayoutConstraint.deactivate(pickerVerticalConstraints)
        datePicker.removeFromSuperview()
        NSLayoutConstraint.activate(noPickerVerticalConstraints)
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
    }
    
    @objc func pickerChanged() {
        textField.text = dateFormatter.string(from: datePicker.date)
        textFieldDidEndEditing(textField)
    }
}

extension DateCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        setDateHandler(dateFormatter.date(from: textField.text ?? ""))
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
    }
}

public struct SettingsSection {
    let title: String?
    let cellModels: [SettingsCellModel]
    public init(title: String?, cellModels: [SettingsCellModel]) {
        self.title = title
        self.cellModels = cellModels
    }
}

public extension Notification.Name {
    static let SettingsTVCCheckForVisibilityChanges = Notification.Name(rawValue: "SettingsTVCCheckForVisibilityChanges")
    static let SettingsTVCTableviewBeginUpdates = Notification.Name(rawValue: "SettingsTVCTableviewBeginUpdates")
    static let SettingsTVCTableviewEndUpdates = Notification.Name(rawValue: "SettingsTVCTableviewEndUpdates")
}

public class Trampoline {
    public weak var testSettingsTVC: SettingsTVC?
}

open class SettingsTVC: UITableViewController {
    
    var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer!
    var sections = [SettingsSection]()
    var textFields = [UITextField]()
    var indexPathsForHidableCells = [IndexPath]()
    public let trampoline: Trampoline
    
    public init(sections: [SettingsSection]) {  // or ensure sections are populated before tableView attempts to load
        self.sections = sections
        self.trampoline = Trampoline()
        super.init(style: .grouped)
        self.gestureRecognizerToDismissFirstResponder = UITapGestureRecognizer(target: self, action: #selector(handleGesture(gestureRecognizer:)))
        self.trampoline.testSettingsTVC = self
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
        return sections[section].cellModels.count
    }
    
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = sections[indexPath.section].cellModels[indexPath.row]
        let cellIdentifier = "\(indexPath.section)-\(indexPath.row)"
        if let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) {
            configure(cell: cell, model: model)
            return cell
        }
        switch model.cellType {
        case .boolSwitch(_,_,_):
            if let cell = SwitchCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .rightSelection(_,_):
            if let cell = RightSelectionCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .buttonCell(_,_):
            if let cell = ButtonCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .ratingsCell(_,_,_,_):
            if let cell = RatingCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .iapCell(_,_,_):
            if let cell = IAPCell(model: model, identifier: cellIdentifier) {
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .textFieldCell(_,_,_,_,_,_,_):
            if let cell = TextFieldCell(model: model, identifier: cellIdentifier) {
                textFields.append(cell.textField)
                cell.gestureRecognizerToDismissFirstResponder = gestureRecognizerToDismissFirstResponder
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .dateCell(_):
            if let cell = DateCell(model: model, identifier: cellIdentifier) {
                textFields.append(cell.textField)
                cell.gestureRecognizerToDismissFirstResponder = gestureRecognizerToDismissFirstResponder
                configure(cell: cell, model: model)
                if let _ = model.visibilityHandler {
                    indexPathsForHidableCells.append(indexPath)
                }
                return cell
            }
        case .tagCloudCell(let cloudID, let tagCloudDelegate, let parameters):
            let cell = TagCloudCell(cloudID: cloudID, tagCloudDelegate: tagCloudDelegate, reuseIdentifier: cellIdentifier, parameters: parameters)
            configure(cell: cell, model: model)
            if let _ = model.visibilityHandler {
                indexPathsForHidableCells.append(indexPath)
            }
            return cell
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
    }
    
    open override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let model = sections[indexPath.section].cellModels[indexPath.row]
        var showCell = true
        if let visibilityHandler = model.visibilityHandler {
            showCell = visibilityHandler()
        }
        return showCell ? UITableView.automaticDimension : 0
    }
    
    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? SettingsCell {
            if let cell = cell as? DateCell {
                tableView.beginUpdates()
                cell.selectAction(presentingViewController: self)
                tableView.endUpdates()
            } else {
                cell.selectAction(presentingViewController: self)
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
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
            let model = sections[indexPath.section].cellModels[indexPath.row]
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

public class AppInfo : NSObject {  // class from NSObject only for Obj-C compatibility for iQIF
    
    let appID: String
    let session: URLSession
    
    public init(with appID: String) {
        
        self.appID = appID
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: sessionConfig)
    }
    
    public func getData(completion: @escaping (_ dataDict: [AnyHashable : Any]) -> Void) {
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "itunes.apple.com"
        urlComponents.path = "/lookup"
        urlComponents.queryItems = [URLQueryItem(name: "id", value: appID)]
        
        guard let storeURL = urlComponents.url else { return }
        
        let task = session.dataTask(with: storeURL) {
            
            (data, response, error) -> Void in
            
            guard error == nil else {
                if let error = error {
                    print(error.localizedDescription)
                }
                return
            }
            
            guard let data = data else { return }
            
            if let possibleDict = ((try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable : Any]) as [AnyHashable : Any]??), let dict = possibleDict {
                completion(dict)
                //print(possibleDict)
            }
            
        }
        task.resume()
    }
}


/*
 
 AppInfo *appInfo = [[AppInfo alloc] initWith:@"386493543"];
 [appInfo getDataWithCompletion:^(NSDictionary* _Nonnull dataDict) {
 NSArray *dict = dataDict[@"results"];
 if ([dict isKindOfClass:[NSArray class]]) {
 NSDictionary *result = [dict firstObject];
 if (result) {
 NSString *totalReviewsCount = result[@"userRatingCount"];
 NSString *versionReviewsCount = result[@"userRatingCountForCurrentVersion"];
 NSString *totalUserRating = result[@"averageUserRating"];
 NSLog(@"%@\n%@\n%@", totalReviewsCount, versionReviewsCount, totalUserRating);
 }
 }
 }];
 
 https://itunes.apple.com/lookup?id=386493543
 {
 "resultCount":1,
 "results": [
 {
 "ipadScreenshotUrls":["http://a5.mzstatic.com/us/r30/Purple3/v4/e3/7a/ff/e37affe2-10d1-9e5b-c53e-52e224d3e5a0/screen480x480.jpeg", "http://a4.mzstatic.com/us/r30/Purple1/v4/9d/61/97/9d6197a4-ef52-3523-3851-18560391e1b9/screen480x480.jpeg", "http://a3.mzstatic.com/us/r30/Purple3/v4/a4/98/f9/a498f9c5-461c-79b8-9c4d-83be09abb0c2/screen480x480.jpeg", "http://a4.mzstatic.com/us/r30/Purple3/v4/91/ab/c2/91abc2d0-59c1-3e8d-18ef-90bd450c2362/screen480x480.jpeg"], "appletvScreenshotUrls":[], "artworkUrl512":"http://is5.mzstatic.com/image/thumb/Purple49/v4/be/78/8f/be788f6a-4fe1-0139-f651-b040d3d5fa88/source/512x512bb.jpg", "artistViewUrl":"https://itunes.apple.com/us/developer/eric-schramm/id386493546?uo=4", "artworkUrl60":"http://is5.mzstatic.com/image/thumb/Purple49/v4/be/78/8f/be788f6a-4fe1-0139-f651-b040d3d5fa88/source/60x60bb.jpg", "artworkUrl100":"http://is5.mzstatic.com/image/thumb/Purple49/v4/be/78/8f/be788f6a-4fe1-0139-f651-b040d3d5fa88/source/100x100bb.jpg", "kind":"software", "features":["iosUniversal"],
 "supportedDevices":["iPad2Wifi", "iPad23G", "iPhone4S", "iPadThirdGen", "iPadThirdGen4G", "iPhone5", "iPodTouchFifthGen", "iPadFourthGen", "iPadFourthGen4G", "iPadMini", "iPadMini4G", "iPhone5c", "iPhone5s", "iPhone6", "iPhone6Plus", "iPodTouchSixthGen"], "advisories":[],
 "screenshotUrls":["http://a1.mzstatic.com/us/r30/Purple3/v4/5d/ea/9a/5dea9a4f-80ba-7609-5b9f-13d9f56f2357/screen696x696.jpeg", "http://a4.mzstatic.com/us/r30/Purple3/v4/b1/c6/91/b1c691ec-9fde-6d4d-247f-5fb9ea6174cd/screen696x696.jpeg", "http://a3.mzstatic.com/us/r30/Purple3/v4/98/13/ef/9813efca-f3a9-7a7a-86ba-3b4d2dc65387/screen696x696.jpeg", "http://a2.mzstatic.com/us/r30/Purple3/v4/f5/a7/b6/f5a7b6e6-3932-e1cc-5d42-146c81593881/screen696x696.jpeg"], "isGameCenterEnabled":false, "averageUserRatingForCurrentVersion":1.0, "languageCodesISO2A":["EN"], "fileSizeBytes":"14227456", "sellerUrl":"http://www.iqif.info/", "userRatingCountForCurrentVersion":1, "trackContentRating":"4+", "trackCensoredName":"iQIF", "trackViewUrl":"https://itunes.apple.com/us/app/iqif/id386493543?mt=8&uo=4", "contentAdvisoryRating":"4+", "currency":"USD", "wrapperType":"software", "version":"3.2.2", "artistId":386493546, "artistName":"Eric Schramm", "genres":["Finance", "Productivity"], "price":0.99,
 "description":"Dissatisfied with the official Quicken iOS apps and only need to enter receipts on-the-go?  Looking for a solution for entering GnuCash transactions on the go?  iQIF is perfect for you.\n\niQIF allows you to effortlessly create transactions on your  iOS device and when ready, export them via a QIF file which can be imported by Quicken, GnuCash or any other money managing application.  It is NOT a bloated pocket version of a money managing application, but simply a mobile transaction-creating interface (i.e. it does not sync both ways with Quicken).  Hopefully others will have found this as useful as I have.  Please note that your desktop finance application must be able to import QIF files.  \nKNOWN ISSUES:  \n- PLEASE VERIFY YOUR VERSION OF QUICKEN CAN IMPORT QIF FILES BEFORE PURCHASING.  There are some newer versions where Intuit has been trying to deprecate the use of the QIF format in favor of the proprietary OFX format. DOES NOT WORK WITH QUICKEN ESSENTIALS.\n\n*** PLEASE CONTACT ME PERSONALLY WITH PROBLEMS BEFORE GIVING UP ON iQIF - Unfortunately I cannot contact those who leave reviews expressing dissatisfaction, but in many cases I might have been able to remedy the issue and possibly help others having the same issue. ***", "releaseDate":"2010-08-18T02:57:49Z", "trackName":"iQIF", "bundleId":"com.eware.iqif", "trackId":386493543, "primaryGenreName":"Finance", "isVppDeviceBasedLicensingEnabled":true, "currentVersionReleaseDate":"2016-04-09T15:36:20Z", "releaseNotes":"• bugfix - swiping to delete a split no longer causes iQIF to crash", "sellerName":"Eric Schramm", "minimumOsVersion":"8.0", "primaryGenreId":6015, "formattedPrice":"$0.99", "genreIds":["6015", "6007"], "averageUserRating":4.0, "userRatingCount":70}]
 }*/

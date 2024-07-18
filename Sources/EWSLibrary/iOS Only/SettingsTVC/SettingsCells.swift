//
//  SettingsOtherCells.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/5/20.
//  Copyright © 2020 eware. All rights reserved.
//

#if os(iOS)
import UIKit


public typealias CellDetailGetStringHandler = () -> (String, UIColor?)

public enum SettingsCellType {
    
    public enum ButtonCellType {
        case centered(titleColor: UIColor, backgroundColor: UIColor)
        case leftDisplayViewController(backgroundColor: UIColor?, accessory: UITableViewCell.AccessoryType?)
    }
    
    case boolSwitch(title: String, getBoolHandler: () -> (Bool), setBoolHandler: (Bool) -> ())
    case rightSelection(title: String, getStringHandler: CellDetailGetStringHandler? = nil, refreshOnViewWillAppear: Bool = false)
    case buttonCell(type: ButtonCellType, title: String)
    case ratingsCell(initialTitle: String, titleColor: UIColor, appStoreID: String, updateTitleHandler: (_ appInfoDict: [AnyHashable : Any]) -> (String))
    case iapCell(initialTitle: String, purchasedTitle: String, iapKey: String)
    case textFieldCell(attributes: TextFieldAttributes)
    case dateCell(attributes: DateCellAttributes)
    case tagCloudCell(cloudID: String, addTagTitle: String, addTagInstructions: String, tagCloudDelegate: TagCloudDelegate, parameters: TagCloudParameters = TagCloudParameters())
    case photoCell(maxCellHeight: CGFloat?, getImageTitleHandler: () -> (UIImage?, String?), setImageUpdateTitleHandler: (UIImage?) -> (String?))
    case textViewCell(attributes: TextViewAttributes)
}

public struct DateCellAttributes {
    let title: String?
    let fieldPlaceholder: String?
    let datePickerMode: UIDatePicker.Mode
    let dateFormatter: DateFormatter
    let dismissalSetsDateToPickerDate: Bool
    let getDateHandler: () -> (Date?, UIColor?)
    let setDateHandler: (Date?) -> ()
    
    
    public init(title: String?, fieldPlaceholder: String?, datePickerMode: UIDatePicker.Mode, dateFormatter: DateFormatter, dismissalSetsDateToPickerDate: Bool, getDateHandler: @escaping () -> (Date?, UIColor?), setDateHandler: @escaping (Date?) -> ()) {
        self.title = title
        self.fieldPlaceholder = fieldPlaceholder
        self.datePickerMode = datePickerMode
        self.dateFormatter = dateFormatter
        self.dismissalSetsDateToPickerDate = dismissalSetsDateToPickerDate
        self.getDateHandler = getDateHandler
        self.setDateHandler = setDateHandler
    }
}

public struct TextFieldAttributes {
    let title: String?
    let fieldPlaceHolder: String?
    let fieldMaximumWidthPercent: CGFloat?
    let fieldKeyboard: UIKeyboardType?
    let getStringHandler: () -> (String?, UIColor?)
    let setStringHandler: (String) -> ()
    let isValidHandler: (String) -> (Bool)
    
    public init(title: String, fieldPlaceHolder: String?, fieldMaximumWidthPercent: CGFloat?, fieldKeyboard: UIKeyboardType?, getStringHandler: @escaping () -> (String?, UIColor?), setStringHandler: @escaping (String) -> (), isValidHandler: @escaping (String) -> (Bool)) {
        self.title = title
        self.fieldPlaceHolder = fieldPlaceHolder
        self.fieldMaximumWidthPercent = fieldMaximumWidthPercent
        self.fieldKeyboard = fieldKeyboard
        self.getStringHandler = getStringHandler
        self.setStringHandler = setStringHandler
        self.isValidHandler = isValidHandler
    }
}

public struct TextViewAttributes {
    let title: String?
    let fieldKeyboard: UIKeyboardType?
    let getStringHandler: () -> (String?, UIColor?)
    let setStringHandler: (String) -> ()
    
    public init(title: String, fieldKeyboard: UIKeyboardType?, getStringHandler: @escaping () -> (String?, UIColor?), setStringHandler: @escaping (String) -> ()) {
        self.title = title
        self.fieldKeyboard = fieldKeyboard
        self.getStringHandler = getStringHandler
        self.setStringHandler = setStringHandler
    }
}

public enum SettingsCellSelectionType {
    
    case helpText(title: String, message: String)
    case helpTextPresentPicker(titleMessage: String, message: String, actionString: String, pickerPresenter: PickerPresenter, allowRemoveDefaultAction: Bool)
    case presentPicker(pickerPresenter: PickerPresenter)
    case cellButtonAction(action: (_ presentingViewController: UIViewController)->())
    case handledByCell
    
    @MainActor
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
    let additionalProperties: [SettingsCellProperties]
    public init(cellType: SettingsCellType, selectionType: SettingsCellSelectionType, additionalProperties: [SettingsCellProperties] = [], visibilityHandler: (() -> Bool)? = nil) {
        self.cellType = cellType
        self.selectionType = selectionType
        self.visibilityHandler = visibilityHandler
        self.additionalProperties = additionalProperties
    }
}

public enum SettingsCellProperties {
    case gestureRecognizers(gestureRecognizers: [UIGestureRecognizer])
    
    @MainActor
    func addProperties(cell: UITableViewCell) {
        switch self {
        case .gestureRecognizers(let gestureRecognizers):
            for gestureRecognizer in gestureRecognizers {
                cell.addGestureRecognizer(gestureRecognizer)
            }
        }
    }
}

@MainActor
protocol SettingsCell {
    func selectAction(presentingViewController: UIViewController)
}

class SettingsSwitchCell: UITableViewCell, SettingsCell {
    
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

class SettingsRightSelectionCell: UITableViewCell, SettingsCell {
    
    let title: String
    let getStringHandler: CellDetailGetStringHandler?
    var pickerPresenter: PickerPresenter?
    let selectionAction: ((UIViewController) -> ())
    
    let rightSelectionLabel = UILabel()
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .rightSelection(let title, let getStringHandler, _) = model.cellType {
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
        rightSelectionLabel.textAlignment = .right
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

class SettingsButtonCell: UITableViewCell, SettingsCell {
    
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



public class SettingsIAPCell : UITableViewCell, SettingsCell {
    
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
            selector: #selector(SettingsIAPCell.update),
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
                DispatchQueue.main.async {
                    let navigationController = UINavigationController(rootViewController: viewController)
                    presentingController.present(navigationController, animated: true, completion: nil)
                    viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: iapCoordinator, action: #selector(IAPCoordinator.dismiss))
                }
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

class SettingsTextFieldCell: UITableViewCell, SettingsCell {
    
    let title: String
    let fieldMaximumWidthPercent: CGFloat?
    let getStringHandler: () -> (String?, UIColor?)
    let setStringHandler: (String) -> ()
    let isValidHandler: (String) -> (Bool)
    let selectActionHandler: (_ presentingViewController: UIViewController) -> ()
    
    let textField = UITextField()
    
    weak var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer?
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .textFieldCell(let attributes) = model.cellType {
            self.title = attributes.title ?? ""
            self.fieldMaximumWidthPercent = attributes.fieldMaximumWidthPercent
            textField.placeholder = attributes.fieldPlaceHolder
            textField.keyboardType = attributes.fieldKeyboard ?? .default
            self.getStringHandler = attributes.getStringHandler
            self.setStringHandler = attributes.setStringHandler
            self.isValidHandler = attributes.isValidHandler
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
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        
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
                textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8)
            ]
            
            if let fieldMaximumWidthPercent = fieldMaximumWidthPercent {
                //constraints.append(textField.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: fieldMaximumWidthPercent / 100))
                constraints.append(textField.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: fieldMaximumWidthPercent / 100))
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
    
    func validateText(text: String) {
        if isValidHandler(text) {
            if #available(iOS 13.0, *) {
                backgroundColor = .systemBackground
                textField.textColor = .systemBlue
            } else {
                backgroundColor = .white
                textField.textColor = .blue
            }
        } else {
            if #available(iOS 13.0, *) {
                backgroundColor = .systemYellow
                textField.textColor = .systemRed
            } else {
                backgroundColor = .yellow
                textField.textColor = .red
            }
        }
    }
}

extension SettingsTextFieldCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        validateText(text: textField.text ?? "")
        setStringHandler(textField.text ?? "")
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
    }
}

class SettingsDateCell: UITableViewCell, SettingsCell {
    
    let title: String
    let dateFormatter: DateFormatter
    let dismissalSetsDateToPickerDate: Bool
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
            self.dismissalSetsDateToPickerDate = attributes.dismissalSetsDateToPickerDate
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
                textField.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
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
        
        if dismissalSetsDateToPickerDate {
            textField.text = dateFormatter.string(from: datePicker.date)
            updateDate()
        }
        
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
        NSLayoutConstraint.deactivate(pickerVerticalConstraints)
        datePicker.removeFromSuperview()
        NSLayoutConstraint.activate(noPickerVerticalConstraints)
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
    }
    
    @objc func pickerChanged() {
        textField.text = dateFormatter.string(from: datePicker.date)
        updateDate()
    }
}

extension SettingsDateCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateDate()
    }
    
    func updateDate() {
        setDateHandler(dateFormatter.date(from: textField.text ?? ""))
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
    }
}

class SettingsTextViewCell: UITableViewCell, SettingsCell {
    
    let title: String
    let getStringHandler: () -> (String?, UIColor?)
    let setStringHandler: (String) -> ()
    let selectActionHandler: (_ presentingViewController: UIViewController) -> ()
    
    let textView = UITextView()
    
    weak var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer?
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .textViewCell(let attributes) = model.cellType {
            self.title = attributes.title ?? ""
            textView.keyboardType = attributes.fieldKeyboard ?? .default
            self.getStringHandler = attributes.getStringHandler
            self.setStringHandler = attributes.setStringHandler
            self.selectActionHandler = model.selectionType.action()
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    func buildCell() {
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        textView.delegate = self
        textView.isScrollEnabled = false
        
        let (fieldText, fieldTextColor) = getStringHandler()
        textView.text = fieldText
        
        #if swift(>=5.1)
            if #available(iOS 13, *) {
                textView.textColor = fieldTextColor ?? .systemBlue
            } else {
                textView.textColor = fieldTextColor ?? .blue
            }
        #else
            textView.textColor = fieldTextColor ?? .blue
        #endif
        
        let marginGuide = contentView.layoutMarginsGuide
        
        if title.isEmpty {
            NSLayoutConstraint.activate([
                textView.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
                textView.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
                textView.topAnchor.constraint(equalTo: contentView.topAnchor),
                textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
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
                label.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor),
                label.topAnchor.constraint(equalTo: marginGuide.topAnchor),
                textView.topAnchor.constraint(equalTo: label.bottomAnchor),
                textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                textView.trailingAnchor.constraint(equalTo: marginGuide.trailingAnchor, constant: -8),
                textView.leadingAnchor.constraint(equalTo: marginGuide.leadingAnchor),
                textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ]
            
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

extension SettingsTextViewCell : UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
        setStringHandler(textView.text)
        NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
    }
}
#endif

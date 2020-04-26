//
//  TableViewCells.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 4/26/20.
//  Copyright © 2020 eware. All rights reserved.
//

import UIKit

public protocol TableViewCell {
    func configureCell(with configuration: TableViewCellConfiguration)
}

public protocol TableViewCellConfiguration { }

public struct TextFieldCellConfiguration: TableViewCellConfiguration {
    let initialValue: String
    let textUpdated: (String) -> ()
    let textIsValid: (String) -> (Bool)
    public init(initialValue: String, textUpdated: @escaping (String) -> (), textIsValid: @escaping (String) -> (Bool)) {
        self.initialValue = initialValue
        self.textUpdated = textUpdated
        self.textIsValid = textIsValid
    }
}

public class TextFieldCell: UITableViewCell, TableViewCell {
    
    weak var gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer?
    
    private let title: String
    private let fieldMaximumWidthPercent: CGFloat?
    private let titleLabel = UILabel()
    
    private var textFieldText = "" {
        didSet {
            textField.text = textFieldText.isEmpty ? nil : textFieldText
            validateText()
        }
    }
    private var textUpdated: (String) -> () = {_ in }
    private var textIsValid: (String) -> (Bool) = { _ in true }
    
    public let textField = UITextField()  // public so it can be added to array to resign first responder
    
    public init(title: String, fieldMaximumWidthPercent: CGFloat?, reuseIdentifier: String, gestureRecognizerToDismissFirstResponder: UITapGestureRecognizer) {
        self.title = title
        self.fieldMaximumWidthPercent = fieldMaximumWidthPercent
        self.gestureRecognizerToDismissFirstResponder = gestureRecognizerToDismissFirstResponder
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
        selectionStyle = .none
    }
    
    public func configureCell(with configuration: TableViewCellConfiguration) {
        if let textFieldConfig = configuration as? TextFieldCellConfiguration {
            textIsValid = textFieldConfig.textIsValid
            textUpdated = textFieldConfig.textUpdated
            textFieldText = textFieldConfig.initialValue
        }
    }
    
    func buildCell() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        textField.delegate = self
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        
        textField.text = textFieldText
        textField.textColor = .systemBlue
        
        let layoutMargins = contentView.layoutMarginsGuide
        
        if title.isEmpty {
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: layoutMargins.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: layoutMargins.trailingAnchor),
                textField.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
                textField.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor)
            ])
        } else {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.text = title
            contentView.addSubview(label)
            
            var constraints = [NSLayoutConstraint]()
            
            constraints = [
                label.leadingAnchor.constraint(equalTo: layoutMargins.leadingAnchor),
                label.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
                label.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor),
                textField.trailingAnchor.constraint(equalTo: layoutMargins.trailingAnchor, constant: -8),
                textField.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
                textField.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor),
                textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8)
            ]
            
            if let fieldMaximumWidthPercent = fieldMaximumWidthPercent {
                constraints.append(textField.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: fieldMaximumWidthPercent / 100))
            } else {
                constraints.append(contentsOf: [
                    label.widthAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.widthAnchor, multiplier: 0.4),
                    textField.widthAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.widthAnchor, multiplier: 0.4)
                ])
            }
            
            NSLayoutConstraint.activate(constraints)
        }
    }
    
    func validateText() {
        if textIsValid(textFieldText) {
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TextFieldCell : UITextFieldDelegate {
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        gestureRecognizerToDismissFirstResponder?.isEnabled = true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        textUpdated(textField.text ?? "")
        textFieldText = textField.text ?? ""
        gestureRecognizerToDismissFirstResponder?.isEnabled = false
    }
}

public struct SegmentedControllCellConfiguration: TableViewCellConfiguration {
    let initialSelectedIndex: Int
    let selectedIndexUpdated: (Int) -> ()
    public init(initialSelectedIndex: Int, selectedIndexUpdated: @escaping (Int) -> ()) {
        self.initialSelectedIndex = initialSelectedIndex
        self.selectedIndexUpdated = selectedIndexUpdated
    }
}

public class SegmentedControlCell: UITableViewCell, TableViewCell {
    
    private var selectedIndex: Int = -1 {
        didSet {
            segmentedControl.selectedSegmentIndex = selectedIndex
        }
    }
    private var selectedIndexUpdated: (Int) -> () = {_ in }
    
    private let title: String
    private let titleLabel = UILabel()
    private let segmentedControl = UISegmentedControl()
    
    public init(title: String, segments: [String], reuseIdentifier: String) {
        self.title = title
        segmentedControl.removeAllSegments()
        for segment in segments.reversed() {
            segmentedControl.insertSegment(withTitle: segment, at: 0, animated: false)
        }
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
        selectionStyle = .none
    }
    
    public func configureCell(with configuration: TableViewCellConfiguration) {
        if let segmentedControlCellConfig = configuration as? SegmentedControllCellConfiguration {
            selectedIndex = segmentedControlCellConfig.initialSelectedIndex
            selectedIndexUpdated = segmentedControlCellConfig.selectedIndexUpdated
        }
    }
    
    func buildCell() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentedControl)
        segmentedControl.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
        
        let layoutMargins = contentView.layoutMarginsGuide
        
        if title.isEmpty {
            NSLayoutConstraint.activate([
                segmentedControl.leadingAnchor.constraint(equalTo: layoutMargins.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: layoutMargins.trailingAnchor),
                segmentedControl.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor)
            ])
        } else {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.text = title
            contentView.addSubview(label)
            
            var constraints = [NSLayoutConstraint]()
            
            constraints = [
                label.leadingAnchor.constraint(equalTo: layoutMargins.leadingAnchor),
                label.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
                label.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: layoutMargins.trailingAnchor, constant: -8),
                segmentedControl.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor),
                segmentedControl.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8)
            ]
            
            NSLayoutConstraint.activate(constraints)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func selectionChanged() {
        selectedIndexUpdated(segmentedControl.selectedSegmentIndex)
    }
}

//
//  AppReleaseNotes.swift
//  StattyCaddy
//
//  Created by Eric Schramm on 5/23/21.
//  Copyright © 2021 Eric Schramm. All rights reserved.
//

#if os(iOS)
import UIKit


public class AppReleaseNotesVC : UIViewController {
    public static let kReleaseNotesViewVersionKey = "AppReleaseNotes.VersionKey"
    public static let kVersionChangesForDisplay = "AppReleaseNotes.ChangesForDisplay"
    
    let completionHandler: () -> ()
    let releaseNotesTitle: String
    let releaseNotesText: String
    
    public init(completion: @escaping () -> ()) {
        self.completionHandler = completion
        
        let currentAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?"
        self.releaseNotesTitle = "What's new in version \(currentAppVersion)"
        
        let lines = Bundle.main.infoDictionary?[Self.kVersionChangesForDisplay] as? [String] ?? []
        self.releaseNotesText = lines.joined(separator: "\n\n")
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.view.frame
        self.view.insertSubview(blurEffectView, at: 0)
        
        let popupView = UIView()
        popupView.translatesAutoresizingMaskIntoConstraints = false
        popupView.backgroundColor = .systemBackground
        popupView.layer.cornerRadius = 15
        popupView.layer.shadowOffset = CGSize(width: 7, height: 7)
        popupView.layer.shadowColor = UIColor.black.cgColor
        popupView.layer.shadowRadius = 5
        popupView.layer.shadowOpacity = 0.7
        blurEffectView.contentView.addSubview(popupView)
        var constraints = [
            popupView.centerYAnchor.constraint(equalTo: blurEffectView.centerYAnchor),
            popupView.centerXAnchor.constraint(equalTo: blurEffectView.centerXAnchor),
            popupView.widthAnchor.constraint(equalTo: blurEffectView.widthAnchor, multiplier: 0.75),
            popupView.heightAnchor.constraint(lessThanOrEqualTo: blurEffectView.heightAnchor, multiplier: 0.6)
        ]
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = releaseNotesTitle
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        popupView.addSubview(titleLabel)
        constraints.append(contentsOf: [
            titleLabel.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: popupView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: popupView.trailingAnchor, constant: -20)
        ])
        
        let titleSeparator = UIView()
        titleSeparator.translatesAutoresizingMaskIntoConstraints = false
        titleSeparator.backgroundColor = .systemGray
        popupView.addSubview(titleSeparator)
        constraints.append(contentsOf: [
            titleSeparator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            titleSeparator.heightAnchor.constraint(equalToConstant: 1),
            titleSeparator.centerXAnchor.constraint(equalTo: popupView.centerXAnchor),
            titleSeparator.widthAnchor.constraint(equalTo: popupView.widthAnchor, multiplier: 0.7)
        ])
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = releaseNotesText
        textView.isEditable = false
        
        let textViewWidth = (view.bounds.size.width * 0.75) - (25 * 2)
        let maximumTextHeight = view.bounds.size.height * 0.5
        let calculatedHeight = (releaseNotesText as NSString).boundingRect(with: CGSize(width: textViewWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: [.font : textView.font ?? UIFont.systemFont(ofSize: 12)], context: nil).height
        textView.isScrollEnabled = (calculatedHeight > maximumTextHeight)
        popupView.addSubview(textView)
        constraints.append(contentsOf: [
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: popupView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: popupView.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            textView.heightAnchor.constraint(lessThanOrEqualToConstant: maximumTextHeight)
        ])
        
        let textSeparator = UIView()
        textSeparator.translatesAutoresizingMaskIntoConstraints = false
        textSeparator.backgroundColor = .systemGray
        popupView.addSubview(textSeparator)
        constraints.append(contentsOf: [
            textSeparator.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 7),
            textSeparator.heightAnchor.constraint(equalToConstant: 1),
            textSeparator.centerXAnchor.constraint(equalTo: popupView.centerXAnchor),
            textSeparator.widthAnchor.constraint(equalTo: popupView.widthAnchor, multiplier: 0.7)
        ])
        
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(dismissNotes), for: .touchUpInside)
        popupView.addSubview(closeButton)
        constraints.append(contentsOf: [
            closeButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 20),
            closeButton.bottomAnchor.constraint(equalTo: popupView.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: popupView.centerXAnchor)
        ])
        
        NSLayoutConstraint.activate(constraints)
        // title, text, close
    }
    
    public static func isAppOnFirstLaunch() -> Bool {
        // Read stored version string
        let previousAppVersion = UserDefaults.standard.string(forKey: kReleaseNotesViewVersionKey)

        // Flag app as on first launch if no previous app string is found
        let isFirstLaunch = (previousAppVersion == nil) ? true : false
        
        if isFirstLaunch {
            // Store current app version if needed
            Self.storeCurrentAppVersionString();
        }
        
        return isFirstLaunch
    }
    
    public static func isAppVersionUpdated() -> Bool {
        // Read stored version string and current version string
        guard let previousAppVersion = UserDefaults.standard.string(forKey: kReleaseNotesViewVersionKey) else {
            Self.storeCurrentAppVersionString()
            return true
        }
        
        guard let currentAppVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return true }
        
        let isUpdated = (currentAppVersion != previousAppVersion)
        
        if !isUpdated {
            Self.storeCurrentAppVersionString()
        }
        
        return isUpdated
    }
    
    static func storeCurrentAppVersionString() {
        // Store current app version string in the user defaults
        guard let currentAppVersion = Bundle.main.infoDictionary?["CFBundleVersion"] else { return }
        UserDefaults.standard.setValue(currentAppVersion, forKey: kReleaseNotesViewVersionKey)
    }
    
    @objc func dismissNotes() {
        self.dismiss(animated: true, completion: nil)
    }
}
#endif

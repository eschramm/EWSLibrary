//
//  SettingsAppInfoCell.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/5/20.
//  Copyright © 2020 eware. All rights reserved.
//

import UIKit
import StoreKit


public class SettingsRatingCell : UITableViewCell, SettingsCell {
    
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

//
//  ConnectionController.swift
//  SharedSwiftCode
//
//  Created by Eric Schramm on 2/28/16.
//  Copyright © 2016 Eric Schramm. All rights reserved.
//

import UIKit

public class ConnectionController {
    
    let appName: String
    let trackerBase: String          // iqif.ignorelist.com
    let lastCheckInPrefKey: String
    let https: Bool
    
    var hideNetworkActivityIndicator = true
    var additionalTrackingDict: [String : String]?
    let session: URLSession
    
    
    public init(withAppName appName: String, trackerBase: String, lastCheckInPrefKey: String, https: Bool) {
        self.appName = appName
        self.trackerBase = trackerBase
        self.lastCheckInPrefKey = lastCheckInPrefKey
        self.https = https
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: sessionConfig)
    }
    
    public func performCheck(_ additionalTrackingDict: [String : String]?) {
        self.additionalTrackingDict = additionalTrackingDict
        
        if hideNetworkActivityIndicator == false {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        
        sendTrackingURL()
        UserDefaults.standard.set(Date(), forKey: lastCheckInPrefKey)
    }
    
    fileprivate func sendTrackingURL() {
    
        //simple tracking statistics
        
        //if supplied: additionalTrackingDict e.g.
        //["TC"   : 100,
        // "CC"   : 50,
        // "AC    : 10,
        // "TagC" : 4]  to append to tracker URL
    
        guard let infoPlistURL = Bundle.main.url(forResource: "Info", withExtension: "plist")  else { return }
        guard let infoPlist = NSDictionary(contentsOf: infoPlistURL) else { return }
        guard let appVersion = infoPlist["CFBundleShortVersionString"] as? String else { return }
        
        let deviceVersion = UIDevice.current.model
        let iOSversion = UIDevice.current.systemVersion
        let locale = Locale.current.identifier
        let deviceName = UIDevice.current.name
        
        let nameData = deviceName.data(using: String.Encoding.utf8)
        guard let encodedDeviceName = nameData?.base64EncodedString(options: .lineLength76Characters) else { return }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = https ? "https" : "http"
        urlComponents.host = trackerBase
        urlComponents.path = ""
        
        var params = [
            URLQueryItem(name: "app", value: appName),
            URLQueryItem(name: "version", value: appVersion),
            URLQueryItem(name: "device", value: deviceVersion),
            URLQueryItem(name: "iOSVersion", value: iOSversion),
            URLQueryItem(name: "locale", value: locale),
            URLQueryItem(name: "deviceUnique", value: encodedDeviceName)  ]
        
        if let dict = additionalTrackingDict {
            for (key, value) in dict {
                params.append(URLQueryItem(name: key, value: value))
            }
        }
        
        urlComponents.queryItems = params
        
        guard let trackingURL = urlComponents.url else { return }
        
        let task = session.dataTask(with: trackingURL)
        task.resume()
    }
}


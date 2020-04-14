//
//  AppDelegate.swift
//  EWSLibraryiOSTestApp
//
//  Created by Eric Schramm on 8/19/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        let mainTVC = MainTVC()
        let rootNavController = UINavigationController(rootViewController: mainTVC)
        window?.rootViewController = rootNavController
        window?.makeKeyAndVisible()
        
        return true
    }

}


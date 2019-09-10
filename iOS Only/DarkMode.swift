//
//  DarkMode.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 9/10/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit

public extension UIColor {
    class func dynamicBackground() -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemBackground
        } else {
            return UIColor.white
        }
    }
    
    class func dynamicLabel() -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.label
        } else {
            return UIColor.black
        }
    }
    
    class func dynamicLightGray() -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemGray
        } else {
            return UIColor.lightGray
        }
    }
    
    class func dynamicYellow() -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemYellow
        } else {
            return UIColor.yellow
        }
    }
}

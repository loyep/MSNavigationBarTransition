//
//  NavigationBarData.swift
//  MSNavigationBarTransition
//
//  Created by eony on 2016/1/9.
//  Copyright © 2016年 Maxwell Eony. All rights reserved.
//

import UIKit

struct NavigationBarData {
    
    static let BarTintColorArray: [NavigationBarBackgroundViewColor] = [.Cyan, .Yellow, .Green, .Orange, .lightGray, .NoValue]
    static let BackgroundImageColorArray: [NavigationBarBackgroundViewColor] = [.NoValue, .Transparent, .Cyan, .Yellow, .Green, .Orange, .lightGray, .White, .Black, .Red]
    static let BarFontColorArray: [NavigationBarBackgroundViewColor] = [.Black, .Cyan, .Yellow, .Green, .Orange, .lightGray, .Red, .White, .NoValue]
    
    
    var barTintColor = NavigationBarData.BarTintColorArray.first!
    var backgroundImageColor = NavigationBarData.BackgroundImageColorArray.first!
    var prefersHidden = false
    var prefersShadowImageHidden = false
    var barFontColor = NavigationBarData.BarFontColorArray.first!
    

}

enum NavigationBarBackgroundViewColor: String {
    case Cyan
    case Yellow
    case Green
    case Orange
    case lightGray
    case Transparent
    case Black
    case White
    case Red
    case NoValue = "No Value"
    
    var toUIColor: UIColor? {
        switch self {
        case .Cyan:
            return UIColor.cyan
        case .Yellow:
            return UIColor.yellow
        case .Green:
            return UIColor.green
        case .Orange:
            return UIColor.orange
        case .lightGray:
            return UIColor.lightGray
        case .Black:
            return UIColor.black
        case .White:
            return UIColor.white
        case .Red:
            return UIColor.red
        default:
            return nil
        }
    }
    
    var toUIImage: UIImage? {
        switch self {
        case .Transparent:
            return UIImage()
        default:
            if let color = toUIColor {
                return UIImage(color: color)
            } else {
                return nil
            }
        }
    }
}


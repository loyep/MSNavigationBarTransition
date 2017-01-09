//
//  NavigationController.swift
//  KMNavigationBarTransition
//
//  Created by eony on 2016/1/9.
//  Copyright © 2016年 Maxwell Eony. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {

    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.interactivePopGestureRecognizer?.delegate = self
    }

}

// MARK: Gesture Recognizer Delegate

extension NavigationController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        // Ignore interactive pop gesture when there is only one view controller on the navigation stack
        if viewControllers.count <= 1 {
            return false
        }
        return true
    }
    
}

//
//  QMUIKit.h
//  QMUIKit
//
//  Created by zhoonchen on 16/9/9.
//  Copyright © 2016年 QMUI Team. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for QMUIKit.
FOUNDATION_EXPORT double QMUIKitVersionNumber;

//! Project version string for QMUIKit.
FOUNDATION_EXPORT const unsigned char QMUIKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <QMUIKit/PublicHeader.h>


// 此项目同时存在静态库和动态库，所以为了修复一些找不到文件的报错，这里的import写了两份，一份给静态库一份给动态库。

/// Category
#import <QMUIKit/UIViewController+QMUI.h>
#import <QMUIKit/UINavigationController+QMUI.h>
#import <QMUIKit/UINavigationBar+Transition.h>
#import <QMUIKit/UINavigationController+NavigationBarTransition.h>

#import <QMUIKit/QMUINavigationController.h>

//
//  QMUINavigationBar+Transition.m
//  qmui
//
//  Created by bang on 11/25/16.
//  Copyright © 2016 QMUI Team. All rights reserved.
//

#import "UINavigationBar+Transition.h"
#import <objc/runtime.h>

CG_INLINE void
ReplaceMethod(Class _class, SEL _originSelector, SEL _newSelector) {
    Method oriMethod = class_getInstanceMethod(_class, _originSelector);
    Method newMethod = class_getInstanceMethod(_class, _newSelector);
    BOOL isAddedMethod = class_addMethod(_class, _originSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    if (isAddedMethod) {
        class_replaceMethod(_class, _newSelector, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, newMethod);
    }
}

@implementation UINavigationBar (Transition)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        ReplaceMethod(cls, @selector(setShadowImage:), @selector(NavigationBarTransition_setShadowImage:));
        ReplaceMethod(cls, @selector(setBarTintColor:), @selector(NavigationBarTransition_setBarTintColor:));
        ReplaceMethod(cls, @selector(setBackgroundImage:forBarMetrics:), @selector(NavigationBarTransition_setBackgroundImage:forBarMetrics:));
        
    });
}

- (void)NavigationBarTransition_setShadowImage:(UIImage *)image {
    [self NavigationBarTransition_setShadowImage:image];
    if (self.transitionNavigationBar) {
        self.transitionNavigationBar.shadowImage = image;
    }
}


- (void)NavigationBarTransition_setBarTintColor:(UIColor *)tintColor {
    [self NavigationBarTransition_setBarTintColor:tintColor];
    if (self.transitionNavigationBar) {
        self.transitionNavigationBar.barTintColor = self.barTintColor;
    }
}

- (void)NavigationBarTransition_setBackgroundImage:(UIImage *)backgroundImage forBarMetrics:(UIBarMetrics)barMetrics {
    [self NavigationBarTransition_setBackgroundImage:backgroundImage forBarMetrics:barMetrics];
    if (self.transitionNavigationBar) {
        [self.transitionNavigationBar setBackgroundImage:backgroundImage forBarMetrics:barMetrics];
    }
}

static char transitionNavigationBarKey;

- (UINavigationBar *)transitionNavigationBar {
    return objc_getAssociatedObject(self, &transitionNavigationBarKey);
}

- (void)setTransitionNavigationBar:(UINavigationBar *)transitionNavigationBar {
    objc_setAssociatedObject(self, &transitionNavigationBarKey, transitionNavigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end

//
//  UINavigationController+KMNavigationBarTransition.m
//
//  Copyright (c) 2016 Zhouqi Mo (https://github.com/MoZhouqi)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "UINavigationController+KMNavigationBarTransition.h"
#import "KMWeakObjectContainer.h"
#import <objc/runtime.h>

void KMSwizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector)
{
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    
    BOOL didAddMethod =
    class_addMethod(cls,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(cls,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

typedef void (^_FDViewControllerWillAppearInjectBlock)(UIViewController *viewController, BOOL animated);

@interface UIViewController (KMNavigationBarPrivate)

@property (nonatomic, copy) _FDViewControllerWillAppearInjectBlock fd_willAppearInjectBlock;

@property (nonatomic, assign) BOOL km_prefersNavigationBarBackgroundViewHidden;

@end

@implementation UIViewController (KMNavigationBarPrivate)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        KMSwizzleMethod([self class], @selector(viewWillAppear:), @selector(fd_viewWillAppear:));
    });
}

- (void)fd_viewWillAppear:(BOOL)animated {
    [self fd_viewWillAppear:animated];
    
    if (self.fd_willAppearInjectBlock) {
        self.fd_willAppearInjectBlock(self, animated);
    } else if (self.navigationController && self.navigationController.viewControllers.count == 1) {
        [self.navigationController setNavigationBarHidden:self.fd_prefersNavigationBarHidden animated:animated];
    }
}

- (_FDViewControllerWillAppearInjectBlock)fd_willAppearInjectBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setFd_willAppearInjectBlock:(_FDViewControllerWillAppearInjectBlock)block {
    objc_setAssociatedObject(self, @selector(fd_willAppearInjectBlock), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)km_prefersNavigationBarBackgroundViewHidden {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setKm_prefersNavigationBarBackgroundViewHidden:(BOOL)hidden {
    [[self.navigationController.navigationBar valueForKey:@"_backgroundView"]
     setHidden:hidden];
    objc_setAssociatedObject(self, @selector(km_prefersNavigationBarBackgroundViewHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UINavigationController (KMNavigationBarTransition)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        KMSwizzleMethod([self class],
                        @selector(pushViewController:animated:),
                        @selector(km_pushViewController:animated:));
        
        KMSwizzleMethod([self class],
                        @selector(popViewControllerAnimated:),
                        @selector(km_popViewControllerAnimated:));
        
        KMSwizzleMethod([self class],
                        @selector(popToViewController:animated:),
                        @selector(km_popToViewController:animated:));
        
        KMSwizzleMethod([self class],
                        @selector(popToRootViewControllerAnimated:),
                        @selector(km_popToRootViewControllerAnimated:));
        
        KMSwizzleMethod([self class],
                        @selector(setViewControllers:animated:),
                        @selector(km_setViewControllers:animated:));
    });
}

- (UIColor *)km_containerViewBackgroundColor {
    return [UIColor whiteColor];
}

- (void)km_pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    if (!disappearingViewController) {
        return [self km_pushViewController:viewController animated:animated];
    }
    
    __weak typeof(self) weakSelf = self;
    _FDViewControllerWillAppearInjectBlock block = ^(UIViewController *viewController, BOOL animated) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf setNavigationBarHidden:viewController.fd_prefersNavigationBarHidden animated:animated];
        }
    };
    
    // Setup will appear inject block to appearing view controller.
    // Setup disappearing view controller as well, because not every view controller is added into
    // stack by pushing, maybe by "-setViewControllers:".
    viewController.fd_willAppearInjectBlock = block;
    if (disappearingViewController && !disappearingViewController.fd_willAppearInjectBlock) {
        disappearingViewController.fd_willAppearInjectBlock = block;
    }
    
    if (!self.km_transitionContextToViewController || !disappearingViewController.km_transitionNavigationBar) {
        [disappearingViewController km_addTransitionNavigationBarIfNeeded];
    }
    if (animated) {
        self.km_transitionContextToViewController = viewController;
        if (disappearingViewController.km_transitionNavigationBar) {
            disappearingViewController.km_prefersNavigationBarBackgroundViewHidden = YES;
        }
    }
    return [self km_pushViewController:viewController animated:animated];
}

- (UIViewController *)km_popViewControllerAnimated:(BOOL)animated {
    if (self.viewControllers.count < 2) {
        return [self km_popViewControllerAnimated:animated];
    }
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    [disappearingViewController km_addTransitionNavigationBarIfNeeded];
    UIViewController *appearingViewController = self.viewControllers[self.viewControllers.count - 2];
    if (appearingViewController.km_transitionNavigationBar) {
        UINavigationBar *appearingNavigationBar = appearingViewController.km_transitionNavigationBar;
        self.navigationBar.barTintColor = appearingNavigationBar.barTintColor;
        [self.navigationBar setBackgroundImage:[appearingNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = appearingNavigationBar.shadowImage;
    }
    if (animated) {
        disappearingViewController.km_prefersNavigationBarBackgroundViewHidden = YES;
    }
    return [self km_popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)km_popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (![self.viewControllers containsObject:viewController] || self.viewControllers.count < 2) {
        return [self km_popToViewController:viewController animated:animated];
    }
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    [disappearingViewController km_addTransitionNavigationBarIfNeeded];
    if (viewController.km_transitionNavigationBar) {
        UINavigationBar *appearingNavigationBar = viewController.km_transitionNavigationBar;
        self.navigationBar.barTintColor = appearingNavigationBar.barTintColor;
        [self.navigationBar setBackgroundImage:[appearingNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = appearingNavigationBar.shadowImage;
    }
    if (animated) {
        disappearingViewController.km_prefersNavigationBarBackgroundViewHidden = YES;
    }
    return [self km_popToViewController:viewController animated:animated];
}

- (NSArray<UIViewController *> *)km_popToRootViewControllerAnimated:(BOOL)animated {
    if (self.viewControllers.count < 2) {
        return [self km_popToRootViewControllerAnimated:animated];
    }
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    [disappearingViewController km_addTransitionNavigationBarIfNeeded];
    UIViewController *rootViewController = self.viewControllers.firstObject;
    if (rootViewController.km_transitionNavigationBar) {
        UINavigationBar *appearingNavigationBar = rootViewController.km_transitionNavigationBar;
        self.navigationBar.barTintColor = appearingNavigationBar.barTintColor;
        [self.navigationBar setBackgroundImage:[appearingNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = appearingNavigationBar.shadowImage;
    }
    if (animated) {
        disappearingViewController.km_prefersNavigationBarBackgroundViewHidden = YES;
    }
    return [self km_popToRootViewControllerAnimated:animated];
}

- (void)km_setViewControllers:(NSArray<UIViewController *> *)viewControllers animated:(BOOL)animated {
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    if (animated && disappearingViewController && ![disappearingViewController isEqual:viewControllers.lastObject]) {
        [disappearingViewController km_addTransitionNavigationBarIfNeeded];
        if (disappearingViewController.km_transitionNavigationBar) {
            disappearingViewController.km_prefersNavigationBarBackgroundViewHidden = YES;
        }
    }
    return [self km_setViewControllers:viewControllers animated:animated];
}

- (UIViewController *)km_transitionContextToViewController {
    return km_objc_getAssociatedWeakObject(self, _cmd);
}

- (void)setKm_transitionContextToViewController:(UIViewController *)viewController {
    km_objc_setAssociatedWeakObject(self, @selector(km_transitionContextToViewController), viewController);
}

@end


@implementation UIViewController (KMNavigationBarTransition)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        KMSwizzleMethod([self class],
                        @selector(viewWillLayoutSubviews),
                        @selector(km_viewWillLayoutSubviews));
        
        KMSwizzleMethod([self class],
                        @selector(viewDidAppear:),
                        @selector(km_viewDidAppear:));
    });
}

- (void)km_viewDidAppear:(BOOL)animated {
    if (self.km_transitionNavigationBar) {
        self.navigationController.navigationBar.barTintColor = self.km_transitionNavigationBar.barTintColor;
        [self.navigationController.navigationBar setBackgroundImage:[self.km_transitionNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setShadowImage:self.km_transitionNavigationBar.shadowImage];
        
        UIViewController *transitionViewController = self.navigationController.km_transitionContextToViewController;
        if (!transitionViewController || [transitionViewController isEqual:self]) {
            [self.km_transitionNavigationBar removeFromSuperview];
            self.km_transitionNavigationBar = nil;
            self.navigationController.km_transitionContextToViewController = nil;
        }
    }
    self.km_prefersNavigationBarBackgroundViewHidden = NO;
    [self km_viewDidAppear:animated];
}

- (void)km_viewWillLayoutSubviews {
    id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
    UIViewController *fromViewController = [tc viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [tc viewControllerForKey:UITransitionContextToViewControllerKey];
    
    if ([self isEqual:self.navigationController.viewControllers.lastObject] && [toViewController isEqual:self]) {
        if (self.navigationController.navigationBar.translucent) {
            [tc containerView].backgroundColor = [self.navigationController km_containerViewBackgroundColor];
        }
        fromViewController.view.clipsToBounds = NO;
        toViewController.view.clipsToBounds = NO;
        if (!self.km_transitionNavigationBar) {
            [self km_addTransitionNavigationBarIfNeeded];
            
            self.km_prefersNavigationBarBackgroundViewHidden = YES;
        }
        [self km_resizeTransitionNavigationBarFrame];
    }
    if (self.km_transitionNavigationBar) {
        [self.view bringSubviewToFront:self.km_transitionNavigationBar];
    }
    [self km_viewWillLayoutSubviews];
}

- (void)km_resizeTransitionNavigationBarFrame {
    if (!self.view.window) {
        return;
    }
    UIView *backgroundView = [self.navigationController.navigationBar valueForKey:@"_backgroundView"];
    CGRect rect = [backgroundView.superview convertRect:backgroundView.frame toView:self.view];
    self.km_transitionNavigationBar.frame = rect;
}

- (void)km_addTransitionNavigationBarIfNeeded {
    if (!self.isViewLoaded || !self.view.window) {
        return;
    }
    if (!self.navigationController.navigationBar) {
        return;
    }
    [self km_adjustScrollViewContentOffsetIfNeeded];
    UINavigationBar *bar = [[UINavigationBar alloc] init];
    bar.barStyle = self.navigationController.navigationBar.barStyle;
    if (bar.translucent != self.navigationController.navigationBar.translucent) {
        bar.translucent = self.navigationController.navigationBar.translucent;
    }
    bar.barTintColor = self.navigationController.navigationBar.barTintColor;
    [bar setBackgroundImage:[self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
    bar.shadowImage = self.navigationController.navigationBar.shadowImage;
    [self.km_transitionNavigationBar removeFromSuperview];
    self.km_transitionNavigationBar = bar;
    [self km_resizeTransitionNavigationBarFrame];
    if (!self.navigationController.navigationBarHidden && !self.navigationController.navigationBar.hidden) {
        [self.view addSubview:self.km_transitionNavigationBar];
    }
}

- (void)km_adjustScrollViewContentOffsetIfNeeded {
    if ([self.view isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)self.view;
        const CGFloat topContentOffsetY = -scrollView.contentInset.top;
        const CGFloat bottomContentOffsetY = scrollView.contentSize.height - (CGRectGetHeight(scrollView.bounds) - scrollView.contentInset.bottom);
        
        CGPoint adjustedContentOffset = scrollView.contentOffset;
        if (adjustedContentOffset.y > bottomContentOffsetY) {
            adjustedContentOffset.y = bottomContentOffsetY;
        }
        if (adjustedContentOffset.y < topContentOffsetY) {
            adjustedContentOffset.y = topContentOffsetY;
        }
        [scrollView setContentOffset:adjustedContentOffset animated:NO];
    }
}

- (UINavigationBar *)km_transitionNavigationBar {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setKm_transitionNavigationBar:(UINavigationBar *)navigationBar {
    objc_setAssociatedObject(self, @selector(km_transitionNavigationBar), navigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)fd_prefersNavigationBarHidden
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_prefersNavigationBarHidden:(BOOL)hidden
{
    objc_setAssociatedObject(self, @selector(fd_prefersNavigationBarHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

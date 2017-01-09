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
#import <objc/runtime.h>

void MSSwizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
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

@interface _MSFullscreenPopGestureRecognizerDelegate : UIPercentDrivenInteractiveTransition <UIGestureRecognizerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) UINavigationController *navigationController;

@end

@implementation _MSFullscreenPopGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    // Ignore when no view controller is pushed into the navigation stack.
    if (self.navigationController.viewControllers.count <= 1) {
        return false;
    }
    
    // Disable when the active view controller doesn't allow interactive pop.
    UIViewController *topViewController = self.navigationController.viewControllers.lastObject;
    if (topViewController.ms_interactivePopDisabled) {
        return false;
    }
    
    // Ignore pan gesture when the navigation controller is currently in transition.
    if ([[self.navigationController valueForKey:@"_isTransitioning"] boolValue]) {
        return false;
    }
    
    // Prevent calling the handler when the gesture begins in an opposite direction.
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    if (translation.x <= 0) {
        return false;
    }
    
    return true;
}

@end

//@interface UINavigationBar (MSNavigationBarPrivate)
//
//@end

typedef void (^_MSViewControllerWillAppearInjectBlock)(UIViewController *viewController, BOOL animated);

@interface UIViewController (MSNavigationBarPrivate)

@property (nonatomic, copy) _MSViewControllerWillAppearInjectBlock ms_willAppearInjectBlock;

@property (nonatomic, assign) BOOL ms_prefersNavigationBarBackgroundViewHidden;

@property (nonatomic, strong) UINavigationBar *ms_transitionNavigationBar;

- (void)ms_addTransitionNavigationBarIfNeeded;

- (BOOL)ms_isEqual:(UIViewController *)object;

@end

@implementation UIViewController (MSNavigationBarPrivate)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MSSwizzleMethod([self class],
                        @selector(viewWillAppear:),
                        @selector(ms_viewWillAppear:));
        
        MSSwizzleMethod([self class],
                        @selector(viewWillLayoutSubviews),
                        @selector(ms_viewWillLayoutSubviews));
        
        MSSwizzleMethod([self class],
                        @selector(viewDidAppear:),
                        @selector(ms_viewDidAppear:));
    });
}

- (BOOL)ms_isEqual:(UIViewController *)object {
    return false;
    if (self == object) {
        return true;
    }
    
    if (object.ms_transitionNavigationBar == self.ms_transitionNavigationBar) {
        return true;
    }
    
    if (self.ms_transitionNavigationBar && object.ms_transitionNavigationBar) {
        UIImage *appearImage = [self.ms_transitionNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault];
        UIImage *disappearImage = [object.ms_transitionNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault];
        NSData *appearData = UIImagePNGRepresentation(appearImage);
        NSData *disappearData = UIImagePNGRepresentation(disappearImage);
        if ((appearData && disappearData) || [appearData isEqualToData:disappearData]) {
            return true;
        } else {
            return false;
        }
    }
    return false;
}

- (BOOL)ms_prefersNavigationBarBackgroundViewHidden {
    return [[self ms_navigationBarBackgroundView] isHidden];
}

- (void)setMs_prefersNavigationBarBackgroundViewHidden:(BOOL)hidden {
    [[self ms_navigationBarBackgroundView] setHidden:hidden];
}

- (void)ms_viewWillAppear:(BOOL)animated {
    [self ms_viewWillAppear:animated];
    
    if (self.ms_willAppearInjectBlock) {
        self.ms_willAppearInjectBlock(self, animated);
    } else if (self.navigationController && self.navigationController.viewControllers.count == 1) {
        [self.navigationController setNavigationBarHidden:self.ms_prefersNavigationBarHidden animated:animated];
    }
}

- (_MSViewControllerWillAppearInjectBlock)ms_willAppearInjectBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setMs_willAppearInjectBlock:(_MSViewControllerWillAppearInjectBlock)block {
    objc_setAssociatedObject(self, @selector(ms_willAppearInjectBlock), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)ms_viewDidAppear:(BOOL)animated {
    if (self.ms_transitionNavigationBar) {
        self.navigationController.navigationBar.barTintColor = self.ms_transitionNavigationBar.barTintColor;
        [self.navigationController.navigationBar setBackgroundImage:[self.ms_transitionNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setShadowImage:self.ms_transitionNavigationBar.shadowImage];
        
        UIViewController *transitionViewController = self.navigationController.ms_transitionContextToViewController;
        if (!transitionViewController || [transitionViewController isEqual:self]) {
            [self.ms_transitionNavigationBar removeFromSuperview];
            self.ms_transitionNavigationBar = nil;
            self.navigationController.ms_transitionContextToViewController = nil;
        }
    }
    self.ms_prefersNavigationBarBackgroundViewHidden = NO;
    [self ms_viewDidAppear:animated];
}

- (void)ms_viewWillLayoutSubviews {
    id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
    UIViewController *fromViewController = [tc viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [tc viewControllerForKey:UITransitionContextToViewControllerKey];
    
    if ([self isEqual:self.navigationController.viewControllers.lastObject] && [toViewController isEqual:self]) {
        if (self.navigationController.navigationBar.translucent) {
            [tc containerView].backgroundColor = [self.navigationController ms_containerViewBackgroundColor];
        }
        fromViewController.view.clipsToBounds = NO;
        toViewController.view.clipsToBounds = NO;
        if (!self.ms_transitionNavigationBar) {
            [self ms_addTransitionNavigationBarIfNeeded];
            
            self.ms_prefersNavigationBarBackgroundViewHidden = true;
        }
        [self ms_resizeTransitionNavigationBarFrame];
    }
    if (self.ms_transitionNavigationBar) {
        [self.view bringSubviewToFront:self.ms_transitionNavigationBar];
    }
    [self ms_viewWillLayoutSubviews];
}

- (void)ms_resizeTransitionNavigationBarFrame {
    if (!self.view.window) {
        return;
    }
    
    UIView *backgroundView = [self ms_navigationBarBackgroundView];
    CGRect rect = [backgroundView.superview convertRect:backgroundView.frame toView:self.view];
    self.ms_transitionNavigationBar.frame = rect;
}

- (UIView *)ms_navigationBarBackgroundView {
    return (UIView *)[self.navigationController.navigationBar valueForKey:@"_backgroundView"];
}

- (void)ms_addTransitionNavigationBarIfNeeded {
    
    if (!self.navigationController.ms_viewControllerBasedNavigationBarAppearanceEnabled) {
        return;
    }
    
    if (!self.isViewLoaded || !self.view.window) {
        return;
    }
    
    if (!self.navigationController.navigationBar) {
        return;
    }
    
    [self ms_adjustScrollViewContentOffsetIfNeeded];
    UINavigationBar *bar = [[UINavigationBar alloc] init];
    bar.barStyle = self.navigationController.navigationBar.barStyle;
    if (bar.translucent != self.navigationController.navigationBar.translucent) {
        bar.translucent = self.navigationController.navigationBar.translucent;
    }
    
    bar.barTintColor = self.navigationController.navigationBar.barTintColor;
    [bar setBackgroundImage:[self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
    bar.shadowImage = self.navigationController.navigationBar.shadowImage;
    
    [self.ms_transitionNavigationBar removeFromSuperview];
    self.ms_transitionNavigationBar = bar;
    
    [self ms_resizeTransitionNavigationBarFrame];
    
    if (!self.navigationController.navigationBarHidden && !self.navigationController.navigationBar.hidden) {
        [self.view addSubview:self.ms_transitionNavigationBar];
    }
}

- (void)ms_adjustScrollViewContentOffsetIfNeeded {
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
        [scrollView setContentOffset:adjustedContentOffset animated:false];
    }
}

- (UINavigationBar *)ms_transitionNavigationBar {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setMs_transitionNavigationBar:(UINavigationBar *)navigationBar {
    objc_setAssociatedObject(self, @selector(ms_transitionNavigationBar), navigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UINavigationController (MSNavigationBarTransition)

- (BOOL)ms_viewControllerBasedNavigationBarAppearanceEnabled {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) {
        return number.boolValue;
    }
    self.ms_viewControllerBasedNavigationBarAppearanceEnabled = true;
    return true;
}

- (UIPanGestureRecognizer *)ms_fullscreenPopGestureRecognizer {
    UIPanGestureRecognizer *panGestureRecognizer = objc_getAssociatedObject(self, _cmd);
    
    if (!panGestureRecognizer) {
        panGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
        panGestureRecognizer.maximumNumberOfTouches = 1;
        
        objc_setAssociatedObject(self, _cmd, panGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return panGestureRecognizer;
}

- (void)setMs_viewControllerBasedNavigationBarAppearanceEnabled:(BOOL)enabled {
    SEL key = @selector(ms_viewControllerBasedNavigationBarAppearanceEnabled);
    objc_setAssociatedObject(self, key, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MSSwizzleMethod([self class],
                        @selector(pushViewController:animated:),
                        @selector(ms_pushViewController:animated:));
        
        MSSwizzleMethod([self class],
                        @selector(popViewControllerAnimated:),
                        @selector(ms_popViewControllerAnimated:));
        
        MSSwizzleMethod([self class],
                        @selector(popToViewController:animated:),
                        @selector(ms_popToViewController:animated:));
        
        MSSwizzleMethod([self class],
                        @selector(popToRootViewControllerAnimated:),
                        @selector(ms_popToRootViewControllerAnimated:));
        
        MSSwizzleMethod([self class],
                        @selector(setViewControllers:animated:),
                        @selector(ms_setViewControllers:animated:));
    });
}

- (_MSFullscreenPopGestureRecognizerDelegate *)ms_popGestureRecognizerDelegate {
    _MSFullscreenPopGestureRecognizerDelegate *delegate = objc_getAssociatedObject(self, _cmd);
    
    if (!delegate) {
        delegate = [[_MSFullscreenPopGestureRecognizerDelegate alloc] init];
        delegate.navigationController = self;
        self.delegate = delegate;
        
        objc_setAssociatedObject(self, _cmd, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return delegate;
}


- (void)ms_pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.ms_fullscreenPopGestureRecognizer]) {
        
        // Add our own gesture recognizer to where the onboard screen edge pan gesture recognizer is attached to.
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.ms_fullscreenPopGestureRecognizer];
        
        // Forward the gesture events to the private handler of the onboard gesture recognizer.
        NSArray *internalTargets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id internalTarget = [internalTargets.firstObject valueForKey:@"target"];
        SEL internalAction = NSSelectorFromString(@"handleNavigationTransition:");
        self.ms_fullscreenPopGestureRecognizer.delegate = self.ms_popGestureRecognizerDelegate;
        [self.ms_fullscreenPopGestureRecognizer addTarget:internalTarget action:internalAction];
        
        // Disable the onboard gesture recognizer.
        self.interactivePopGestureRecognizer.enabled = false;
    }
    
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    if (!disappearingViewController) {
        return [self ms_pushViewController:viewController animated:animated];
    }
    
    __weak typeof(self) weakSelf = self;
    __weak typeof(disappearingViewController) weakDisappear = disappearingViewController;
    _MSViewControllerWillAppearInjectBlock block = ^(UIViewController *viewController, BOOL animated) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf setNavigationBarHidden:viewController.ms_prefersNavigationBarHidden animated:animated];
//            [[viewController ms_navigationBarBackgroundView] setHidden:viewController.ms_prefersNavigationBarHidden];
            __strong typeof(weakDisappear) strongDisappear = weakDisappear;
            if ([viewController ms_isEqual:strongDisappear]) {
                [[viewController ms_navigationBarBackgroundView] setHidden:viewController.ms_prefersNavigationBarHidden];
            }
        }
    };
    
    // Setup will appear inject block to appearing view controller.
    // Setup disappearing view controller as well, because not every view controller is added into
    // stack by pushing, maybe by "-setViewControllers:".
    viewController.ms_willAppearInjectBlock = block;
    if (disappearingViewController && !disappearingViewController.ms_willAppearInjectBlock) {
        disappearingViewController.ms_willAppearInjectBlock = block;
    }
    
    if (!self.ms_transitionContextToViewController || !disappearingViewController.ms_transitionNavigationBar) {
        [disappearingViewController ms_addTransitionNavigationBarIfNeeded];
    }
    
    if (animated) {
        self.ms_transitionContextToViewController = viewController;
        if (disappearingViewController.ms_transitionNavigationBar) {
            disappearingViewController.ms_prefersNavigationBarBackgroundViewHidden = true;
        }
    }
    return [self ms_pushViewController:viewController animated:animated];
}

- (UIViewController *)ms_popViewControllerAnimated:(BOOL)animated {
    if (self.viewControllers.count < 2) {
        return [self ms_popViewControllerAnimated:animated];
    }
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    [disappearingViewController ms_addTransitionNavigationBarIfNeeded];
    UIViewController *appearingViewController = self.viewControllers[self.viewControllers.count - 2];
    if (appearingViewController.ms_transitionNavigationBar) {
        UINavigationBar *appearingNavigationBar = appearingViewController.ms_transitionNavigationBar;
        self.navigationBar.barTintColor = appearingNavigationBar.barTintColor;
        [self.navigationBar setBackgroundImage:[appearingNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = appearingNavigationBar.shadowImage;
    }
    
    if (animated) {
        disappearingViewController.ms_prefersNavigationBarBackgroundViewHidden = true;
    }
    
    return [self ms_popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)ms_popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (![self.viewControllers containsObject:viewController] || self.viewControllers.count < 2) {
        return [self ms_popToViewController:viewController animated:animated];
    }
    
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    [disappearingViewController ms_addTransitionNavigationBarIfNeeded];
    
    if (viewController.ms_transitionNavigationBar) {
        UINavigationBar *appearingNavigationBar = viewController.ms_transitionNavigationBar;
        self.navigationBar.barTintColor = appearingNavigationBar.barTintColor;
        [self.navigationBar setBackgroundImage:[appearingNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = appearingNavigationBar.shadowImage;
    }
    
    if (animated) {
        disappearingViewController.ms_prefersNavigationBarBackgroundViewHidden = true;
    }
    
    return [self ms_popToViewController:viewController animated:animated];
}

- (NSArray<UIViewController *> *)ms_popToRootViewControllerAnimated:(BOOL)animated {
    if (self.viewControllers.count < 2) {
        return [self ms_popToRootViewControllerAnimated:animated];
    }
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    [disappearingViewController ms_addTransitionNavigationBarIfNeeded];
    UIViewController *rootViewController = self.viewControllers.firstObject;
    if (rootViewController.ms_transitionNavigationBar) {
        UINavigationBar *appearingNavigationBar = rootViewController.ms_transitionNavigationBar;
        self.navigationBar.barTintColor = appearingNavigationBar.barTintColor;
        [self.navigationBar setBackgroundImage:[appearingNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = appearingNavigationBar.shadowImage;
    }
    if (animated) {
        disappearingViewController.ms_prefersNavigationBarBackgroundViewHidden = true;
    }
    
    return [self ms_popToRootViewControllerAnimated:animated];
}

- (void)ms_setViewControllers:(NSArray<UIViewController *> *)viewControllers animated:(BOOL)animated {
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    if (animated && disappearingViewController && ![disappearingViewController isEqual:viewControllers.lastObject]) {
        [disappearingViewController ms_addTransitionNavigationBarIfNeeded];
        if (disappearingViewController.ms_transitionNavigationBar) {
            disappearingViewController.ms_prefersNavigationBarBackgroundViewHidden = true;
        }
    }
    return [self ms_setViewControllers:viewControllers animated:animated];
}

- (UIViewController *)ms_transitionContextToViewController {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setMs_transitionContextToViewController:(UIViewController *)viewController {
    objc_setAssociatedObject(self, @selector(ms_transitionContextToViewController), viewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


@implementation UIViewController (MSNavigationBarTransition)

- (void)setMs_interactivePopDisabled:(BOOL)disabled {
    objc_setAssociatedObject(self, @selector(ms_interactivePopDisabled), @(disabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)ms_interactivePopDisabled {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

// By default this is white, it is related to issue with transparent navigationBar
- (UIColor *)ms_containerViewBackgroundColor {
    return [UIColor whiteColor];
}

- (BOOL)ms_prefersNavigationBarHidden {
    NSNumber *hidden = objc_getAssociatedObject(self, _cmd);
    if (hidden) {
        return [hidden boolValue];
    }
    self.ms_prefersNavigationBarHidden = false;
    return false;
}

- (void)setMs_prefersNavigationBarHidden:(BOOL)hidden {
    self.ms_prefersNavigationBarBackgroundViewHidden = hidden;
    objc_setAssociatedObject(self, @selector(ms_prefersNavigationBarHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

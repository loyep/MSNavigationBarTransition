//
//  UINavigationController+NavigationBarTransition.m
//  qmui
//
//  Created by QQMail on 16/2/22.
//  Copyright © 2016年 QMUI Team. All rights reserved.
//

#import "UINavigationController+NavigationBarTransition.h"
#import "QMUINavigationController.h"
#import <objc/runtime.h>
//#import "QMUICommonDefines.h"
//#import "QMUIConfiguration.h"
//#import "UINavigationController+QMUI.h"
//#import "UIImage+QMUI.h"
//#import "UIViewController+QMUI.h"
#import "UINavigationBar+Transition.h"

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

/**
 *  基于指定的倍数，对传进来的 floatValue 进行像素取整。若指定倍数为0，则表示以当前设备的屏幕倍数为准。
 *
 *  例如传进来 “2.1”，在 2x 倍数下会返回 2.5（0.5pt 对应 1px），在 3x 倍数下会返回 2.333（0.333pt 对应 1px）。
 */
CG_INLINE float
flatfSpecificScale(float floatValue, float scale) {
    scale = scale == 0 ? ([[UIScreen mainScreen] scale]) : scale;
    CGFloat flattedValue = ceilf(floatValue * scale) / scale;
    return flattedValue;
}

CG_INLINE void
fd_ReplaceMethod(Class _class, SEL _originSelector, SEL _newSelector) {
    Method oriMethod = class_getInstanceMethod(_class, _originSelector);
    Method newMethod = class_getInstanceMethod(_class, _newSelector);
    BOOL isAddedMethod = class_addMethod(_class, _originSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    if (isAddedMethod) {
        class_replaceMethod(_class, _newSelector, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, newMethod);
    }
}

/**
 *  基于当前设备的屏幕倍数，对传进来的 floatValue 进行像素取整。
 *
 *  注意如果在 Core Graphic 绘图里使用时，要注意当前画布的倍数是否和设备屏幕倍数一致，若不一致，不可使用 flatf() 函数。
 */
CG_INLINE float
flatf(float floatValue) {
    return flatfSpecificScale(floatValue, 0);
}
// 将一个CGSize像素对齐
CG_INLINE CGSize
CGSizeFlatted(CGSize size) {
    return CGSizeMake(flatf(size.width), flatf(size.height));
}

@interface _FDFullscreenPopGestureRecognizerDelegate : UIPercentDrivenInteractiveTransition <UIGestureRecognizerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) UINavigationController *navigationController;

@end

@implementation _FDFullscreenPopGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    // Ignore when no view controller is pushed into the navigation stack.
    if (self.navigationController.viewControllers.count <= 1) {
        return NO;
    }
    
    // Disable when the active view controller doesn't allow interactive pop.
    UIViewController *topViewController = self.navigationController.viewControllers.lastObject;
    if (topViewController.fd_interactivePopDisabled) {
        return NO;
    }
    
    // Ignore pan gesture when the navigation controller is currently in transition.
    if ([[self.navigationController valueForKey:@"_isTransitioning"] boolValue]) {
        return NO;
    }
    
    // Prevent calling the handler when the gesture begins in an opposite direction.
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    if (translation.x <= 0) {
        return NO;
    }
    
    return YES;
}

@end

typedef void (^_FDViewControllerWillAppearInjectBlock)(UIViewController *viewController, BOOL animated);
/**
 *  为了响应<b>NavigationBarTransition</b>分类的功能，UIViewController需要做一些相应的支持。
 *  @see UINavigationController+NavigationBarTransition.h
 */
@interface UIViewController (NavigationBarTransitionPrivate)

@property (nonatomic, copy) _FDViewControllerWillAppearInjectBlock fd_willAppearInjectBlock;

/// 用来模仿真的navBar的，在转场过程中存在的一条假navBar
@property (nonatomic, strong) UINavigationBar *transitionNavigationBar;

/// 是否要把真的navBar隐藏
@property (nonatomic, assign) BOOL prefersNavigationBarBackgroundViewHidden;

/// 添加假的navBar
- (void)addTransitionNavigationBarIfNeeded;

/// .m文件里自己赋值和使用。因为有些特殊情况下viewDidAppear之后，有可能还会调用到viewWillLayoutSubviews，导致原始的navBar隐藏，所以用这个属性做个保护。
@property (nonatomic, assign) BOOL lockTransitionNavigationBar;

@end

@implementation UIViewController (NavigationBarTransition)

- (BOOL)fd_interactivePopDisabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_interactivePopDisabled:(BOOL)disabled
{
    objc_setAssociatedObject(self, @selector(fd_interactivePopDisabled), @(disabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

@implementation UIViewController (NavigationBarTransitionPrivate)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        fd_ReplaceMethod(cls, @selector(viewWillLayoutSubviews), @selector(NavigationBarTransition_viewWillLayoutSubviews));
        fd_ReplaceMethod(cls, @selector(viewDidAppear:), @selector(NavigationBarTransition_viewDidAppear:));
        fd_ReplaceMethod(cls, @selector(viewDidDisappear:), @selector(NavigationBarTransition_viewDidDisappear:));
        fd_ReplaceMethod(cls, @selector(viewWillAppear:), @selector(NavigationBarTransition_viewWillAppear:));
    });
}

- (void)NavigationBarTransition_viewWillAppear:(BOOL)animated {
    
    [self NavigationBarTransition_viewWillAppear:animated];
    
    if (self.fd_willAppearInjectBlock) {
        self.fd_willAppearInjectBlock(self, animated);
    }
}

- (_FDViewControllerWillAppearInjectBlock)fd_willAppearInjectBlock
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setFd_willAppearInjectBlock:(_FDViewControllerWillAppearInjectBlock)block
{
    objc_setAssociatedObject(self, @selector(fd_willAppearInjectBlock), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)NavigationBarTransition_viewDidAppear:(BOOL)animated {
    if (self.transitionNavigationBar) {
        // 回到界面的时候，把假的navBar去掉并且还原老的navBar
        self.navigationController.navigationBar.barTintColor = self.transitionNavigationBar.barTintColor;
        [self.navigationController.navigationBar setBackgroundImage:[self.transitionNavigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setShadowImage:self.transitionNavigationBar.shadowImage];
        [self removeTransitionNavigationBar];
    }
    // 老的navBar显示出来
    self.prefersNavigationBarBackgroundViewHidden = NO;
    self.lockTransitionNavigationBar = YES;
    [self NavigationBarTransition_viewDidAppear:animated];
}

- (void)NavigationBarTransition_viewDidDisappear:(BOOL)animated {
    self.lockTransitionNavigationBar = NO;
    [self NavigationBarTransition_viewDidDisappear:animated];
    if (self.transitionNavigationBar) {
        // 对于被pop导致当前viewController走到viewDidDisappear:的情况，removeTransitionNavigationBar里是无法正确把navigationBar上的observe移除的，因为此时获取不到self.navigationController，所以removeObserve提前到viewWillDisappear里
        [self removeTransitionNavigationBar];
    }
}

- (void)NavigationBarTransition_viewWillLayoutSubviews {
    
    id<UIViewControllerTransitionCoordinator> transitionCoordinator = self.transitionCoordinator;
    UIViewController *fromViewController = [transitionCoordinator viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionCoordinator viewControllerForKey:UITransitionContextToViewControllerKey];
    
    BOOL isCurrentToViewController = (self == self.navigationController.viewControllers.lastObject && self == toViewController);
    
    if (isCurrentToViewController && !self.lockTransitionNavigationBar) {
        if (!self.transitionNavigationBar) {
            [self addTransitionNavigationBarIfNeeded];
            toViewController.navigationController.navigationBar.transitionNavigationBar = toViewController.transitionNavigationBar;
            self.prefersNavigationBarBackgroundViewHidden = YES;
        }
        // 设置假的 navBar 的frame
        [self resizeTransitionNavigationBarFrame];
    }
    
    [self NavigationBarTransition_viewWillLayoutSubviews];
}

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size cornerRadius:(CGFloat)cornerRadius {
    size = CGSizeFlatted(size);
    if (size.width < 0 || size.height < 0) {
        return nil;
    }
    
    UIImage *resultImage = nil;
    color = color ? color : [UIColor whiteColor];
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    
    if (cornerRadius > 0) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:cornerRadius];
        [path addClip];
        [path fill];
    } else {
        CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    }
    
    resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultImage;
}

- (void)addTransitionNavigationBarIfNeeded {
    if (!self.view.window || !self.navigationController.navigationBar) {
        return;
    }
    
    UINavigationBar *originBar = self.navigationController.navigationBar;
    UINavigationBar *customBar = [[UINavigationBar alloc] init];
    if (customBar.barStyle != originBar.barStyle) {
        customBar.barStyle = originBar.barStyle;
    }
    if (customBar.translucent != originBar.translucent) {
        customBar.translucent = originBar.translucent;
    }
    if (![customBar.barTintColor isEqual:originBar.barTintColor]) {
        customBar.barTintColor = originBar.barTintColor;
    }
    UIImage *backgroundImage = [originBar backgroundImageForBarMetrics:UIBarMetricsDefault];
    if (CGSizeEqualToSize(backgroundImage.size, CGSizeZero)) {
        // 保护一下那种没有图片的 UIImage 例如：[UIImage new]，如果没有保护则会出现系统默认的navBar样式，很奇怪。
        // navController 设置自己的 navBar 为 [UIImage new] 却没事
        backgroundImage = [[self class] imageWithColor:[UIColor clearColor]];
    }
    [customBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    [customBar setShadowImage:originBar.shadowImage];
    self.transitionNavigationBar = customBar;
    [self resizeTransitionNavigationBarFrame];
    if (!self.navigationController.navigationBarHidden) {
        [self.view addSubview:self.transitionNavigationBar];
    }
}

- (void)removeTransitionNavigationBar {
    if (!self.transitionNavigationBar) {
        return;
    }
    [self.transitionNavigationBar removeFromSuperview];
    self.transitionNavigationBar = nil;
}

- (void)resizeTransitionNavigationBarFrame {
    if (!self.view.window) {
        return;
    }
    UIView *backgroundView = [self.navigationController.navigationBar valueForKey:@"_backgroundView"];
    CGRect rect = [backgroundView.superview convertRect:backgroundView.frame toView:self.view];
    self.transitionNavigationBar.frame = rect;
}

// 该 viewController 是否实现自定义 navBar 动画的协议

//- (BOOL)respondCustomNavigationBarTransitionWhenPushAppearing {
//    BOOL respondPushAppearing = NO;
//    if ([self qmui_respondQMUINavigationControllerDelegate]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        if ([vc respondsToSelector:@selector(shouldCustomNavigationBarTransitionWhenPushAppearing)]) {
//            respondPushAppearing = YES;
//        }
//    }
//    return respondPushAppearing;
//}
//
//- (BOOL)respondCustomNavigationBarTransitionWhenPushDisappearing {
//    BOOL respondPushDisappearing = NO;
//    if ([self qmui_respondQMUINavigationControllerDelegate]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        if ([vc respondsToSelector:@selector(shouldCustomNavigationBarTransitionWhenPushDisappearing)]) {
//            respondPushDisappearing = YES;
//        }
//    }
//    return respondPushDisappearing;
//}
//
//- (BOOL)respondCustomNavigationBarTransitionWhenPopAppearing {
//    BOOL respondPopAppearing = NO;
//    if ([self qmui_respondQMUINavigationControllerDelegate]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        if ([vc respondsToSelector:@selector(shouldCustomNavigationBarTransitionWhenPopAppearing)]) {
//            respondPopAppearing = YES;
//        }
//    }
//    return respondPopAppearing;
//}
//
//- (BOOL)respondCustomNavigationBarTransitionWhenPopDisappearing {
//    BOOL respondPopDisappearing = NO;
//    if ([self qmui_respondQMUINavigationControllerDelegate]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        if ([vc respondsToSelector:@selector(shouldCustomNavigationBarTransitionWhenPopDisappearing)]) {
//            respondPopDisappearing = YES;
//        }
//    }
//    return respondPopDisappearing;
//}
//
//// 该 viewController 实现自定义 navBar 动画的协议的返回值
//
//- (BOOL)canCustomNavigationBarTransitionWhenPushAppearing {
//    return YES;
//    if ([self respondCustomNavigationBarTransitionWhenPushAppearing]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        return  [vc shouldCustomNavigationBarTransitionWhenPushAppearing];
//    }
//    return NO;
//}
//
//- (BOOL)canCustomNavigationBarTransitionWhenPushDisappearing {
//    return YES;
//    if ([self respondCustomNavigationBarTransitionWhenPushDisappearing]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        return  [vc shouldCustomNavigationBarTransitionWhenPushDisappearing];
//    }
//    return NO;
//}
//
//- (BOOL)canCustomNavigationBarTransitionWhenPopAppearing {
//    return YES;
//    if ([self respondCustomNavigationBarTransitionWhenPopAppearing]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        return  [vc shouldCustomNavigationBarTransitionWhenPopAppearing];
//    }
//    return NO;
//}
//
//- (BOOL)canCustomNavigationBarTransitionWhenPopDisappearing {
//    return YES;
//    if ([self respondCustomNavigationBarTransitionWhenPopDisappearing]) {
//        UIViewController<QMUINavigationControllerDelegate> *vc = (UIViewController<QMUINavigationControllerDelegate> *)self;
//        return  [vc shouldCustomNavigationBarTransitionWhenPopDisappearing];
//    }
//    return NO;
//}

static char lockTransitionNavigationBarKey;

- (BOOL)lockTransitionNavigationBar {
    return [objc_getAssociatedObject(self, &lockTransitionNavigationBarKey) boolValue];
}

- (void)setLockTransitionNavigationBar:(BOOL)lockTransitionNavigationBar {
    objc_setAssociatedObject(self, &lockTransitionNavigationBarKey, [[NSNumber alloc] initWithBool:lockTransitionNavigationBar], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char transitionNavigationBarKey;

- (UINavigationBar *)transitionNavigationBar {
    return objc_getAssociatedObject(self, &transitionNavigationBarKey);
}

- (void)setTransitionNavigationBar:(UINavigationBar *)transitionNavigationBar {
    objc_setAssociatedObject(self, &transitionNavigationBarKey, transitionNavigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char prefersNavigationBarBackgroundViewHiddenKey;

- (BOOL)prefersNavigationBarBackgroundViewHidden {
    return [objc_getAssociatedObject(self, &prefersNavigationBarBackgroundViewHiddenKey) boolValue];
}

- (void)setPrefersNavigationBarBackgroundViewHidden:(BOOL)prefersNavigationBarBackgroundViewHidden {
    [[self.navigationController.navigationBar valueForKey:@"_backgroundView"] setHidden:prefersNavigationBarBackgroundViewHidden];
    objc_setAssociatedObject(self, &prefersNavigationBarBackgroundViewHiddenKey, [[NSNumber alloc] initWithBool:prefersNavigationBarBackgroundViewHidden], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UINavigationController (NavigationBarTransition)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        ReplaceMethod(cls, @selector(pushViewController:animated:), @selector(NavigationBarTransition_pushViewController:animated:));
        ReplaceMethod(cls, @selector(popViewControllerAnimated:), @selector(NavigationBarTransition_popViewControllerAnimated:));
        ReplaceMethod(cls, @selector(popToViewController:animated:), @selector(NavigationBarTransition_popToViewController:animated:));
        ReplaceMethod(cls, @selector(popToRootViewControllerAnimated:), @selector(NavigationBarTransition_popToRootViewControllerAnimated:));
    });
}

- (UIPanGestureRecognizer *)fd_fullscreenPopGestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = objc_getAssociatedObject(self, _cmd);
    
    if (!panGestureRecognizer) {
        panGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
        panGestureRecognizer.maximumNumberOfTouches = 1;
        
        objc_setAssociatedObject(self, _cmd, panGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return panGestureRecognizer;
}

- (_FDFullscreenPopGestureRecognizerDelegate *)fd_popGestureRecognizerDelegate
{
    _FDFullscreenPopGestureRecognizerDelegate *delegate = objc_getAssociatedObject(self, _cmd);
    
    if (!delegate) {
        delegate = [[_FDFullscreenPopGestureRecognizerDelegate alloc] init];
        delegate.navigationController = self;
        self.delegate = delegate;
        
        objc_setAssociatedObject(self, _cmd, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return delegate;
}

- (void)NavigationBarTransition_pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.fd_fullscreenPopGestureRecognizer]) {
        
        // Add our own gesture recognizer to where the onboard screen edge pan gesture recognizer is attached to.
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.fd_fullscreenPopGestureRecognizer];
        
        // Forward the gesture events to the private handler of the onboard gesture recognizer.
        NSArray *internalTargets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id internalTarget = [internalTargets.firstObject valueForKey:@"target"];
        SEL internalAction = NSSelectorFromString(@"handleNavigationTransition:");
        self.fd_fullscreenPopGestureRecognizer.delegate = self.fd_popGestureRecognizerDelegate;
        [self.fd_fullscreenPopGestureRecognizer addTarget:internalTarget action:internalAction];
        
        // Disable the onboard gesture recognizer.
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    
    if (!disappearingViewController) {
        return [self NavigationBarTransition_pushViewController:viewController animated:animated];
    }
//    BOOL shouldCustomNavigationBarTransition = NO;
//    if ([disappearingViewController canCustomNavigationBarTransitionWhenPushDisappearing]) {
//        shouldCustomNavigationBarTransition = YES;
//    }
//    if (!shouldCustomNavigationBarTransition && [viewController canCustomNavigationBarTransitionWhenPushAppearing]) {
//        shouldCustomNavigationBarTransition = YES;
//    }
//    if (shouldCustomNavigationBarTransition) {
        [disappearingViewController addTransitionNavigationBarIfNeeded];
        disappearingViewController.prefersNavigationBarBackgroundViewHidden = YES;
//    }
    
    __weak typeof(self) weakSelf = self;
    __weak typeof(UIViewController *) fromVC = self.topViewController;
    _FDViewControllerWillAppearInjectBlock block = ^(UIViewController *viewController, BOOL animated) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            BOOL hide = [viewController respondsToSelector:@selector(navigationHide)] && [viewController performSelector:@selector(navigationHide)];
            [strongSelf setNavigationBarHidden:hide animated:animated];
            [UIApplication sharedApplication].statusBarStyle = viewController.preferredStatusBarStyle;
            [strongSelf setNeedsStatusBarAppearanceUpdate];
        }
    };
    
    viewController.fd_willAppearInjectBlock = block;
    if (disappearingViewController && !disappearingViewController.fd_willAppearInjectBlock) {
        disappearingViewController.fd_willAppearInjectBlock = block;
    }
    return [self NavigationBarTransition_pushViewController:viewController animated:animated];
}

- (UIViewController *)NavigationBarTransition_popViewControllerAnimated:(BOOL)animated {
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    UIViewController *appearingViewController = self.viewControllers.count >= 2 ? self.viewControllers[self.viewControllers.count - 2] : nil;
    if (!disappearingViewController) {
        return [self NavigationBarTransition_popViewControllerAnimated:animated];
    }
    [self handlePopViewControllerNavigationBarTransitionWithDisappearViewController:disappearingViewController appearViewController:appearingViewController];
    return [self NavigationBarTransition_popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)NavigationBarTransition_popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    UIViewController *appearingViewController = viewController;
    if (!disappearingViewController) {
        [self NavigationBarTransition_popToViewController:viewController animated:animated];
    }
    [self handlePopViewControllerNavigationBarTransitionWithDisappearViewController:disappearingViewController appearViewController:appearingViewController];
    return [self NavigationBarTransition_popToViewController:viewController animated:animated];
}

- (NSArray<UIViewController *> *)NavigationBarTransition_popToRootViewControllerAnimated:(BOOL)animated {
    if (self.viewControllers.count > 1) {
        UIViewController *disappearingViewController = self.viewControllers.lastObject;
        UIViewController *appearingViewController = self.viewControllers.firstObject;
        if (!disappearingViewController) {
            [self NavigationBarTransition_popToRootViewControllerAnimated:animated];
        }
        [self handlePopViewControllerNavigationBarTransitionWithDisappearViewController:disappearingViewController appearViewController:appearingViewController];
    }
    return [self NavigationBarTransition_popToRootViewControllerAnimated:animated];
}

- (void)handlePopViewControllerNavigationBarTransitionWithDisappearViewController:(UIViewController *)disappearViewController appearViewController:(UIViewController *)appearViewController {
//    BOOL shouldCustomNavigationBarTransition = NO;
//    if ([disappearViewController canCustomNavigationBarTransitionWhenPopDisappearing]) {
//        shouldCustomNavigationBarTransition = YES;
//    }
//    if (appearViewController && !shouldCustomNavigationBarTransition && [appearViewController canCustomNavigationBarTransitionWhenPopAppearing]) {
//        shouldCustomNavigationBarTransition = YES;
//    }
//    if (shouldCustomNavigationBarTransition) {
        [disappearViewController addTransitionNavigationBarIfNeeded];
        if (appearViewController.transitionNavigationBar) {
            // 假设从A→B→C，其中A设置了bar的样式，B跟随A所以B里没有设置bar样式的代码，C又把样式改为另一种，此时从C返回B时，由于B没有设置bar的样式的代码，所以bar的样式依然会保留C的，这就错了，所以每次都要手动改回来才保险
            [self resetOriginNavigationBarWithCustomNavigationBar:appearViewController.transitionNavigationBar];
        }
        disappearViewController.prefersNavigationBarBackgroundViewHidden = YES;
//    }
}

- (void)resetOriginNavigationBarWithCustomNavigationBar:(UINavigationBar *)navigationBar {
    ///TODO:for molice 保持和addTransitionBar的修改的样式的数量一致
    self.navigationBar.barTintColor = navigationBar.barTintColor;
    [self.navigationBar setBackgroundImage:[navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
    [self.navigationBar setShadowImage:navigationBar.shadowImage];
}

@end

//
//  LPTouchUtils.m
//  Created by Karl Krukow on 14/08/11.
//  Copyright 2011 LessPainful. All rights reserved.
//
#import <sys/utsname.h>

static NSString* lp_deviceName()
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}
#define LPiPHONE4INCHOFFSET 44

#import "LPTouchUtils.h"


@implementation LPTouchUtils

+(BOOL)is5InchPhone {
    UIDevice *device = [UIDevice currentDevice];
    BOOL inch5Phone = NO;
    if([@"iPhone Simulator" isEqualToString: [device model]])
    {
        NSDictionary *env = [[NSProcessInfo processInfo]environment];
        NSPredicate *inch5PhonePred = [NSPredicate predicateWithFormat:@"IPHONE_SIMULATOR_VERSIONS LIKE '*iPhone (Retina 4-inch)*'"];
        inch5Phone = [inch5PhonePred evaluateWithObject:env];
    }
    else if ([[device model] hasPrefix:@"iPhone"])
    {
        inch5Phone = [lp_deviceName() isEqualToString:@"iPhone5,2"];
    }
    return inch5Phone;
}

+(CGPoint) translateToScreenCoords:(CGPoint) point {
    UIScreen*  s = [UIScreen mainScreen];
    

    BOOL inch5Phone = [LPTouchUtils is5InchPhone];

    
    

    UIScreenMode* sm =[s currentMode];
    CGRect b = [s bounds];
    CGSize size = sm.size;
    UIDeviceOrientation o = [[UIDevice currentDevice] orientation];
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        if ([UIScreen mainScreen].scale == 2.0f) {
            CGSize result = [[UIScreen mainScreen] bounds].size;
            CGFloat scale = [UIScreen mainScreen].scale;
            result = CGSizeMake(result.width * scale, result.height * scale);
            
            if(result.height == 960 && inch5Phone)
            {//detect Letterbox
                return CGPointMake(point.x, point.y + LPiPHONE4INCHOFFSET);
            }
            
            if(result.height == 1136){
                //NSLog(@"iPhone 5 Resolution");
                //iPhone 5 full 
                return point;
            }
        } 
    }
    
    
        
    CGRect small_vert = CGRectMake(0, 0, 320, 480);
    CGRect small_hori = CGRectMake(0, 0, 480, 320);
    CGSize large_size_vert = CGSizeMake(768, 1024);
    CGSize large_size_hori = CGSizeMake(1024, 768);
    CGSize retina_ipad_vert = CGSizeMake(1536, 2048);
    CGSize retina_ipad_hori = CGSizeMake(2048, 1536);
    
    
    if ((CGRectEqualToRect(small_vert, b) || CGRectEqualToRect(small_hori, b))  &&
        (CGSizeEqualToSize(large_size_hori, size) || CGSizeEqualToSize(large_size_vert, size) ||
         CGSizeEqualToSize(retina_ipad_hori, size) || CGSizeEqualToSize(retina_ipad_vert, size))) {
       
        CGSize orientation_size =  UIDeviceOrientationIsPortrait(o) || UIDeviceOrientationFaceUp == o || UIDeviceOrientationUnknown == o ? large_size_vert : large_size_hori;
        float x_offset = orientation_size.width/2.0f - b.size.width/2.0f;
        float y_offset = orientation_size.height/2.0f - b.size.height/2.0f;
        return CGPointMake(x_offset+point.x, y_offset+point.y);
    } else {
        return point;
    }
}
+(UIWindow*)windowForView:(UIView*)view
{
    id v = view;
    while (v && ![v isKindOfClass:[UIWindow class]])
    {
        v = [v superview];
    }
    return v;
}

+(BOOL)canFindView:(UIView *)viewToFind asSubViewInView:(UIView *)viewToSearch
{
    if (viewToFind == viewToSearch) { return YES; }
    if (viewToFind == nil || viewToSearch == nil) {return  NO; }
        
    for (UIView *subView  in [viewToSearch subviews])
    {
        if ([self canFindView:viewToFind asSubViewInView:subView])
        {
            return YES;
        }
    }
    return NO;
    
}
+(BOOL)isViewOrParentsHidden:(UIView*)view
{
    if ([view alpha] <= 0.05) {
        return YES;
    }
    UIView* superView = view;
    while (superView)
    {
        if ([superView isHidden]) {
            return YES;
        }
        superView = [superView superview];
    }
    return NO;    
}
+(BOOL)isViewVisible:(UIView *)view
{
    if (![view isKindOfClass:[UIView class]] || [self isViewOrParentsHidden:view]) {return NO;}
    CGPoint center = [self centerOfView:view shouldTranslate:NO];
    UIWindow *windowForView = [self windowForView:view];
    if (!windowForView) {return YES;/* what can I do?*/}
    UIView *hitView = [windowForView hitTest:center withEvent:nil];
    if ([self canFindView: view asSubViewInView:hitView])
    {
        return YES;
    } 
    UIView *hitSuperView = hitView;
    
    while (hitSuperView && hitSuperView != view)
    {
        hitSuperView = [hitSuperView superview];
    }
    if (hitSuperView == view)
    {
        return YES;
    }
    
    if (![view isKindOfClass:[UIControl class]] && ![hitView isKindOfClass:[UINavigationBar class]])
    {
        //there may be a case with a non-control (e.g., label)
        //on top of a control visually but not logically
        UIWindow *viewWin = [self windowForView:view];
        UIWindow *hitWin = [self windowForView:hitView];
        if (viewWin == hitWin)//common window
        {
            CGRect ctrlRect = [viewWin convertRect:hitView.frame fromView:hitView.superview];            
            return CGRectContainsPoint(ctrlRect, center);
            //
            
        }
    }
    return NO;
}

+(CGPoint)centerOfFrame:(CGRect)frame shouldTranslate:(BOOL)shouldTranslate
{
    CGPoint translated =  shouldTranslate ? [self translateToScreenCoords:frame.origin] : frame.origin;
    
    
    return CGPointMake(translated.x + 0.5 * frame.size.width,
                       translated.y + 0.5 * frame.size.height);
}


+(CGPoint)centerOfFrame:(CGRect)frame
{
    return [self centerOfFrame:frame shouldTranslate:YES];
}

+(CGPoint)centerOfView:(UIView *)view shouldTranslate:(BOOL)shouldTranslate
{
 
    UIWindow *delegateWindow = nil;
    NSString *iosVersion = [UIDevice currentDevice].systemVersion;
    id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
    
    if ([[iosVersion substringToIndex:1] isEqualToString:@"4"] || !([appDelegate respondsToSelector:@selector(window)]))
    {
        
        if ([appDelegate respondsToSelector:@selector(window)]) {
            delegateWindow = [appDelegate window];
        }

        if (!delegateWindow)
        {
            NSArray *allWindows = [[UIApplication sharedApplication] windows];
            delegateWindow = [allWindows objectAtIndex:0];
        }
    }
    else
    {
        delegateWindow = appDelegate.window;
    }
    
    UIWindow *viewWindow = [self windowForView:view];
    CGRect bounds = [viewWindow convertRect:view.bounds fromView:view];
    bounds = [delegateWindow convertRect:bounds fromWindow:viewWindow];
        
    return [self centerOfFrame:bounds shouldTranslate:shouldTranslate];
}
+(CGPoint) centerOfView:(UIView *) view 
{
    return [self centerOfView:view shouldTranslate:YES];
}
+(CGPoint) centerOfView:(id)view 
          withSuperView:(UIView *)superView
               inWindow:(id)window
{
        
        CGRect frameInWindow = [window convertRect:[view frame] fromView:superView];
    return [self centerOfFrame:frameInWindow shouldTranslate:YES];
}


//  Created by Olivier Larivain on 3/6/13.
//  Copyright (c) 2013 LessPainful. All rights reserved.
//  Contribution by kra: https://github.com/calabash/calabash-ios-server/pull/15/files
//  Modified 22.04.2013 by Karl Krukow, Xamarin (karl.krukow@xamarin.com)
//      refactor from category method
//

+(void)flashView:(id) viewOrDom forDuration:(NSUInteger) duration
{
    if ([viewOrDom isKindOfClass: [UIView class]])
    {
        UIView *view = (UIView*) viewOrDom;
        
        UIColor *originalBackgroundColor = [view.backgroundColor retain];
        CGFloat orginalAlpha = view.alpha;
        for (NSUInteger i = 0; i < 5; i++) {
            view.backgroundColor = [UIColor yellowColor];
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, .05, false);
            view.alpha = 0;
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, .05, false);
            
            view.backgroundColor = [UIColor blueColor];
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, .05, false);
            
            view.alpha = 1;
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, .05, false);
        }
        view.alpha = orginalAlpha;
        view.backgroundColor = originalBackgroundColor;
        [originalBackgroundColor release];
    }
    else
    {
        //TODO implement flash in JavaScript
    }

}

@end

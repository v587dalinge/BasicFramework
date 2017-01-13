//
//  MainHelper.m
//  BasicFramework
//
//  Created by Rainy on 2016/11/7.
//  Copyright © 2016年 Rainy. All rights reserved.
//

#import "MainHelper.h"
static MainHelper *helper = nil;

@implementation MainHelper

+(instancetype)shareHelper
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[MainHelper alloc] init];
    });
    
    return helper;
}


#pragma mark - 神奇的load方法
+(void)load{
    
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
#pragma mark 容错开启
        [[MainHelper shareHelper] FaultTolerance];
#pragma mark AppDelegate
        [[MainHelper shareHelper] ListeningLifeCycleAndRegisteredAPNS];
        
    });
    
}

-(void)FaultTolerance
{
    
#if !DEBUG
    
    [AvoidCrash becomeEffective];
    //监听通知:AvoidCrashNotification, 获取AvoidCrash捕获的崩溃日志的详细信息
    [kNotificationCenter addObserver:self selector:@selector(dealwithCrashMessage:) name:AvoidCrashNotification object:nil];
#endif
    
}
-(void)dealwithCrashMessage:(NSNotification *)notification
{
    //注意:所有的信息都在userInfo中
    //你可以在这里收集相应的崩溃信息进行相应的处理(比如传到自己服务器)
    NSLog(@"%@",notification.userInfo);
}


- (void)ListeningLifeCycleAndRegisteredAPNS
{
    //注册AppDelegate默认回调监听
    [self _setupAppDelegateNotifications];
    
    //注册apns
    [self _registerRemoteNotification];
    
    
}
// 监听系统生命周期回调，以便将需要的事件传给SDK
- (void)_setupAppDelegateNotifications
{
    [kNotificationCenter addObserver:self selector:@selector(appDidEnterBackgroundNotif:)name:UIApplicationDidEnterBackgroundNotification object:nil];
    [kNotificationCenter addObserver:self selector:@selector(appWillEnterForeground:)name:UIApplicationWillEnterForegroundNotification object:nil];
    [kNotificationCenter addObserver:self selector:@selector(application_OpenURL_SourceApplication_Annotation:) name:_NotificationNameForAppDelegateBackOff object:nil];
    [kNotificationCenter addObserver:self selector:@selector(userDidTakeScreenshot:)name:UIApplicationUserDidTakeScreenshotNotification object:nil];
}
//app-app or web-app互调-回调
- (void)application_OpenURL_SourceApplication_Annotation:(NSNotification *)notif
{
    
    NSString *urlStr = [notif.object absoluteString];
    if ([urlStr hasPrefix:@"basicframework://"]) {
        
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:urlStr delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alert show];
    }
}
- (void)appDidEnterBackgroundNotif:(NSNotification*)notif
{
    NSLog(@"程序进入后台！");
}

- (void)appWillEnterForeground:(NSNotification*)notif
{
    NSLog(@"程序进入前台！");
}
- (void)userDidTakeScreenshot:(NSNotification *)notification
{
    
    NSLog(@"检测到截屏 可以对图片处理 例如：分享...");
    //人为截屏 用户截屏行为 获取所截图片
    UIImage *image = [MainHelper imageWithScreenshot];
}

#pragma mark - register apns
// 注册推送
- (void)_registerRemoteNotification
{
    UIApplication *application = [UIApplication sharedApplication];
    application.applicationIconBadgeNumber = 0;
    
    if([application respondsToSelector:@selector(registerUserNotificationSettings:)])
    {
        UIUserNotificationType notificationTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
        [application registerUserNotificationSettings:settings];
    }
    
#if !TARGET_IPHONE_SIMULATOR
    //iOS8 注册APNS
    if ([application respondsToSelector:@selector(registerForRemoteNotifications)]) {
        [application registerForRemoteNotifications];
    }else{
        UIRemoteNotificationType notificationTypes = UIRemoteNotificationTypeBadge |
        UIRemoteNotificationTypeSound |
        UIRemoteNotificationTypeAlert;
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
    }
#endif
}


/**
*  截取当前屏幕
*
*  @return NSData *
*/
+ (NSData *)dataWithScreenshotInPNGFormat
{
    CGSize imageSize = CGSizeZero;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsPortrait(orientation))
    
        imageSize = [UIScreen mainScreen].bounds.size;
    else
        imageSize = CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);

    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, window.center.x, window.center.y);
        CGContextConcatCTM(context, window.transform);
        CGContextTranslateCTM(context, -window.bounds.size.width * window.layer.anchorPoint.x, -window.bounds.size.height * window.layer.anchorPoint.y);
        
        if (orientation == UIInterfaceOrientationLandscapeLeft)
        {
        
            CGContextRotateCTM(context, M_PI_2);
            CGContextTranslateCTM(context, 0, -imageSize.width);
        }
        else if (orientation == UIInterfaceOrientationLandscapeRight)
        {
       
            CGContextRotateCTM(context, -M_PI_2);
            CGContextTranslateCTM(context, -imageSize.height, 0);
            
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
       
            CGContextRotateCTM(context, M_PI);
            CGContextTranslateCTM(context, -imageSize.width, -imageSize.height);
        }
        if ([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)])
        {
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
        }
        else
        {
            [window.layer renderInContext:context];
        }
        CGContextRestoreGState(context);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return UIImagePNGRepresentation(image);
}


/*  返回截取到的图片
*
*  @return UIImage *
*/
+ (UIImage *)imageWithScreenshot
{
     NSData *imageData = [MainHelper dataWithScreenshotInPNGFormat];
     return [UIImage imageWithData:imageData];
}




- (void)dealloc
{
    [kNotificationCenter removeObserver:self];
}

@end

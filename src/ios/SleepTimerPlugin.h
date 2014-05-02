//
//  SleepTimerPlugin.h
//
//  Created by Brad Kammin on 4/29/14.
//
//

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVPluginResult.h>

@interface SleepTimerPlugin : CDVPlugin
{
    BOOL _countdown;
    NSTimer * _timer;
    NSTimer * _remainingTimeTimer;
    NSString* _callbackId;
}

- (void)sleep:(CDVInvokedUrlCommand*)command;

@end

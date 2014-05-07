//
//  WakeupPlugin.h
//
//  Created by Brad Kammin on 4/29/14.
//
//

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVPluginResult.h>

@interface WakeupPlugin : CDVPlugin
{
    NSString* _callbackId;
}

- (void)wakeup:(CDVInvokedUrlCommand*)command;

@end

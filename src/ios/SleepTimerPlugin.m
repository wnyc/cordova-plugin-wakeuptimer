//
//  SleepTimerPlugin.m
//
//  Created by Brad Kammin on 4/29/14.
//
//

#import "SleepTimerPlugin.h"

@implementation SleepTimerPlugin

#pragma mark Plugin methods

- (void)sleep:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary  * options = [command.arguments objectAtIndex:0];
    
    int seconds = [[options valueForKey:@"sleep"] integerValue];
    _countdown = [[options valueForKey:@"countdown"] boolValue];
    _callbackId = command.callbackId;
    
    if ([_timer isValid]) {
        [_timer invalidate];
        _timer=nil;
    }
    
    if (_remainingTimeTimer && [_remainingTimeTimer isValid]) {
        [_remainingTimeTimer invalidate];
        _remainingTimeTimer=nil;
    }
    
    if (seconds > 0){
        NSLog (@"SleepTimer Plugin sleeping..." );
        _timer = [NSTimer scheduledTimerWithTimeInterval: seconds
                                                  target: self
                                                selector: @selector(sleepTimerExpired)
                                                userInfo: nil
                                                 repeats: NO];

        if (_countdown) {
            _remainingTimeTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                      target: self
                                                    selector: @selector(sleepTimerCountdown)
                                                    userInfo: nil
                                                     repeats: YES];
        }
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) sleepTimerExpired {
    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"type": @"sleep"}];
    
    if ([_timer isValid]) {
        [_timer invalidate];
    }
    _timer=nil;
    if (_remainingTimeTimer && [_remainingTimeTimer isValid]) {
        [_remainingTimeTimer invalidate];
    }
    _remainingTimeTimer=nil;
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

-(void) sleepTimerCountdown {
    NSTimeInterval result = 0;
	if (_timer && [_timer isValid]) {
		result = [[_timer fireDate] timeIntervalSinceNow];
	}
 
    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"type": @"countdown", @"timeLeft" : @((int)ceil(result))}];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

@end

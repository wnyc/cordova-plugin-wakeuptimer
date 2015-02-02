//
//  WakeupPlugin.m
//
//  Created by Brad Kammin on 4/29/14.
//
//

#import "WakeupPlugin.h"

static NSString * const kWakeupPluginJSONAlarmsKey = @"alarms";
static NSString * const kWakeupPluginJSONTypeKey = @"type";
static NSString * const kWakeupPluginJSONAlarmTypeKey = @"alarm_type";
static NSString * const kWakeupPluginJSONExtraKey = @"extra";
static NSString * const kWakeupPluginJSONTimeKey = @"time";
static NSString * const kWakeupPluginJSONMessageKey = @"message";
static NSString * const kWakeupPluginJSONActionKey = @"action";
static NSString * const kWakeupPluginJSONSoundKey = @"sound";
static NSString * const kWakeupPluginJSONDaysKey = @"days";
static NSString * const kWakeupPluginJSONHourKey = @"hour";
static NSString * const kWakeupPluginJSONMinuteKey = @"minute";
static NSString * const kWakeupPluginJSONSecondsKey = @"seconds";
static NSString * const kWakeupPluginJSONAlarmDateKey = @"alarm_date";

static NSString * const kWakeupPluginJSONWakeupValue = @"wakeup";
static NSString * const kWakeupPluginJSONSnoozeValue = @"snooze";
static NSString * const kWakeupPluginJSONOneTimeValue = @"onetime";
static NSString * const kWakeupPluginJSONDaylistValue = @"daylist";
static NSString * const kWakeupPluginJSONSetValue = @"set";

static NSString * const kWakeupPluginJSONDaySundayValue = @"sunday";
static NSString * const kWakeupPluginJSONDayMondayValue = @"monday";
static NSString * const kWakeupPluginJSONDayTuesdayValue = @"tuesday";
static NSString * const kWakeupPluginJSONDayWednesdayValue = @"wednesday";
static NSString * const kWakeupPluginJSONDayThursdayValue = @"thursday";
static NSString * const kWakeupPluginJSONDayFridayValue = @"friday";
static NSString * const kWakeupPluginJSONDaySaturdayValue = @"saturday";

static NSString * const kWakeupPluginAlarmSettingsFile = @"alarmsettings.plist";

@interface WakeupPlugin ()

@property NSString * callbackId;

@end

@implementation WakeupPlugin

- (void)pluginInitialize
{
    // watch for local notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wup_onLocalNotification:) name:CDVLocalNotification object:nil]; // if app is in foreground
    
    [UIDevice currentDevice].batteryMonitoringEnabled=YES; // required to determine if device is charging
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wup_onBatteryStateDidChange:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [self wup_onBatteryStateDidChange:nil];
    
    NSLog(@"Wakeup Plugin initialized");
}


#pragma mark Plugin methods

- (void)wakeup:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary * options = [command.arguments objectAtIndex:0];
    NSArray * alarms;
    
    if ([options objectForKey:kWakeupPluginJSONAlarmsKey]) {
        alarms = [options objectForKey:kWakeupPluginJSONAlarmsKey];
    } else {
        alarms = [NSArray array]; // empty means cancel all
    }
    
    NSLog(@"scheduling wakeups...");
    
    self.callbackId = command.callbackId;
    
    [self wup_saveToPrefs:alarms];
    
    [self wup_setAlarms:alarms cancelAlarms:true];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)snooze:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary * options = [command.arguments objectAtIndex:0];
    NSArray * alarms;
    self.callbackId = command.callbackId;
    
    if ([options objectForKey:kWakeupPluginJSONAlarmsKey]) {
        alarms = [options objectForKey:kWakeupPluginJSONAlarmsKey];
        NSLog(@"scheduling snooze...");
        [self wup_setAlarms:alarms cancelAlarms:false];
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark Preference storage methods

- (void)wup_saveToPrefs:(NSArray *)alarms {
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:alarms options:0 error:&error];
    
    if (!jsonData) {
        NSLog(@"error converting NSDictionary to JSON string: %@", error);
    } else {
        NSMutableDictionary *settings = [self wup_preferences];
        NSString *alarmsJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [settings setValue:alarmsJson forKey:kWakeupPluginJSONAlarmsKey];
        NSString * prefsFile = [self wup_prefsFilePath];
        if (![settings writeToFile:prefsFile atomically:YES]) {
            NSLog(@"failed to save preferences to file!");
        } else {
            [self wup_addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:prefsFile]];
        }
    }
}

- (NSMutableDictionary *) wup_preferences
{
    NSMutableDictionary *prefs;
    if ([[NSFileManager defaultManager] fileExistsAtPath: [self wup_prefsFilePath]]) {
        prefs = [[NSMutableDictionary alloc] initWithContentsOfFile: [self wup_prefsFilePath]];
        
    } else {
        prefs = [[NSMutableDictionary alloc] initWithCapacity: 10];
        /* set default values */
        [prefs setObject:@{} forKey:kWakeupPluginJSONAlarmsKey];
    }
    return prefs;
};

- (NSString *) wup_prefsFilePath
{
    NSString *cacheDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *prefsFilePath = [cacheDirectory stringByAppendingPathComponent: kWakeupPluginAlarmSettingsFile];
    return prefsFilePath;
}

// prevent backup to the Cloud
- (BOOL)wup_addSkipBackupAttributeToItemAtURL:(NSURL *)URL{
    BOOL success=false;
    if ([[NSFileManager defaultManager] fileExistsAtPath: [URL path]])  {
        NSError *error = nil;
        success = [URL setResourceValue: [NSNumber numberWithBool: YES] forKey: NSURLIsExcludedFromBackupKey error: &error];
        if(!success){
            NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
        }
    }
    return success;
}

#pragma mark Alarm configuration methods

- (void)wup_setNotification:(NSString*)type alarmDate:(NSDate*)alarmDate extra:(NSDictionary*)extra message:(NSString*)message action:(NSString*)action  sound:(NSString*)sound repeatInterval:(int)repeatInterval{
    if(alarmDate){
        UILocalNotification* alarm = [[UILocalNotification alloc] init];
        if (alarm) {
            alarm.fireDate = alarmDate;
            alarm.timeZone = [NSTimeZone defaultTimeZone];
            alarm.repeatInterval = repeatInterval;
            
            if (sound!=nil){
                alarm.soundName = sound;
            } else {
                alarm.soundName = UILocalNotificationDefaultSoundName;
            }

            if (message!=nil){
                alarm.alertBody = message;
            } else {
                alarm.alertBody = @"Wake up!";
            }
            
            if (action!=nil){
                alarm.alertAction = action;
            }
            
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extra options:0 error:&error];
            
            NSString *json = @"{}"; // default empty
            
            if (jsonData) {
                json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
            
            alarm.userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                              kWakeupPluginJSONWakeupValue, kWakeupPluginJSONTypeKey,
                              type, kWakeupPluginJSONAlarmTypeKey,
                              json,  kWakeupPluginJSONExtraKey, nil];
            
            NSLog(@"scheduling a new alarm local notification for %@", alarm.fireDate);
            
            UIApplication * app = [UIApplication sharedApplication];
            [app scheduleLocalNotification:alarm];
            
            NSTimeInterval time = [alarmDate timeIntervalSince1970];
            NSNumber *timeMs = [NSNumber numberWithDouble:(time * 1000)];
            CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{kWakeupPluginJSONTypeKey: kWakeupPluginJSONSetValue, kWakeupPluginJSONAlarmTypeKey:type, kWakeupPluginJSONAlarmDateKey : timeMs}];
            [pluginResult setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        }
    }
}

- (void)wup_setAlarms:(NSArray *)alarms cancelAlarms:(BOOL)cancelAlarms{
    
	BOOL backgroundSupported = [self wup_isBackgroundSupported];
    
    if(cancelAlarms) {
        [self wup_cancelAlarms];
    }
    
    if (backgroundSupported) {
        for (int i=0;i<[alarms count];i++){
            NSDictionary * alarm = alarms[i];
            
            NSString * type=[alarm valueForKeyPath:kWakeupPluginJSONTypeKey];
            NSDictionary * time = [alarm valueForKeyPath:kWakeupPluginJSONTimeKey];
            NSDictionary * extra = [alarm valueForKeyPath:kWakeupPluginJSONExtraKey];
            NSString * message = [alarm valueForKeyPath:kWakeupPluginJSONMessageKey];
            NSString * action = [alarm valueForKeyPath:kWakeupPluginJSONActionKey];
            NSString * sound = [alarm valueForKeyPath:kWakeupPluginJSONSoundKey];
            
            if ( type==nil ) {
                type = kWakeupPluginJSONOneTimeValue;
            }
            
            // other types to add support for: weekly, daily, weekday, weekend
            if ( [type isEqualToString:kWakeupPluginJSONOneTimeValue]) {
                NSDate * alarmDate = [self wup_getOneTimeAlarmDate:time];
                [self wup_setNotification:type alarmDate:alarmDate extra:extra message:message action:action sound:sound repeatInterval:0];
            } else if ( [type isEqualToString:kWakeupPluginJSONDaylistValue] ) {
                NSArray * days = [alarm valueForKeyPath:kWakeupPluginJSONDaysKey];
                for (int j=0;j<[days count];j++) {
                    NSDate * alarmDate = [self wup_getAlarmDate:time day:[self wup_dayOfWeekIndex:[days objectAtIndex:j]]];
                    [self wup_setNotification:type alarmDate:alarmDate extra:extra message:message action:action sound:sound repeatInterval:NSWeekCalendarUnit];
                }
            } else if ( [type isEqualToString:kWakeupPluginJSONSnoozeValue]) {
                [self wup_cancelSnooze];
                NSDate * alarmDate = [self wup_getTimeFromNow:time];
                [self wup_setNotification:type alarmDate:alarmDate extra:extra message:message action:action sound:sound repeatInterval:0];
            }
            
            NSLog(@"setting alarm...");
        }
    }
    
}

- (void) wup_cancelAlarms {
    UIApplication * app = [UIApplication sharedApplication];
    NSArray *localNotifications = [app scheduledLocalNotifications];
    
    for (UILocalNotification *not in localNotifications) {
        NSString * type = [not.userInfo objectForKey:kWakeupPluginJSONTypeKey];
        if (type && [type isEqualToString:kWakeupPluginJSONWakeupValue]) {
            NSLog(@"cancelling existing alarm notification");
            [app cancelLocalNotification:not];
        }
        
    }
}

- (void) wup_cancelSnooze {
    UIApplication * app = [UIApplication sharedApplication];
    NSArray *localNotifications = [app scheduledLocalNotifications];
    
    for (UILocalNotification *not in localNotifications) {
        NSString * type = [not.userInfo objectForKey:kWakeupPluginJSONAlarmTypeKey];
        if (type && [type isEqualToString:kWakeupPluginJSONSnoozeValue]) {
            NSLog(@"cancelling existing alarm notification");
            [app cancelLocalNotification:not];
        }
    }
}

- (BOOL) wup_isBackgroundSupported {
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
		backgroundSupported = device.multitaskingSupported;
	}
	return backgroundSupported;
}

-(NSDate*) wup_getOneTimeAlarmDate:(NSDictionary*)time {
    NSDate *alarmDate = nil;
    NSDate * now = [NSDate date];
    int hour=[time objectForKey:kWakeupPluginJSONHourKey]!=nil ? [[time objectForKey:kWakeupPluginJSONHourKey] intValue] : -1;
    int minute=[time objectForKey:kWakeupPluginJSONMinuteKey]!=nil ? [[time objectForKey:kWakeupPluginJSONMinuteKey] intValue] : 0;
    NSCalendar * gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *nowComponents =[gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:now]; // set to current day
    [nowComponents setHour:hour];
    [nowComponents setMinute:minute];
    [nowComponents setSecond:0];
    alarmDate = [gregorian dateFromComponents:nowComponents];

    if ( [alarmDate compare:now]==NSOrderedAscending){
        NSDateComponents * addDayComponents = [[NSDateComponents alloc] init];
        [addDayComponents setDay:1];
        alarmDate = [gregorian dateByAddingComponents:addDayComponents toDate:alarmDate options:0];
    }
    
    return alarmDate;
}

-(NSDate*) wup_getAlarmDate:(NSDictionary*)time day:(int)dayOfWeek {
    NSDate *alarmDate = nil;
    NSDate * now = [NSDate date];
    unsigned nowSeconds=[self wup_secondOfTheDay:now];
    
    int hour=[time objectForKey:kWakeupPluginJSONHourKey]!=nil ? [[time objectForKey:kWakeupPluginJSONHourKey] intValue] : -1;
    int minute=[time objectForKey:kWakeupPluginJSONMinuteKey]!=nil ? [[time objectForKey:kWakeupPluginJSONMinuteKey] intValue] : 0;
    
    if (hour>=0 && dayOfWeek >= 0) {
        NSCalendar * gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *nowComponents =[gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:now];
        [nowComponents setHour:hour];
        [nowComponents setMinute:minute];
        [nowComponents setSecond:0];
        
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *weekdayComponents =[gregorian components:NSWeekdayCalendarUnit fromDate:[NSDate date]];
        NSInteger currentDayOfWeek = [weekdayComponents weekday]; // 1-7 = Sunday-Saturday
        currentDayOfWeek--; // make zero-based
        
        // add number of days until 'dayOfWeek' occurs
        alarmDate = [gregorian dateFromComponents:nowComponents];
        unsigned alarmSeconds=[self wup_secondOfTheDay:alarmDate];
        
        long daysUntilAlarm=0;
        if(currentDayOfWeek>dayOfWeek){
            // currentDayOfWeek=thursday (4); alarm=monday (1) -- add 4 days
            daysUntilAlarm=(6-currentDayOfWeek) + dayOfWeek + 1; // (days until the end of week) + dayOfWeek + 1
        }else if(currentDayOfWeek<dayOfWeek){
            // example: currentDayOfWeek=monday (1); dayOfWeek=thursday (4) -- add three days
            daysUntilAlarm=dayOfWeek-currentDayOfWeek;
        }else{
            if(alarmSeconds > nowSeconds){
                daysUntilAlarm=0;
            }else{
                daysUntilAlarm=7;
            }
        }
        
        NSDateComponents * addDayComponents = [[NSDateComponents alloc] init];
        [addDayComponents setDay:(daysUntilAlarm)];
        alarmDate = [gregorian dateByAddingComponents:addDayComponents toDate:alarmDate options:0];

        
    }
    
	return alarmDate;
}

-(NSDate*) wup_getTimeFromNow:(NSDictionary*)time {
    NSDate *alarmDate = [NSDate date];

    int seconds=[time objectForKey:kWakeupPluginJSONSecondsKey]!=nil ? [[time objectForKey:kWakeupPluginJSONSecondsKey] intValue] : -1;

    if (seconds>=0){
        NSCalendar * gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents * addSeconds = [[NSDateComponents alloc] init];
        [addSeconds setSecond:seconds];
        alarmDate = [gregorian dateByAddingComponents:addSeconds toDate:alarmDate options:0];
    } else {
        alarmDate=nil;
    }
    return alarmDate;
}

- (unsigned) wup_secondOfTheDay:(NSDate*) time
{
    // extracts hour/minutes/seconds from NSDate, converts to seconds since midnight
    NSCalendar* curCalendar = [NSCalendar currentCalendar];
    const unsigned units    = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* comps = [curCalendar components:units fromDate:time];
    int hour = (int)[comps hour];
    int min  = (int)[comps minute];
    int sec  = (int)[comps second];
    
    return ((hour * 60) + min) * 60 + sec;
}

-(int) wup_dayOfWeekIndex:(NSString*)day {
    int dayIndex=-1;
    if ( [day isEqualToString:kWakeupPluginJSONDaySundayValue]){
        dayIndex = 0;
    } else if ( [day isEqualToString:kWakeupPluginJSONDayMondayValue]){
        dayIndex = 1;
    } else if ( [day isEqualToString:kWakeupPluginJSONDayTuesdayValue]){
        dayIndex = 2;
    } else if ( [day isEqualToString:kWakeupPluginJSONDayWednesdayValue]){
        dayIndex = 3;
    } else if ( [day isEqualToString:kWakeupPluginJSONDayThursdayValue]){
        dayIndex = 4;
    } else if ( [day isEqualToString:kWakeupPluginJSONDayFridayValue]){
        dayIndex = 5;
    } else if ( [day isEqualToString:kWakeupPluginJSONDaySaturdayValue]){
        dayIndex = 6;
    }
    return dayIndex;
}

#pragma mark Wakeup handlers

- (void)wup_onLocalNotification:(NSNotification *)notification
{
    NSLog(@"Wakeup Plugin received local notification while app is running");
    
    UILocalNotification* localNotification = [notification object];
    NSString * notificationType = [[localNotification userInfo] objectForKey:kWakeupPluginJSONTypeKey];
    
    if ( notificationType!=nil && [notificationType isEqualToString:kWakeupPluginJSONWakeupValue] && self.callbackId!=nil) {
        NSLog(@"wakeup detected!");
        NSString * extra = [[localNotification userInfo] objectForKey:kWakeupPluginJSONExtraKey];
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{kWakeupPluginJSONTypeKey: kWakeupPluginJSONWakeupValue, kWakeupPluginJSONExtraKey : extra}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }

}

- (void)wup_onBatteryStateDidChange:(NSNotification *)notification {
    NSLog(@"Wakeup Plugin battery status changed");
    if ([UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging || [UIDevice currentDevice].batteryState == UIDeviceBatteryStateFull ) {
        // device is charging - disable automatic screen-locking
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    } else {
        // device is NOT charging - enable automatic screen-locking
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

#pragma mark Cleanup

- (void)dispose {
    NSLog(@"Wakeup Plugin disposing");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CDVLocalNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [super dispose];
}

@end

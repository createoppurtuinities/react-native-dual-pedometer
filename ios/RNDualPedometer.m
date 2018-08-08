#import "RNDualPedometer.h"
#import <CoreMotion/CoreMotion.h>

// import RCTBridge
#if __has_include(<React/RCTBridge.h>)
#import <React/RCTBridge.h>
#elif __has_include(“RCTBridge.h”)
#import “RCTBridge.h”
#else
#import “React/RCTBridge.h” // Required when used as a Pod in a Swift project
#endif

// import RCTEventDispatcher
#if __has_include(<React/RCTEventDispatcher.h>)
#import <React/RCTEventDispatcher.h>
#elif __has_include(“RCTEventDispatcher.h”)
#import “RCTEventDispatcher.h”
#else
#import “React/RCTEventDispatcher.h” // Required when used as a Pod in a Swift project
#endif

@interface RNDualPedometer ()
@property (nonatomic, readonly) CMPedometer *pedometer;
@end

@implementation RNDualPedometer {
    bool hasListeners;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

RCT_REMAP_METHOD(queryPedometerFromDate,
                 startTime:      (NSDate *)startTime
                 endTime:        (NSDate *)endTime
                 queryResolver:  (RCTPromiseResolveBlock)resolve
                 queryRejecter:  (RCTPromiseRejectBlock)reject)
{
    [self queryPedometerFromDate:startTime endTime:endTime queryResolver:resolve queryRejecter:reject];
}

RCT_REMAP_METHOD(startPedometerUpdatesFromDate,
                 startTime:       (NSDate *)startTime
                 eventsResolver:  (RCTPromiseResolveBlock)resolve
                 eventsRejecter:  (RCTPromiseRejectBlock)reject)
{
    [self startPedometerUpdatesFromDate:startTime];
    resolve(@(YES));
}

RCT_REMAP_METHOD(stopPedometerUpdates,
                 eventsResolver:  (RCTPromiseResolveBlock)resolve
                 eventsRejecter:  (RCTPromiseRejectBlock)reject)
{
    [self stopPedometerUpdates];
    resolve(@(YES));
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"pedometer:update"];
}

- (void) queryPedometerFromDate:(NSDate *)startTime endTime:(NSDate *)endTime queryResolver:(RCTPromiseResolveBlock)resolve queryRejecter:(RCTPromiseRejectBlock)reject
{
    NSLog(@"query pedometer start date: %@", startTime);
    NSLog(@"query pedometer end date: %@", endTime);
    
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"Running in Simulator");
    resolve([self simulatorPedometerData:startTime endTime:endTime]);
#else
    NSLog(@"Running on device");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pedometer queryPedometerDataFromDate:startTime
                                            toDate:endTime
                                       withHandler:^(CMPedometerData *pedometerData, NSError *error) {
                                           if (!error) {
                                               resolve([self devicePedometerData:pedometerData]);
                                           } else {
                                               reject(@"failure", @"There was a failure", error);
                                           }
                                       }];
    });
#endif
}

- (void) startPedometerUpdatesFromDate:(NSDate *)startTime
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pedometer startPedometerUpdatesFromDate:startTime
                                          withHandler:^(CMPedometerData *pedometerData, NSError *error) {
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  [self emitMessageToRN:@"pedometer:update" :[self devicePedometerData:pedometerData]];
                                              });
                                          }];
    });
}

- (void) stopPedometerUpdates
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pedometer stopPedometerUpdates];
    });
}

- (NSDictionary *) simulatorPedometerData:(NSDate *)startTime endTime:(NSDate *)endTime {
    
    return @{
             @"startTime": @([startTime timeIntervalSince1970]),
             @"endTime": @([endTime timeIntervalSince1970]),
             @"steps": @(123456),
             };
}

- (NSDictionary *) devicePedometerData:(CMPedometerData *)data {
    
    return @{
             @"startTime": @([data.startDate timeIntervalSince1970] * 1000),
             @"endTime": @([data.endDate timeIntervalSince1970] * 1000),
             @"steps": data.numberOfSteps?:[NSNull null],
             @"distance": data.distance?:[NSNull null],
             @"averageActivePace": data.averageActivePace?:[NSNull null],
             @"currentPace": data.currentPace?:[NSNumber numberWithInt:0],
             @"currentCadence": data.currentCadence?:[NSNumber numberWithInt:0],
             };
}

#pragma mark - Private methods

// Will be called when this module's first listener is added.
- (void) startObserving {
    hasListeners = YES;
}

// Will be called when this module's last listener is removed, or on dealloc.
- (void) stopObserving {
    hasListeners = NO;
}

- (void) emitMessageToRN: (NSString *)eventName :(NSDictionary *)params {
    // The bridge eventDispatcher is used to send events from native to JS env
    // No documentation yet on DeviceEventEmitter: https://github.com/facebook/react-native/issues/2819
    [self sendEventWithName: eventName body: params];
}

- (instancetype) init
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    _pedometer = [[CMPedometer alloc] init];
    
    return self;
}

@end

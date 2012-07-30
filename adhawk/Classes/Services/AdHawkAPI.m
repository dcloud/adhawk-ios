//
//  AdHawkAPI.m
//  adhawk
//
//  Created by Daniel Cloud on 7/12/12.
//  Copyright (c) 2012 Sunlight Foundation. All rights reserved.
//

#import "AdHawkAPI.h"
#import "Settings.h"
#import "AdHawkAd.h"

#define NSLog(__FORMAT__, ...) TFLog((@"%s [Line %d] " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)


NSURL *endPointURL(NSString * path)
{
    return [NSURL URLWithString:path relativeToURL:[NSURL URLWithString:ADHAWK_API_BASE_URL]];
    
}

RKObjectManager *setUpAPI(void)
{
    RKObjectManager* manager = [RKObjectManager objectManagerWithBaseURL:[RKURL URLWithBaseURLString:ADHAWK_API_BASE_URL]];
    [manager.client setValue:ADHAWK_APP_USER_AGENT forHTTPHeaderField:@"User-Agent"];
    manager.acceptMIMEType = RKMIMETypeJSON;
    manager.serializationMIMEType = RKMIMETypeJSON;
    
    RKObjectMapping* adMapping = [RKObjectMapping mappingForClass:[AdHawkAd class]];
    [adMapping mapAttributes: @"result_url", nil];    
    [adMapping mapAttributes:@"share_text", nil];
    [manager.mappingProvider setMapping:adMapping forKeyPath:@""];
    
    [RKObjectManager setSharedManager:manager];
    
    return manager;
}

@implementation AdHawkAPI

@synthesize currentAd, currentAdHawkURL, searchDelegate, _lastFoundLocation;

+ (AdHawkAPI *) sharedInstance
{
    DEFINE_SHARED_INSTANCE_USING_BLOCK(^{
        return [[self alloc] init];
    });
}

- (id)init
{
    self = [super init];
    self._lastFoundLocation = nil;
    setUpAPI();
    
    return self;
}

- (void)searchForAdWithFingerprint:(NSString*)fingerprint delegate:(id)delegate {
    searchDelegate = delegate;
    NSNumber *lat = [NSNumber numberWithInt:0];
    NSNumber *lon = [NSNumber numberWithInt:0];

//    if (nil != self._lastFoundLocation) {
//        lat = [NSNumber numberWithDouble:self._lastFoundLocation.coordinate.latitude];
//        lon = [NSNumber numberWithDouble:self._lastFoundLocation.coordinate.longitude];
//    }
    
    NSMutableDictionary* birdIsTheWord = [NSMutableDictionary dictionaryWithCapacity:3];
    [birdIsTheWord setObject:fingerprint forKey:@"fingerprint"];
    [birdIsTheWord setObject:lat forKey:@"lat"];
    [birdIsTheWord setObject:lon forKey:@"lon"];
    NSLog(@"Submitting fingerprint: %@", fingerprint);
    
//    NSURL *reqURL = endPointURL(@"/ad/");
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    RKObjectManager* manager = [RKObjectManager sharedManager];
    [manager loadObjectsAtResourcePath:@"/ad/" usingBlock:^(RKObjectLoader * loader) {
        loader.serializationMIMEType = RKMIMETypeJSON;
        loader.objectMapping = [manager.mappingProvider objectMappingForClass:[AdHawkAd class]];
        loader.resourcePath = @"/ad/";
        loader.method = RKRequestMethodPOST;
        loader.delegate = self;
        [loader setBody:birdIsTheWord forMIMEType:RKMIMETypeJSON];
        [TestFlight passCheckpoint:@"Submitted Fingerprint"];
    }];
    
//    NSURLRequest *req = [NSURLRequest initWithURL:url];
//    req.HTTPMethod=@"POST";


}

- (void)objectLoaderDidFinishLoading:(RKObjectLoader*)objectLoader {
    NSLog(@"Object Loader Finished: %@", objectLoader.resourcePath);
}

- (void)objectLoader:(RKObjectLoader*)objectLoader didLoadObject:(id)object {
    NSLog(@"Loaded Object");
    
    RKResponse *response = objectLoader.response;
    NSLog(@"response: %@", [response bodyAsString]);
    
    if ([object isKindOfClass:[AdHawkAd class]]) {
        NSLog(@"Got back an AdHawk ad object!");
        self.currentAd = (AdHawkAd *)object;
        self.currentAdHawkURL = self.currentAd.result_url;
        if (self.currentAdHawkURL != NULL) {
            [[self searchDelegate] adHawkAPIDidReturnURL:self.currentAdHawkURL];

        }
        else {
            NSLog(@"currentAdHawkURL is null: issue adHawkAPIDidReturnNoResult");
            [[self searchDelegate] adHawkAPIDidReturnNoResult];
        }
    }
    else {
        NSLog(@"Got back an object, but it didn't conform to AdHawkAd");
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Server Error" message:@"The server didn't return data AdHawk could identify" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil]; 
        [alertView show];
        [[self searchDelegate] adHawkAPIDidReturnNoResult];
    }
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}


- (void)objectLoader:(RKObjectLoader*)objectLoader didFailWithError:(NSError*)error {
    NSLog(@"%@", error.localizedDescription);
    NSString *recoverySuggestion = error.localizedRecoverySuggestion;
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Server Error" message:@"There was a problem connecting to the server" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil]; 
    [alertView show];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[self searchDelegate] adHawkAPIDidReturnNoResult];
}

#pragma mark CLLocationManager delegate methods

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    // If it's a relatively recent event, turn off updates to save power
    NSDate* eventDate = newLocation.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    
    if (nil == _lastFoundLocation || abs(howRecent) > 15.0) {
        _lastFoundLocation = newLocation;
        NSLog(@"latitude %+.6f, longitude %+.6f\n",
               _lastFoundLocation.coordinate.latitude,
               _lastFoundLocation.coordinate.longitude);

    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"Location update failed: @%", [error localizedDescription]);
}

@end

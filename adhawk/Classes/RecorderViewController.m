//
//  RecorderViewController.m
//  adhawk
//
//  Created by Jim Snavely on 4/14/12.
//  Copyright (c) 2012 Sunlight Foundation 
//

#import "RecorderViewController.h"
#import "AdDetailViewController.h"
#import "AdhawkErrorViewController.h"
#import "InternalAdBrowserViewController.h"
#import "AdHawkLocationManager.h"
#import "Settings.h"
#import "AdHawkAPI.h"
#import "AdHawkAd.h"


extern const char * GetPCMFromFile(char * filename);

@implementation RecorderViewController

@synthesize recordButton, workingBackground, failView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (NSString*) getAudioFilePath {

    NSArray * dirPaths = NSSearchPathForDirectoriesInDomains(
                                                   NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [dirPaths objectAtIndex:0];
    NSString *soundFilePath = [docsDir
                               stringByAppendingPathComponent:@"sound.caf"];
    return soundFilePath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    failView = nil;
    _hawktivityAnimatedImageView = nil;
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnteredBackground:) 
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
//    [[AdHawkAPI sharedInstance] searchForAdWithFingerprint:TEST_FINGERPRINT delegate:self];
//    [self setFailState:YES];
//    [self showSocialActionSheet:self]; // Testing social action sheet
    
    
    [self setFailState:NO];
    
    [self setWorkingState:NO];
    
    // Recording setup. Audio session set up in AppDelegate
    NSString *soundFilePath = [self getAudioFilePath];                                
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    NSDictionary *recordSettings = [NSDictionary 
                                    dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:AVAudioQualityMin],
                                    AVEncoderAudioQualityKey,
                                    [NSNumber numberWithInt:16], 
                                    AVEncoderBitRateKey,
                                    [NSNumber numberWithInt: 2], 
                                    AVNumberOfChannelsKey,
                                    [NSNumber numberWithFloat:44100.0], 
                                    AVSampleRateKey,
                                    nil];
    
    NSError *error = nil;
    
    audioRecorder = [[AVAudioRecorder alloc]
                     initWithURL:soundFileURL
                     settings:recordSettings
                     error:&error];
    audioRecorder.delegate = self;
    
    if (error)
    {
        NSLog(@"error: %@", [error localizedDescription]);
        
    } else {
        [audioRecorder prepareToRecord];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    [audioRecorder release];
    if (_hawktivityAnimatedImageView != nil) {
        [_hawktivityAnimatedImageView release];
        _hawktivityAnimatedImageView = nil;
    }
    if (failView != nil) {
        [failView release];
        failView = nil;
    }
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    recordButton.hidden = NO;
}

- (void) viewDidDisappear:(BOOL)animated
{
    [self setFailState:NO];
    if (_hawktivityAnimatedImageView != nil) {
        [_hawktivityAnimatedImageView release];
        _hawktivityAnimatedImageView = nil;
    }
    if (audioRecorder.recording) {
        [audioRecorder stop];
    }
    [self setWorkingState:NO];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) handleEnteredBackground:(NSNotification *)notification
{
    [self setFailState:NO];
}

- (void) retryButtonClicked
{
    [self setFailState:NO];
    [self setWorkingState:YES];
    [self recordAudio];
}

-(void) setFailState:(BOOL)isFail
{
    if (isFail && failView == nil) {
        AdhawkErrorViewController *errorVC = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"adhawkErrorVC"];
        failView = errorVC.view;
        [errorVC.popularResultsButton addTarget:self action:@selector(showBrowseWebView) forControlEvents:UIControlEventTouchUpInside];
        [errorVC.tryAgainButton addTarget:self action:@selector(handleTVButtonTouch) forControlEvents:UIControlEventTouchUpInside];
        [errorVC.whyNoResultsButton addTarget:self action:@selector(handleWhyNoResultsTouch) forControlEvents:UIControlEventTouchUpInside];
    }
    if (isFail) {
        [self.view addSubview:failView];
        failView.frame = self.view.frame;
    }
    else {
        if ([failView isDescendantOfView:self.view]) {
            [failView removeFromSuperview];
        }
        failView = nil;
    }
}

- (void)setWorkingState:(BOOL)isWorking
{
    if(_hawktivityAnimatedImageView == nil)
    {
        UIImage *animImage = [UIImage animatedImageNamed:@"Animation_" duration:3.125];  
        _hawktivityAnimatedImageView = [[UIImageView alloc] initWithImage:animImage];
        _hawktivityAnimatedImageView.layer.position = recordButton.layer.position;
    }
    if (isWorking) {
        [self.view addSubview:_hawktivityAnimatedImageView];
        workingBackground.hidden = NO;
        recordButton.hidden = YES;
        recordButton.enabled = NO; 
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
    else {
        [_hawktivityAnimatedImageView removeFromSuperview];
        workingBackground.hidden = YES;
        recordButton.hidden = NO;
        recordButton.enabled = YES; 
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
   }
}

#pragma mark button touches

-(void)handleTVButtonTouch
{
    NSLog(@"handleTVButtonTouch run");
    
    AdHawkLocationManager *locationManager = [AdHawkLocationManager sharedInstance];
    [locationManager attempLocationUpdateOver:20.0];
    
    [self setWorkingState:YES];
    [self recordAudio];
}


-(void)showBrowseWebView
{
    InternalAdBrowserViewController *vc = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"internalBrowserVC"];
    NSURL *browseURL = [NSURL URLWithString:ADHAWK_BROWSE_URL];
    [self.navigationController pushViewController:vc animated:YES];
    [vc.webView loadRequest:[NSURLRequest requestWithURL:browseURL]];
}


-(void)handleWhyNoResultsTouch
{
    SimpleWebViewController *vc = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"simpleWebVC"];
    NSURL *browseURL = [NSURL URLWithString:ADHAWK_TROUBLESHOOTING_URL];
    [self.navigationController pushViewController:vc animated:YES];
    [vc.webView loadRequest:[NSURLRequest requestWithURL:browseURL]];
}

-(void) recordAudio
{
    NSLog(@"Start recording audio");
    if (!audioRecorder.recording)
    {
        [self setFailState:NO];

        BOOL didRecord = [audioRecorder recordForDuration:(NSTimeInterval)15.0];        
        if (didRecord) {
            [self setWorkingState:YES];
        }
        else{
            NSLog(@"audioRecorder failed to start recording");
        }

        NSLog(@"Trying recordforDuration method... %@", (didRecord ? @"SUCCESS" : @"FAILURE"));
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [super prepareForSegue:segue sender:sender];
    if ([[segue identifier] isEqualToString:@"adSegue"])
    {
        // Get reference to the destination view controller
        AdDetailViewController *vc = [segue destinationViewController];
        NSLog(@"Segue to AdDetailView");
        
        // Pass any objects to the view controller here, like...
        NSURL *targetURL = [AdHawkAPI sharedInstance].currentAd.result_url;
        [vc setTargetURLString:[targetURL absoluteString]];
    }
}

- (void) stopRecorder
{
    [audioRecorder stop];
    [self handleRecordingFinished];
}

-(void)handleRecordingFinished
{    
    NSLog(@"Handle recording finished. Recorder %@ recording", (audioRecorder.recording ? @"IS" : @"IS NOT"));
    if (audioRecorder.recording) [audioRecorder stop]; else NSLog(@"Audio recorder stopped already, as expected");
    NSString *soundFilePath = [self getAudioFilePath];
    const char * fpCode = GetPCMFromFile((char*) [soundFilePath cStringUsingEncoding:NSASCIIStringEncoding]);
    NSString *fpCodeString = [NSString stringWithCString:fpCode encoding:NSASCIIStringEncoding];
    NSLog(@"Fingerprint generated");
    
//    [[AdHawkAPI sharedInstance] searchForAdWithFingerprint:TEST_FINGERPRINT delegate:self];
    [[AdHawkAPI sharedInstance] searchForAdWithFingerprint:fpCodeString delegate:self];
    [audioRecorder deleteRecording];

}


-(void) adHawkAPIDidReturnURL:(NSURL *)url
{
//    [self performSegueWithIdentifier:@"adSegue" sender:self];
    AdDetailViewController *vc = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"adDetailVC"];
    [vc setTargetURLString:[url absoluteString]];
    [self.navigationController pushViewController:vc animated:YES];
    [self setWorkingState:NO];
}

-(void) adHawkAPIDidReturnNoResult
{
    NSLog(@"No results for search");
    [self setWorkingState:NO];
    [self setFailState:YES];
}

-(void) adHawkAPIDidFailWithError:(NSError *) error
{
    NSLog(@"Fail error: %@", error.code);
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:[error.userInfo objectForKey:@"title"] message:[error.userInfo objectForKey:@"message"] 
                                                       delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil]; 
    [alertView show];
    [self setWorkingState:NO];
}


#pragma mark AudioRecorderDelegate message handlers

-(void)audioRecorderDidFinishRecording: (AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    NSLog(@"audioRecorderDidFinishRecording successully: %@", flag ? @"True" : @"False");
    [self handleRecordingFinished];
}

-(void)audioRecorderEncodeErrorDidOccur: (AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"Encode Error occurred");
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder
{
    TFLog(@"Audio recording interrupted. Should only happen during a call or something.");
}

-(void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder
{
    TFLog(@"Audio recording resumed.");
}

@end

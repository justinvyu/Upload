//
//  ImageCaptureViewController.m
//  Upload
//
//  Created by Justin Yu on 1/17/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "ImageCaptureViewController.h"
#import "AVCamPreviewView.h"
#import "ImageEditViewController.h"
#import "UIImage+ResizeAdditions.h"
#import "UploadConstants.h"
#import "PickerTableViewController.h"
#import "INTULocationManager.h"

#import <Parse/Parse.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>

@interface ImageCaptureViewController () <UIScrollViewDelegate, UITextFieldDelegate, UIPickerViewDelegate, PickerTableViewControllerDelegate>

// Storyboard Outlets
// Before taking
@property (weak, nonatomic) IBOutlet AVCamPreviewView *previewView;
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIView *footerView;
@property (weak, nonatomic) IBOutlet UIButton *captureButton;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

// After taking
@property (weak, nonatomic) IBOutlet UIImageView *imageDisplayView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UITextField *keyboard;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *chooseTagButton;

// AVCaptureSession Management
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) dispatch_queue_t sessionQueue; // Communicate w/ session and other session objects
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;

// Image Management
@property (strong, nonatomic) UIImage *stillImage;
@property (strong, nonatomic) UIImage *croppedImage; // ex: 320 x 320
@property (strong, nonatomic) UIImage *resizedImage; // kImageHeight x kImageHeight, pixels

// For upload
@property (strong, nonatomic) PFFile *imageFile;

// Utils
@property (nonatomic) BOOL deviceAuthorized;
@property (nonatomic) BOOL flashOn;
@property (nonatomic) BOOL captureModeOn;
@property (nonatomic) BOOL locked;
@property (strong, nonatomic) CLLocation *currentLocation;

// Background Task ID
@property (nonatomic) UIBackgroundTaskIdentifier fileUploadBackgroundTaskId;
@property (nonatomic) UIBackgroundTaskIdentifier photoPostBackgroundTaskId;

// Location Task ID
@property (nonatomic) INTULocationRequestID locationRequestID;

@end

@implementation ImageCaptureViewController

#pragma mark - Actions

- (IBAction)chooseTag:(id)sender {
    UINavigationController *navigationController = (UINavigationController *)[self.storyboard instantiateViewControllerWithIdentifier:@"TableNVC"];
    PickerTableViewController *tableViewController = (PickerTableViewController *)[[navigationController viewControllers] objectAtIndex:0];
    tableViewController.navigationItem.title = @"Tags";
    tableViewController.delegate = self;
    tableViewController.tag = self.tag;
    tableViewController.tags = self.tags;
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (IBAction)touchNextButton:(id)sender {
    
    NSString *caption = self.keyboard.text;
    NSString *tag = self.tag;
    PFGeoPoint *coordinate = nil;
    if (self.currentLocation) {
        coordinate = [PFGeoPoint geoPointWithLatitude:self.currentLocation.coordinate.latitude
                                                        longitude:self.currentLocation.coordinate.longitude];
    }
    if (!self.imageFile) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"Make sure that you have taken a photo"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    } else if (!caption || [caption isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"Make sure that you have added a caption"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    } else if (!tag || [tag isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"Make sure that you have added a tag"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    } else if (!coordinate) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"No location???"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    PFObject *photo = [PFObject objectWithClassName:kUploadClassKey];
    [photo setObject:self.imageFile forKey:kUploadPhotoKey];
    [photo setObject:caption forKey:kUploadCaptionKey];
    [photo setObject:tag forKey:kUploadTagKey];
    [photo setObject:coordinate forKey:kUploadReadableGeolocationKey];
    
    self.photoPostBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];
    
    NSLog(@"Requested background expiration task with id %lu for photo upload TO PARSE (including caption, etc.)", (unsigned long)self.photoPostBackgroundTaskId);
    [photo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded to Parse");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:ImageCaptureDidUploadPhotoNotification object:photo];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                            message:nil
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];
    
    [self changeMode];
}

- (IBAction)toggleFlash:(id)sender {
    self.flashOn = self.flashOn ? NO : YES;
    [self.flashButton setImage:[UIImage imageNamed:self.flashOn ? @"flashOn" : @"flashOff"] forState:UIControlStateNormal];
}

- (BOOL)shouldUploadImage {
    UIImage *resizedStillImage = [self.stillImage resizedImage:CGSizeMake(self.view.bounds.size.width,
                                                                          self.view.bounds.size.height)
                                          interpolationQuality:kCGInterpolationHigh];
    
    // Cropped image for testing
    self.croppedImage = [resizedStillImage croppedImage:CGRectMake(0,
                                                                   self.headerView.bounds.size.height,
                                                                   self.view.bounds.size.width,
                                                                   self.view.bounds.size.width)];
    
    self.resizedImage = [self.croppedImage resizedImage:CGSizeMake(kImageHeight, kImageHeight)
                                   interpolationQuality:kCGInterpolationHigh];
    
    
    NSData *imageData = UIImageJPEGRepresentation(self.resizedImage, 1.0f);
    
    if (!imageData) {
        return NO;
    }
    
    self.imageFile = [PFFile fileWithData:imageData];
    
    // Request a background execution task to allow us to finish uploading the photo even if the app is backgrounded
    self.fileUploadBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
    }];
    
    NSLog(@"Requested background expiration task with id %lu for photo upload", (unsigned long)self.fileUploadBackgroundTaskId);
    [self.imageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded successfully");
            [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
        } else {
            NSLog(@"Failed");
            [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
        }
    }];
    
    return YES;
}

- (IBAction)touchCancelButton:(id)sender {
    // Cancel any ongoing background actions
    [self changeMode];
}

#pragma mark - Changing Mode

- (void)changeMode {
    if (self.captureModeOn) {
        self.nextButton.hidden = NO;
        self.keyboard.hidden = NO;
        self.cancelButton.hidden = NO;
        
        self.chooseTagButton.hidden = NO;
        self.flashButton.enabled = NO;
        self.captureButton.hidden = YES;
        self.previewView.hidden = YES;
        
        self.captureModeOn = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        
        [self shouldUploadImage];
    } else {
        self.nextButton.hidden = YES;
        self.keyboard.hidden = YES;
        self.cancelButton.hidden = YES;
        
        self.chooseTagButton.hidden = YES;
        self.flashButton.enabled = YES;
        self.captureButton.hidden = NO;
        self.previewView.hidden = NO;
        
        self.keyboard.text = @"";
        self.tag = nil;
        self.imageDisplayView.image = nil;
        self.stillImage = nil;
        self.croppedImage = nil;
        self.resizedImage = nil;
        
        self.captureModeOn = YES;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    }
}

#pragma mark - Properties

- (NSString *)tag {
    if (!_tag) {
        _tag = @"";
    }
    return _tag;
}

- (NSArray *)tags {
    if (!_tags) {
        _tags = @[@"Food", @"Scenery", @"Event", @"Emergency", @"News"];
    }
    return _tags;
}

- (void)setStillImage:(UIImage *)stillImage {
    _stillImage = stillImage;
    
    self.imageDisplayView.image = stillImage;
}

#pragma mark - Check if Device has Camera Authorization

- (void)checkDeviceAuthorizationStatus {
    NSString *mediaType = AVMediaTypeVideo;
    
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (granted) {
            // Granted access
            [self setDeviceAuthorized:YES];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"Camera not authorized!"
                                            message:@"Upload needs permission to use the Camera, please change privacy settings"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
                [self setDeviceAuthorized:NO];
            });
        }
    }];
}

#pragma mark - Take Image

- (IBAction)snapStillImage:(id)sender
{
    dispatch_async([self sessionQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
        
        // Flash set to Auto for Still Capture
        [ImageCaptureViewController setFlashMode:self.flashOn ? AVCaptureFlashModeOn : AVCaptureFlashModeOff
                                       forDevice:[[self videoDeviceInput] device]];
        
        // Capture a still image.
        // To do: animate the capture
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            
            if (imageDataSampleBuffer)
            {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                // send over image and present edit vc
                UIImage *captureImage = [UIImage imageWithData:imageData];
                
                if (!captureImage)
                    return;
                
                self.stillImage = captureImage;
                
                
                /*
                CGFloat w_scaleFactor = captureImage.size.width / self.view.bounds.size.width;
                CGFloat h_scaleFactor = captureImage.size.height / self.view.bounds.size.height;
                
                NSLog(@"%f, %f", w_scaleFactor, h_scaleFactor);
                
                self.resizedImage = [[captureImage croppedImage:CGRectMake(0,
                                                                           self.headerView.bounds.size.height * w_scaleFactor,
                                                                           self.view.bounds.size.width * w_scaleFactor,
                                                                           self.view.bounds.size.width * w_scaleFactor)]
                                     resizedImage:CGSizeMake(kImageHeight, kImageHeight) interpolationQuality:kCGInterpolationHigh];
                                     
                
                */
                
                [self startSingleLocationRequest];
                [self changeMode];
            }
        }];
    });
}

#pragma mark - Get the video device for a specified media type

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    // Get the preferred camera
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}


#pragma mark - Set Flash

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ([device hasFlash] && [device isFlashModeSupported:flashMode])
    {
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    }
}

#pragma mark - Animation


#pragma mark - Get User's current location

- (void)startSingleLocationRequest {
    INTULocationManager *locationManager = [INTULocationManager sharedInstance]; // Get a singleton of the class
    NSTimeInterval timeout = 10.0;
    self.locationRequestID = [locationManager requestLocationWithDesiredAccuracy:INTULocationAccuracyBlock
                                                                         timeout:timeout
                               block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                                   if (status == INTULocationStatusSuccess) {
                                       // achievedAccuracy is at least the desired accuracy (potentially better)
                                       self.currentLocation = currentLocation;
                                   } else if (status == INTULocationStatusTimedOut) {
                                       
                                   } else {
                                       [[[UIAlertView alloc] initWithTitle:@"Location services (probably) not authorized!"
                                                                  message:@"Upload needs permission to use location, please change privacy settings"
                                                                 delegate:self
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles:nil] show];
                                       /*
                                       if (status == INTULocationStatusServicesNotDetermined) {
                                        
                                       } else if (status == INTULocationStatusServicesRestricted) {
                                           
                                       } else if (status == INTULocationStatusServicesDisabled) {
                                           
                                       } else if (status == INTULocationStatusServicesDenied) {
                                           
                                       } else {
                                           
                                       }
                                        */
                                   }
                               }];
}

/*
#pragma mark - Get User's current location

- (void)getCurrentLocation {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        NSLog(@"V. 8.0 of higher");
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    [self.locationManager startUpdatingLocation];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    NSLog(@"inside");
    [self.locationManager stopUpdatingLocation];
}
 */

#pragma mark - PickerTableViewControllerDelegate

- (void)tagSelected:(NSString *)tag {
    self.tag = tag;
    NSLog(@"%@", self.tag);
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // Prevent crashing undo bug – see note below.
    if(range.length + range.location > textField.text.length)
    {
        return NO;
    }
    
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength > 140) ? NO : YES; // Do not allow the user to type another character if the char count is > 140
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    //[self touchNextButton:textField];
    [textField resignFirstResponder];
    return YES;
}

- (void)keyboardWillShow:(NSNotification *)note {
    if (!self.locked) {
        CGRect keyboardFrameEnd = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        CGSize scrollViewContentSize = self.scrollView.bounds.size;
        scrollViewContentSize.height += keyboardFrameEnd.size.height;
        [self.scrollView setContentSize:scrollViewContentSize];
        
        CGPoint scrollViewContentOffset = self.scrollView.contentOffset;
        // Align the bottom edge of the photo with the keyboard
        scrollViewContentOffset.y = scrollViewContentOffset.y + keyboardFrameEnd.size.height*2.7f - [UIScreen mainScreen].bounds.size.height;
        
        [self.scrollView setContentOffset:scrollViewContentOffset animated:NO];
        
        self.locked = YES;
    }
}

- (void)keyboardWillHide:(NSNotification *)note {
    CGRect keyboardFrameEnd = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGSize scrollViewContentSize = self.scrollView.bounds.size;
    scrollViewContentSize.height -= keyboardFrameEnd.size.height;
    [UIView animateWithDuration:0.200f animations:^{
        [self.scrollView setContentSize:scrollViewContentSize];
    }];
    self.locked = NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.keyboard resignFirstResponder];
}

#pragma mark - VC Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Create AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];
    
    // Setup preview view
    [[self previewView] setSession:session];
    
    // Delegate
    self.keyboard.delegate = self;
    self.scrollView.delegate = self;
    
    // Check for authorization
    [self checkDeviceAuthorizationStatus];
    
    // Hide all unneccessary buttons / views
    self.nextButton.hidden = YES;
    self.cancelButton.hidden = YES;
    self.keyboard.hidden = YES;
    
    self.captureModeOn = YES;
    self.flashOn = NO;
    self.locked = NO;
    
    // Tag Button
    CALayer *layer = [self.chooseTagButton layer];
    [layer setMasksToBounds:YES];
    [layer setCornerRadius:5.0f];
    self.chooseTagButton.hidden = YES;
    
    /* Masking
    // Create a mask layer and the frame to determine what will be visible in the view.
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect maskRect = CGRectMake(0, 0, 320, 320 + self.footerView.bounds.size.height);
    
    // Create a path with the rectangle in it.
    CGPathRef path = CGPathCreateWithRect(maskRect, NULL);
    
    // Set the path to the mask layer.
    maskLayer.path = path;
    
    // Release the path since it's not covered by ARC.
    CGPathRelease(path);
    
    // Set the mask of the view.
    self.previewView.layer.mask = maskLayer;
    */
    
    // Not good to do all session initialization on the main queue, blocks UI b/c of [session startRunning]
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL); // "line" queue
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{
        self.fileUploadBackgroundTaskId = UIBackgroundTaskInvalid; // initialize as invalid, "nil"
        self.photoPostBackgroundTaskId = UIBackgroundTaskInvalid;
        
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [ImageCaptureViewController deviceWithMediaType:AVMediaTypeVideo
                                                                    preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error) {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:videoDeviceInput]) {
            [session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];

        }
        
        // Get the Still Image Output
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([session canAddOutput:stillImageOutput]) {
            // Set the compress / decompress coder / decoder to use JPEG format
            [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
            [session addOutput:stillImageOutput];
            [self setStillImageOutput:stillImageOutput];
        }
    });
    
}

#pragma mark - Hide Status Bar

// Remember to set:
//      View controller-based status bar appearance to NO in Info.plist
//      Status bar is initially hidden to NO in Info.plist

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    dispatch_async([self sessionQueue], ^{
        [[self session] startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    dispatch_async([self sessionQueue], ^{
        [[self session] stopRunning];
    });
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}
   

/*
#pragma mark - Test Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"Test"]) {
        if ([segue.destinationViewController isKindOfClass:[TestViewController class]]) {
            TestViewController *tvc = (TestViewController *)segue.destinationViewController;
            tvc.image = self.resizedImage;
        }
    }
}
*/

@end

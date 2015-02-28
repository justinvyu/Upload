//
//  IUUploadViewController.m
//  Uploadv2
//
//  Created by Justin Yu on 2/13/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "IUUploadViewController.h"
#import "AVCamPreviewView.h"
#import "UploadConstants.h"
#import "UIImage+ResizeAdditions.h"
#import "IUPostPhotoTableViewController.h"
#import "CameraFocusSquareView.h"

#import <Parse/Parse.h>
#import <AVFoundation/AVFoundation.h>

@interface IUUploadViewController () <UITextFieldDelegate, IUPostPhotoTableViewControllerDelegate>

// UI
@property (strong, nonatomic) AVCamPreviewView *previewView;
@property (strong, nonatomic) UIButton *captureButton;
@property (strong, nonatomic) UIButton *flashButton;
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) UIImageView *imageDisplayView;
@property (strong, nonatomic) UIButton *cancelButton;
@property (strong, nonatomic) UIView *headerView;
@property (strong, nonatomic) UIView *footerView;
@property (strong, nonatomic) UIView *subFooterView;
@property (strong, nonatomic) CameraFocusSquareView *previousCamFocus;

// AVCaptureSession Management
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) dispatch_queue_t sessionQueue; // Communicate w/ session and other session objects
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;

// Image Management
@property (strong, nonatomic) UIImage *stillImage;
@property (strong, nonatomic) UIImage *resizedImage; // kImageHeight x kImageHeight, pixels

// For upload
@property (strong, nonatomic) PFFile *imageFile;

// Utils
@property (nonatomic) BOOL deviceAuthorized;
@property (nonatomic) BOOL flashOn;

// Background Task ID
@property (nonatomic) UIBackgroundTaskIdentifier fileUploadBackgroundTaskId;

@end

@implementation IUUploadViewController

#pragma mark - Touch Selectors

- (void)takeStillImage {
    dispatch_async([self sessionQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo]
         setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
        
        // Flash set to Auto for Still Capture
        [IUUploadViewController setFlashMode:self.flashOn ? AVCaptureFlashModeOn : AVCaptureFlashModeOff
                                       forDevice:[[self videoDeviceInput] device]];
        
        // Capture a still image.
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo]
                                                             completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
             if (imageDataSampleBuffer) {
                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                 // send over image and present edit vc
                 UIImage *captureImage = [UIImage imageWithData:imageData];
                 if (!captureImage) {
                     return;
                 }
                 self.stillImage = captureImage;
                 [self shouldUploadImage];
                 [self presentPostPhotoVC];
             }
         }];
    });
}

- (void)touchCancelButton {
    // Cancel any ongoing background actions
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)toggleFlash:(UIButton *)sender {
    self.flashOn = self.flashOn ? NO : YES;
    if (self.flashOn) {
        self.flashButton.tintColor = [UIColor whiteColor];
    } else {
        self.flashButton.tintColor = [UIColor lightGrayColor];
    }
}

- (void)presentPostPhotoVC {    
    IUPostPhotoTableViewController *ptvc = [[IUPostPhotoTableViewController alloc] initWithImage:self.resizedImage
                                                                                       imageFile:self.imageFile];
    ptvc.delegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:ptvc];
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - IUPostPhotoTableViewControllerDelegate

- (void)postUploaded:(id<IUPostPhotoTableViewControllerDelegate>)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Focus

- (void)subjectAreaDidChange:(NSNotification *)notification {
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *device = [[self videoDeviceInput] device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]) {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode]) {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        } else {
            NSLog(@"%@", error);
        }
    });
}

- (void)focus:(UIGestureRecognizer *)gesture {
    
    CGPoint touchPoint = [gesture locationInView:self.previewView];
    
    CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:[gesture locationInView:[gesture view]]];
    //NSLog(@"%f, %f", touchPoint.x, touchPoint.y);
    
    [self.previousCamFocus removeFromSuperview];
    CGRect focusRect = CGRectMake(touchPoint.x-(squareLength / 2), touchPoint.y-(squareLength / 2), squareLength, squareLength);
    CameraFocusSquareView *camFocus = [[CameraFocusSquareView alloc]initWithFrame:focusRect];
    [camFocus setBackgroundColor:[UIColor clearColor]];
    [self.previewView addSubview:camFocus];
    self.previousCamFocus = camFocus;
    [camFocus setNeedsDisplay];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:1.5];
    [camFocus setAlpha:0.0];
    [UIView commitAnimations];
    
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

#define VIEW_HEIGHT self.view.bounds.size.height
#define VIEW_WIDTH self.view.bounds.size.width

- (void)setupUI {
    self.view.backgroundColor = [UIColor blackColor];
    
    // Preview View
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.scrollView];
    
    self.previewView = [[AVCamPreviewView alloc] init];
    
    // Create AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    self.session = session;
    // Special config for iPad
    // Keep the default if iPhone
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
    }
    self.previewView.session = session;
    
    self.previewView.frame = self.view.frame;
    self.previewView.center = self.view.center;
    
    [self.scrollView addSubview:self.previewView];
    [self checkDeviceAuthorizationStatus];
    
    // Image Display View
    self.imageDisplayView = [[UIImageView alloc] initWithImage:nil];
    self.imageDisplayView.frame = self.scrollView.frame;
    self.imageDisplayView.center = self.scrollView.center;
    [self.scrollView addSubview:self.imageDisplayView];
    
    // Header View and Subviews
    self.headerView = [[UIView alloc] init];
    self.headerView.frame = CGRectMake(0, 0, self.scrollView.bounds.size.width, 44);
    self.headerView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.8f];
    [self.scrollView addSubview:self.headerView];
    
    self.cancelButton = [[UIButton alloc] initWithFrame:CGRectMake(self.headerView.frame.origin.x + 10,
                                                                   self.headerView.frame.origin.y + 8,
                                                                   30,
                                                                   30)];
    [self.cancelButton setImage:[UIImage imageNamed:@"PKImageBundle.bundle/Cancel.png"] forState:UIControlStateNormal];
    self.cancelButton.userInteractionEnabled = YES;
    [self.cancelButton addTarget:self action:@selector(touchCancelButton) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.cancelButton];
    
    self.flashButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.flashButton setImage:[UIImage imageNamed:@"PKImageBundle.bundle/flash.png"] forState:UIControlStateNormal];
    [self.flashButton setImage:[UIImage imageNamed:@"PKImageBundle.bundle/flashselected.png"] forState:UIControlStateSelected];
    [self.flashButton addTarget:self action:@selector(toggleFlash:) forControlEvents:UIControlEventTouchUpInside];
    CGFloat flashButtonSideLength = 30;
    self.flashButton.tintColor = [UIColor lightGrayColor];
    self.flashButton.frame = CGRectMake(self.headerView.bounds.size.width - flashButtonSideLength - 10,
                                        self.headerView.frame.origin.y + 8,
                                        flashButtonSideLength, flashButtonSideLength);
    [self.headerView addSubview:self.flashButton];
     
    // Footer View and Subviews
    self.footerView = [[UIView alloc] init];
    self.footerView.frame = CGRectMake(0,
                                       self.headerView.bounds.size.height + self.scrollView.bounds.size.width,
                                       self.scrollView.bounds.size.width,
                                       self.scrollView.bounds.size.height - (self.headerView.bounds.size.height + self.scrollView.bounds.size.width));
    self.footerView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.8f];
    [self.scrollView addSubview:self.footerView];
    
    self.subFooterView = [[UIView alloc] init];
    self.subFooterView.frame = CGRectMake(0, 50,
                                          self.footerView.bounds.size.width,
                                          self.footerView.bounds.size.height - 50);
    self.subFooterView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:1.0f];
    [self.footerView addSubview:self.subFooterView];
    
    self.captureButton = [[UIButton alloc] init];
    CGFloat captureButtonSideLength = 80 > self.footerView.bounds.size.height ? self.footerView.bounds.size.height : 80;
    self.captureButton.frame = CGRectMake((self.view.bounds.size.width / 2) - (captureButtonSideLength / 2),
                                          VIEW_HEIGHT - (self.subFooterView.bounds.size.height / 2) - (captureButtonSideLength / 2),
                                          captureButtonSideLength, captureButtonSideLength);
    [self.captureButton setBackgroundImage:[UIImage imageNamed:@"capture.png"] forState:UIControlStateNormal];
    [self.captureButton addTarget:self action:@selector(takeStillImage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.captureButton];
    
    // Tap to Focus
    UITapGestureRecognizer *focus = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focus:)];
    [self.previewView addGestureRecognizer:focus];
}

#pragma mark - Uploading Image File

/**
 *  Checks to see if the image is correctly outputted from AVFoundation crops and resizes to make a 600 by 600
 *  image, and uploads the imageFile to Parse.
 *
 *  Commented out: Thumbnail image support
 *
 *  @return YES or NO depending on whether or not the image can be uploaded.
 */
- (BOOL)shouldUploadImage {
    
    CGFloat scaleFactor = (self.stillImage.size.width / self.view.bounds.size.width);
    
    UIImage *correctImage = [self.stillImage resizedImage:CGSizeMake(self.stillImage.size.width, self.view.bounds.size.height * scaleFactor)
                                     interpolationQuality:kCGInterpolationHigh];
    UIImage *croppedImage = [correctImage croppedImage:CGRectMake(0,
                                                                  self.headerView.bounds.size.height * scaleFactor,
                                                                  correctImage.size.width,
                                                                  correctImage.size.height - (self.footerView.bounds.size.height * scaleFactor))];
    UIImage *resizedImage = [croppedImage resizedImage:CGSizeMake(kImageHeight, kImageHeight) interpolationQuality:kCGInterpolationHigh];
    self.resizedImage = resizedImage;
    //UIImage *thumbnailImage = [resizedImage thumbnailImage:100 transparentBorder:1.0 cornerRadius:5.0 interpolationQuality:kCGInterpolationHigh];
    
    NSData *imageData = UIImageJPEGRepresentation(resizedImage, 1.0f);
    //NSData *thumbnailImageData = UIImageJPEGRepresentation(thumbnailImage, 1.0f);
    if (!imageData) {
        return NO;
    }
    
    PFFile *imageFile = [PFFile fileWithData:imageData];
    //PFFile *thumbnailImageFile = [PFFile fileWithData:thumbnailImageData];
    self.imageFile = imageFile;
    
    // Request a background execution task to allow us to finish uploading the photo even if the app is backgrounded
    self.fileUploadBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
    }];
    
    NSLog(@"Requested background expiration task with id %lu for photo upload", (unsigned long)self.fileUploadBackgroundTaskId);
    [imageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded successfully");
            /*
            [thumbnailImageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    NSLog(@"Thumbnail uploaded successfully");
                } else {
                    NSLog(@"Failed");
                }
            }];
             */
        } else {
            NSLog(@"Failed");
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                            message:@"Make sure you have internet connection"
                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            });
            
        }
        [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
    }];
    return YES;
}

#pragma mark - Properties

- (void)setStillImage:(UIImage *)stillImage {
    _stillImage = stillImage;
    
    self.imageDisplayView.image = stillImage;
}

#pragma mark - Get the video device for a specgified media type

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position {
    // Get the preferred camera
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            captureDevice = device;
            break;
        }
    }
    return captureDevice;
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

#pragma mark - Set Flash

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device {
    if ([device hasFlash] && [device isFlashModeSupported:flashMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        } else {
            NSLog(@"%@", error);
        }
    }
}

#pragma mark - VC Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupUI];
    
    self.flashOn = NO;    
    self.imageDisplayView.hidden = YES;
    self.imageDisplayView.userInteractionEnabled = NO;
    
    // Not good to do all session initialization on the main queue, blocks UI b/c of [session startRunning]
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL); // "line" queue
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{
        self.fileUploadBackgroundTaskId = UIBackgroundTaskInvalid; // initialize as invalid, "nil"
        //self.photoPostBackgroundTaskId = UIBackgroundTaskInvalid;
        
        NSError *error = nil;
        AVCaptureDevice *videoDevice = [IUUploadViewController deviceWithMediaType:AVMediaTypeVideo
                                                                preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
        if ([videoDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [videoDevice lockForConfiguration:&error]) {
            [videoDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            [videoDevice unlockForConfiguration];
        }
        if ([self.session canAddInput:videoDeviceInput]) {
            [self.session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
            
        }
        
        // Get the Still Image Output
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([self.session canAddOutput:stillImageOutput]) {
            // Set the compress / decompress coder / decoder to use JPEG format
            [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
            [self.session addOutput:stillImageOutput];
            [self setStillImageOutput:stillImageOutput];
        }
    });
}

- (BOOL)shouldAutorotate {
    return NO;
}

#pragma mark - Hide Status Bar

// Remember to set:
//      View controller-based status bar appearance to NO in Info.plist
//      Status bar is initially hidden to NO in Info.plist
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    dispatch_async([self sessionQueue], ^{
        [self.session startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    dispatch_async([self sessionQueue], ^{
        [self.session stopRunning];
    });
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end

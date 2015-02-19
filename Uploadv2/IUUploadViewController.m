//
//  IUUploadViewController.m
//  Uploadv2
//
//  Created by Justin Yu on 2/13/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "IUUploadViewController.h"
#import "ImageCaptureViewController.h"
#import "AVCamPreviewView.h"
#import <Parse/Parse.h>
#import <AVFoundation/AVFoundation.h>

@interface IUUploadViewController () <UITextFieldDelegate>

// Before taking
@property (strong, nonatomic) AVCamPreviewView *previewView;

@property (strong, nonatomic) UIButton *captureButton;
@property (strong, nonatomic) UIButton *flashButton;

@property (strong, nonatomic) UIScrollView *scrollView;

// After taking
@property (strong, nonatomic) UIImageView *imageDisplayView;
@property (strong, nonatomic) UIButton *nextButton;
//@property (weak, nonatomic) IBOutlet UIButton *chooseTagButton;

@property (strong, nonatomic) UIButton *cancelButton;
@property (strong, nonatomic) UIView *headerView;
@property (strong, nonatomic) UIView *footerView;

//@property (strong, nonatomic) UITextField *textField;

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
@property (strong, nonatomic) PFGeoPoint *coordinate;

// Utils
@property (nonatomic) BOOL deviceAuthorized;
@property (nonatomic) BOOL flashOn;
@property (nonatomic) BOOL captureModeOn;
@property (nonatomic) BOOL locked;

// Background Task ID
@property (nonatomic) UIBackgroundTaskIdentifier fileUploadBackgroundTaskId;
@property (nonatomic) UIBackgroundTaskIdentifier photoPostBackgroundTaskId;

// Location Task ID
//@property (nonatomic) INTULocationRequestID locationRequestID;

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
        // To do: animate the capture
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo]
                                                             completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
             if (imageDataSampleBuffer)
             {
                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                 // send over image and present edit vc
                 UIImage *captureImage = [UIImage imageWithData:imageData];
                 
                 if (!captureImage)
                     return;
                 
                 self.stillImage = captureImage;
                 
                 [PFGeoPoint geoPointForCurrentLocationInBackground:^(PFGeoPoint *geoPoint, NSError *error) {
                     if (error) {
                         NSLog(@"Unable to get Location");
                     } else {
                         self.coordinate = geoPoint;
                         NSLog(@"Location is Set");
                     }
                 }];
                 
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
                 
                 [self changeMode];
             }
         }];
    });
}

- (void)touchCancelButton {
    // Cancel any ongoing background actions
    if (!self.captureModeOn) {
        [self changeMode];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)toggleFlash {
    self.flashOn = self.flashOn ? NO : YES;
    [self.flashButton setImage:[UIImage imageNamed:self.flashOn ? @"flashOn" : @"flashOff"] forState:UIControlStateNormal];
}

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Code
        
        [self setupUI];
        
        self.nextButton.hidden = YES;
        
        self.captureModeOn = YES;
        self.flashOn = NO;
        self.locked = NO;
        
        self.imageDisplayView.userInteractionEnabled = YES;
        
        /*
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(handleTap:)];
        [self.imageDisplayView addGestureRecognizer:tap];
        */
        
        // Not good to do all session initialization on the main queue, blocks UI b/c of [session startRunning]
        dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL); // "line" queue
        [self setSessionQueue:sessionQueue];
        
        dispatch_async(sessionQueue, ^{
            self.fileUploadBackgroundTaskId = UIBackgroundTaskInvalid; // initialize as invalid, "nil"
            self.photoPostBackgroundTaskId = UIBackgroundTaskInvalid;
            
            NSError *error = nil;
            
            AVCaptureDevice *videoDevice = [IUUploadViewController deviceWithMediaType:AVMediaTypeVideo
                                                                        preferringPosition:AVCaptureDevicePositionBack];
            AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
            
            if (error) {
                NSLog(@"%@", error);
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
    
    return self;
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor blackColor];
    
    // Example Label Adding
    /*
     UILabel *label = [[UILabel alloc] init];
     
     label.frame = self.view.frame;
     label.text = @"Test";
     label.textColor = [UIColor blackColor];
     label.textAlignment = NSTextAlignmentCenter;
     
     [self.view addSubview:label];
     */
    
    // Preview View
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.scrollView];
    
    self.previewView = [[AVCamPreviewView alloc] init];
    
    // Create AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    self.session = session;
    
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
    self.headerView.frame = CGRectMake(0, 0, self.scrollView.bounds.size.width, 50);
    self.headerView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.8f];
    //self.headerView.alpha = 0.8f;

    [self.scrollView addSubview:self.headerView];
    
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:@"✕" forState:UIControlStateNormal];
    self.cancelButton.titleLabel.textColor = [UIColor whiteColor];
    self.cancelButton.tintColor = [UIColor whiteColor];
    self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:25];
    self.cancelButton.showsTouchWhenHighlighted = YES;
    
    self.cancelButton.frame = CGRectMake(self.headerView.frame.origin.x + 8, self.headerView.frame.origin.y + 8, 35, 35);
    self.cancelButton.userInteractionEnabled = YES;
    [self.cancelButton addTarget:self action:@selector(touchCancelButton) forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView addSubview:self.cancelButton];
    
    self.flashButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.flashButton setImage:[UIImage imageNamed:@"flashOff"] forState:UIControlStateNormal];
    [self.flashButton addTarget:self action:@selector(toggleFlash) forControlEvents:UIControlEventTouchUpInside];
    CGFloat flashButtonSideLength = 35;
    self.flashButton.tintColor = [UIColor whiteColor];
    self.flashButton.frame = CGRectMake(self.headerView.bounds.size.width - flashButtonSideLength - 8,
                                        self.headerView.frame.origin.y + 8,
                                        flashButtonSideLength, flashButtonSideLength);
    self.flashButton.showsTouchWhenHighlighted = YES;
    [self.headerView addSubview:self.flashButton];
    
    // Footer View and Subviews
    
    self.footerView = [[UIView alloc] init];
    self.footerView.frame = CGRectMake(0,
                                       self.headerView.bounds.size.height + self.scrollView.bounds.size.width,
                                       self.scrollView.bounds.size.width,
                                       self.scrollView.bounds.size.height - (self.headerView.bounds.size.height + self.scrollView.bounds.size.width));
    
    self.footerView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.8f];
    [self.scrollView addSubview:self.footerView];
    
    self.captureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    [self.captureButton setBackgroundImage:[UIImage imageNamed:@"capture.png"] forState:UIControlStateNormal];
    
    CGFloat captureButtonSideLength = 90 > self.footerView.bounds.size.height ? self.footerView.bounds.size.height : 90;
    
    self.captureButton.frame = CGRectMake((self.footerView.bounds.size.width / 2) - (captureButtonSideLength / 2),
                                          (self.footerView.bounds.size.height / 2) - (captureButtonSideLength / 2),
                                          captureButtonSideLength, captureButtonSideLength);
    self.captureButton.userInteractionEnabled = YES;
    self.captureButton.showsTouchWhenHighlighted = YES;
    [self.captureButton addTarget:self action:@selector(takeStillImage) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.captureButton];
    
    /*
    self.nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    CGFloat nextButtonSideLength = 50 > self.footerView.bounds.size.height ? self.footerView.bounds.size.height : 50;
    self.nextButton.frame = CGRectMake(self.footerView.bounds.size.width - (self.footerView.bounds.size.width / 2) - (nextButtonSideLength / 2),
                                       (self.footerView.bounds.size.height / 2) - (nextButtonSideLength / 2),
                                       nextButtonSideLength,
                                       nextButtonSideLength);
    [self.nextButton setImage:[UIImage imageNamed:@"next.png"] forState:(UIControlStateNormal | UIControlStateHighlighted)];
    [self.footerView addSubview:self.nextButton];
     */
}

#pragma mark - Change Mode

- (void)changeMode {
    if (self.captureModeOn) {
        self.nextButton.hidden = NO;
        //self.keyboard.hidden = NO;
        
        //self.chooseTagButton.hidden = NO;
        self.flashButton.enabled = NO;
        self.captureButton.hidden = YES;
        self.previewView.hidden = YES;
        
        self.captureModeOn = NO;
        /*
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
         */
        //[self shouldUploadImage];
    } else {
        self.nextButton.hidden = YES;
        
        //self.chooseTagButton.hidden = YES;
        self.flashButton.enabled = YES;
        self.captureButton.hidden = NO;
        self.previewView.hidden = NO;
        
        /*
        self.textField.text = @"";
        self.tag = nil;
         */
        self.imageDisplayView.image = nil;
        self.stillImage = nil;
        self.croppedImage = nil;
        self.resizedImage = nil;
        
        /*
        self.textField.hidden = YES;
        [self.textField resignFirstResponder];
        */
        
        self.captureModeOn = YES;
        
        /*
         [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
         [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
         */
    }
}

#pragma mark - Properties

- (void)setStillImage:(UIImage *)stillImage {
    _stillImage = stillImage;
    
    self.imageDisplayView.image = stillImage;
}

#pragma mark - Get the video device for a specgified media type

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

#pragma mark - VC Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

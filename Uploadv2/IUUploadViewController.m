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

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Code
        
        [self setupUI];
        
        self.nextButton.hidden = YES;
        //self.cancelButton.hidden = YES;
        
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
    
    // Header & Footer View
    
    self.headerView = [[UIView alloc] init];
    self.headerView.frame = CGRectMake(0, 0, self.scrollView.bounds.size.width, 50);
    self.headerView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:1.0f];
    //self.headerView.alpha = 0.8f;

    [self.scrollView addSubview:self.headerView];
    
    self.footerView = [[UIView alloc] init];
    self.footerView.frame = CGRectMake(0,
                                       self.headerView.bounds.size.height + self.scrollView.bounds.size.width,
                                       self.scrollView.bounds.size.width,
                                       self.scrollView.bounds.size.height - (self.headerView.bounds.size.height + self.scrollView.bounds.size.width));
    
    self.footerView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:1.0f];
    [self.scrollView addSubview:self.footerView];
    
    self.captureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    [self.footerView addSubview:self.captureButton];
    [self.captureButton setBackgroundImage:[UIImage imageNamed:@"capture"] forState:UIControlStateNormal];
    self.captureButton.center = self.scrollView.center;

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

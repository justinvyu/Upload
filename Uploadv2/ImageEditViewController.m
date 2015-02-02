//
//  ImageEditViewController.m
//  Upload
//
//  Created by Justin Yu on 1/17/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "ImageEditViewController.h"
#import "ImageCaptureViewController.h"
#import "UIImage+ResizeAdditions.h"
#import <Parse/Parse.h>

@interface ImageEditViewController ()

// For storyboard
@property (weak, nonatomic) IBOutlet UIImageView *imageDisplayView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UITextField *keyboard;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;

// Image Management
@property (strong, nonatomic) UIImage *croppedImage; // ex: 320 x 320
@property (strong, nonatomic) UIImage *resizedImage; // kImageHeight x kImageHeight, pixels
@property (strong, nonatomic) NSData *resizedImageData; // For upload

@end

@implementation ImageEditViewController

#pragma mark - Actions

- (IBAction)touchNextButton:(id)sender {
    
}

- (IBAction)touchCancelButton:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:NO completion:nil];
}

- (BOOL)shouldUploadImage {
    
    PFObject *photo = [[PFObject alloc] initWithClassName:@"Photo"];
    
    return YES;
}

- (void)resizeCroppedImage {
    CGSize size = CGSizeMake(kImageHeight, kImageHeight);
    UIImage *resizedImage = [self.croppedImage resizedImage:size interpolationQuality:kCGInterpolationHigh];
    
    [self setResizedImage:resizedImage];
    [self setResizedImageData:UIImageJPEGRepresentation(self.resizedImage, 0.8f)];
}

- (void)cropOriginalImage {
    UIImage *croppedImage = [self.originalImage croppedImage:CGRectMake(0,
                                                                        self.croppedImagePaddingFromTop,
                                                                        self.view.bounds.size.width,
                                                                        self.view.bounds.size.width)];
    [self setCroppedImage:croppedImage];
}

#pragma mark - Properties

- (void)setOriginalImage:(UIImage *)originalImage {
    _originalImage = originalImage;
    
    self.imageDisplayView.image = originalImage;
}

#pragma mark - VC Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
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

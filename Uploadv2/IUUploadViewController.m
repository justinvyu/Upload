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

@interface IUUploadViewController ()

@property (strong, nonatomic) UIScrollView *scrollView;

@end

@implementation IUUploadViewController

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Code
        
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
        
        AVCamPreviewView *previewView = [[AVCamPreviewView alloc] init];
        
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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

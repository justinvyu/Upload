//
//  IUPostPhotoViewController.m
//  Uploadv2
//
//  Created by Justin Yu on 2/18/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "IUPostPhotoViewController.h"

@interface IUPostPhotoViewController ()

@property (strong, nonatomic) PFFile *imageFile;
@property (strong, nonatomic) PFFile *thumbnailImageFile;

@end

@implementation IUPostPhotoViewController

- (instancetype)initWithImage:(UIImage *)image withThumbnailImage:(UIImage *)thumbnailImage {
    self = [super init];
    
    if (self) {
        
        self.modalPresentationStyle = UIModalTransitionStyleCrossDissolve;
        self.view.backgroundColor = [UIColor whiteColor];
        
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

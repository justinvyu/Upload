//
//  ImageEditViewController.h
//  Upload
//
//  Created by Justin Yu on 1/17/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageEditViewController : UIViewController

@property (strong, nonatomic) UIImage *originalImage; // size of the entire self.view
@property (nonatomic) CGFloat croppedImagePaddingFromTop;

@end

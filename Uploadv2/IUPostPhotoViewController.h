//
//  IUPostPhotoViewController.h
//  Uploadv2
//
//  Created by Justin Yu on 2/18/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <Parse/Parse.h>

@interface IUPostPhotoViewController : UIViewController

- (instancetype)initWithImage:(UIImage *)image withThumbnailImage:(UIImage *)thumbnailImage;

@end

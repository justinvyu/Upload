//
//  ImageCaptureViewController.h
//  Upload
//
//  Created by Justin Yu on 1/17/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageCaptureViewController : UIViewController

/*
 
 Things to do:
 Autolayout
 MAYBE get rid of storyboards and do everything in code
 Add a view to mask the capture view
 
 Geotagging
 Let the user choose a tag
 
 */

@property (strong, nonatomic) NSArray *tags;
@property (strong, nonatomic) NSString *tag;

@end


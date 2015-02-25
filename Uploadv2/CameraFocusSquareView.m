//
//  CameraFocusSquareView.m
//  Uploadv2
//
//  Created by Justin Yu on 2/19/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "CameraFocusSquareView.h"
#import <QuartzCore/QuartzCore.h>

const float squareLength = 80.0f;

@implementation CameraFocusSquareView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        [self setBackgroundColor:[UIColor clearColor]];
        [self.layer setBorderWidth:2.0];
        //[self.layer setCornerRadius:4.0];
        [self.layer setBorderColor:[UIColor whiteColor].CGColor];
        
        CABasicAnimation *selectionAnimation = [CABasicAnimation
                                                animationWithKeyPath:@"borderColor"];
        selectionAnimation.toValue = (id)[UIColor purpleColor].CGColor;
        selectionAnimation.repeatCount = 2;
        [self.layer addAnimation:selectionAnimation
                          forKey:@"selectionAnimation"];
        
    }
    return self;
}

@end
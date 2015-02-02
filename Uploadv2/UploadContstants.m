//
//  UploadContstants.m
//  Upload
//
//  Created by Justin Yu on 1/20/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "UploadConstants.h"

#pragma mark - UIImage
CGFloat const kImageHeight = 600.0f;

#pragma mark - Photo Upload Keys
NSString *const kUploadClassKey = @"Photo";
NSString *const kUploadPhotoKey = @"image";
NSString *const kUploadTagKey = @"tag";
NSString *const kUploadCaptionKey = @"caption";
NSString *const kUploadReadableGeolocationKey = @"coordinate";

#pragma mark - NSNotificationCenter
NSString *const ImageCaptureDidUploadPhotoNotification = @"imageCaptureDidUploadPhotoNotification";
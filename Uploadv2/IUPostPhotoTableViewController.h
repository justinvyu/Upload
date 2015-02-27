//
//  IUPostPhotoTableViewController.h
//  
//
//  Created by Justin Yu on 2/20/15.
//
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>

@class IUPostPhotoTableViewController;

/**
 *  Detects when the photo has been either posted or has failed to post to Parse
 */
@protocol IUPostPhotoTableViewControllerDelegate /* replace with CreatePostViewControllerDelegate */ <NSObject>

@optional

- (void)postUploaded:(IUPostPhotoTableViewController *)sender;

@end

@interface IUPostPhotoTableViewController : UITableViewController

- (instancetype)initWithImage:(UIImage *)image imageFile:(PFFile *)imageFile;

@property (strong, nonatomic) UIImage *image;

@property (weak, nonatomic) id<IUPostPhotoTableViewControllerDelegate> delegate;

@end
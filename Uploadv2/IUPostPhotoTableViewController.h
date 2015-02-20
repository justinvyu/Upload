//
//  IUPostPhotoTableViewController.h
//  
//
//  Created by Justin Yu on 2/20/15.
//
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>

@interface IUPostPhotoTableViewController : UITableViewController

- (instancetype)initWithImage:(UIImage *)image imageFile:(PFFile *)imageFile coordinate:(PFGeoPoint *)coordinate;

@end

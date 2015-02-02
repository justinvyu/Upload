//
//  PickerTableViewController.h
//  Upload
//
//  Created by Justin Yu on 1/24/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PickerTableViewControllerDelegate <NSObject>

@required
- (void)tagSelected:(NSString *)tag;

@end

@interface PickerTableViewController : UITableViewController

@property (strong, nonatomic) NSArray *tags;
@property (strong, nonatomic) NSString *tag;

@property (strong, nonatomic) id<PickerTableViewControllerDelegate> delegate;

@end

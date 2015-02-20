//
//  IUPostPhotoTableViewController.m
//  
//
//  Created by Justin Yu on 2/20/15.
//
//

#import "IUPostPhotoTableViewController.h"
#import <SZTextView/SZTextView.h>

@interface IUPostPhotoTableViewController () <UITextViewDelegate>

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) PFFile *imageFile;
@property (strong, nonatomic) PFGeoPoint *coordinate;

@property (strong, nonatomic) UIImageView *imageDisplayView;

@property (strong, nonatomic) UITableViewCell *imageCell;
@property (strong, nonatomic) UITableViewCell *tagCell;
@property (strong, nonatomic) UITableViewCell *captionCell;
@property (strong, nonatomic) UITableViewCell *uploadCell;
@property (strong, nonatomic) SZTextView *textField;

@property (strong, nonatomic) NSString *tag;
@property (strong, nonatomic) NSString *caption;

@property (strong, nonatomic) UIBarButtonItem *cancelButton;
@property (strong, nonatomic) UIBarButtonItem *uploadButton; // for iphone 4

@property (nonatomic) UIBackgroundTaskIdentifier photoPostBackgroundTaskId;

@end

@implementation IUPostPhotoTableViewController

#pragma mark - Touch Selectors

- (void)dismissKeyboard {
    [self.textField resignFirstResponder];
}

- (void)uploadImage {
    NSLog(@"Uploading...");
}

- (void)cancelUpload {
    NSLog(@"cancelled");
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Init

- (instancetype)initWithImage:(UIImage *)image imageFile:(PFFile *)imageFile coordinate:(PFGeoPoint *)coordinate {
    self = [super init];
    
    if (self) {
        // init
        self.image = image;
        self.imageFile = imageFile;
        self.coordinate = coordinate;
    }
    
    return self;
}

- (void)setImage:(UIImage *)image {
    _image = image;
    
    self.imageDisplayView.image = image;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.scrollEnabled = NO;
    
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    if ([[UIScreen mainScreen] bounds].size.height < 568) {
        self.uploadButton = [[UIBarButtonItem alloc] initWithTitle:@"Upload" style:UIBarButtonItemStylePlain target:self action:@selector(uploadImage)];
        self.uploadButton.tintColor = [UIColor colorWithRed:0.4 green:0.1 blue:0.5 alpha:0.7];
        self.navigationItem.rightBarButtonItem = self.uploadButton;
    }
    
    self.cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(cancelUpload)];
    self.cancelButton.tintColor = [UIColor whiteColor];
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    
    self.imageCell = [[UITableViewCell alloc] init];
    self.imageDisplayView = [[UIImageView alloc] init];
    self.imageDisplayView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width);
    self.imageDisplayView.image = self.image;
    [self.imageCell addSubview:self.imageDisplayView];
    
    self.tagCell = [[UITableViewCell alloc] init];
    self.tagCell.imageView.image = [UIImage imageNamed:@"tag2"];
    self.tagCell.textLabel.text = @"Add a tag";
    self.tagCell.textLabel.font = [UIFont systemFontOfSize:15];
    self.tagCell.textLabel.textColor = [UIColor blackColor];
    
    self.captionCell = [[UITableViewCell alloc] init];
    self.textField = [[SZTextView alloc] init];
    self.textField.frame = CGRectInset(self.captionCell.frame, 5, 5);
    self.textField.center = self.captionCell.center;
    self.textField.placeholder = @"Add a caption (less than 140 characters)";
    self.textField.font = [UIFont systemFontOfSize:15];
    [self.captionCell addSubview:self.textField];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:tap];
    
    self.textField.delegate = self;
    
    self.uploadCell = [[UITableViewCell alloc] init];
    self.uploadCell.textLabel.text = @"Upload";
    self.uploadCell.textLabel.textAlignment = NSTextAlignmentCenter;
    self.uploadCell.textLabel.textColor = [UIColor whiteColor];
    self.uploadCell.backgroundColor = [UIColor colorWithRed:0.4 green:0.1 blue:0.5 alpha:0.7];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    // Prevent crashing undo bug – see note below.
    if(range.length + range.location > textView.text.length)
    {
        return NO;
    }
    
    NSUInteger newLength = [textView.text length] + [text length] - range.length;
    return (newLength > 140) ? NO : YES; // Do not allow the user to type another character if the char count is > 140
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case 0:
            return self.view.bounds.size.width;
        case 1:
            return 50;
        case 2:
            if ([[UIScreen mainScreen] bounds].size.height < 568) {
                CGFloat height = self.view.bounds.size.height - 50 - (44/2) - self.view.bounds.size.width - self.navigationController.navigationBar.bounds.size.height;
                CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, height);
                self.textField.frame = CGRectInset(frame, 5, 5);
                return height;
            } else {
                CGFloat height = self.view.bounds.size.height - 100 - (44/2) - self.view.bounds.size.width - self.navigationController.navigationBar.bounds.size.height;
                CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, height);
                self.textField.frame = CGRectInset(frame, 5, 5);
                return height;
            }
        case 3:
            return 50;
    }
    return 44;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    if (screenRect.size.height < 568) {
        NSLog(@"iphone 4");
        return 3;
    } else {
        NSLog(@"iphone 5+");
        return 4;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Configure the cell...
    
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                return self.imageCell;
            case 1:
                return self.tagCell;
            case 2:
                return self.captionCell;
            case 3:
                return self.uploadCell;
        }
    }
    
    return nil;
}

@end

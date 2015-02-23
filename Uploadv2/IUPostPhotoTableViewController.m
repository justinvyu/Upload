//
//  IUPostPhotoTableViewController.m
//  
//
//  Created by Justin Yu on 2/20/15.
//
//

#import "IUPostPhotoTableViewController.h"
#import "UploadConstants.h"
#import "Event.h"
#import "IUUploadViewController.h"

#import <SZTextView/SZTextView.h>
#import <ActionSheetPicker-3.0/ActionSheetPicker.h>
#import <RestKit/RestKit.h>

@interface IUPostPhotoTableViewController () <UITableViewDelegate, UITextViewDelegate>

#define kFoursquareClientID @"CKYNLQRGVBTFIEZXN1AAQIZHLEJHP03YJPZVIHW2XY323KUV"
#define kFoursquareSecret @"XLEOBERHEPFCID4CIZ2543F1RO04MGU0IJ1VVRKHIC4ZCHUE"

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) PFFile *imageFile;
@property (strong, nonatomic) PFGeoPoint *coordinate;

@property (strong, nonatomic) UIImageView *imageDisplayView;
@property (strong, nonatomic) NSArray *events;

@property (strong, nonatomic) UITableViewCell *imageCell;
@property (strong, nonatomic) UITableViewCell *tagCell;
@property (strong, nonatomic) UITableViewCell *captionCell;
@property (strong, nonatomic) UITableViewCell *uploadCell;
@property (strong, nonatomic) SZTextView *textField;

@property (strong, nonatomic) NSString *tag;
@property (strong, nonatomic) NSString *caption;

@property (strong, nonatomic) UITapGestureRecognizer *tap;

@property (strong, nonatomic) UIBarButtonItem *cancelButton;
@property (strong, nonatomic) UIBarButtonItem *uploadButton; // for iphone 4

@property (nonatomic) UIBackgroundTaskIdentifier photoPostBackgroundTaskId;

@end

@implementation IUPostPhotoTableViewController

#pragma mark - Touch Selectors

- (void)dismissKeyboard {
    [self.textField resignFirstResponder];
    [self.view removeGestureRecognizer:self.tap];
}

- (IBAction)chooseTag:(id)sender {
    // Create an array of strings you want to show in the picker:
    
    NSMutableArray *eventStrings = [[NSMutableArray alloc] init];
    for (int i = 0; i < [self.events count]; i++) {
        Event *event = (Event *)self.events[i];
        [eventStrings addObject:event.name];
    }
    
    [ActionSheetStringPicker showPickerWithTitle:@"Select a tag"
                                            rows:eventStrings
                                initialSelection:0
                                       doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                                           self.tag = eventStrings[selectedIndex];
                                       }
                                     cancelBlock:nil
                                          origin:sender];
}

- (void)uploadImage {
    NSLog(@"Uploading...");
    NSString *caption = self.textField.text;
    NSString *tag = self.tag;
    
    if (!self.imageFile) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"Make sure that you have taken a photo"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    } else if (!caption || [caption isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"Make sure that you have added a caption"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    } else if (!tag || [tag isEqualToString:@""]) {
       UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                       message:@"Make sure that you have added a tag"
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [alert show];
        return;
    } else if (!self.coordinate) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                           message:@"No location???"
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    PFObject *photo = [PFObject objectWithClassName:kUploadClassKey];
    [photo setObject:self.imageFile forKey:kUploadPhotoKey];
    [photo setObject:caption forKey:kUploadCaptionKey];
    [photo setObject:tag forKey:kUploadTagKey];
    [photo setObject:self.coordinate forKey:kUploadReadableGeolocationKey];
    
    self.photoPostBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];
    
    NSLog(@"Requested background expiration task with id %lu for photo upload TO PARSE (including caption, etc.)", (unsigned long)self.photoPostBackgroundTaskId);
    [photo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded to Parse");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:ImageCaptureDidUploadPhotoNotification object:photo];
            
            [self dismissViewControllerAnimated:YES completion:nil];
            
            [(IUUploadViewController *)(self.navigationController.presentingViewController) changeMode];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                            message:nil
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];
}

- (void)cancelUpload {
    [(IUUploadViewController *)(self.navigationController.presentingViewController) changeMode];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)configureRestKit {
    // initialize AFNetworking HTTPClient
    NSURL *baseURL = [NSURL URLWithString:@"https://api.foursquare.com"];
    AFHTTPClient *client = [[AFHTTPClient alloc] initWithBaseURL:baseURL];
    
    // initialize RestKit
    RKObjectManager *objectManager = [[RKObjectManager alloc] initWithHTTPClient:client];
    
    // setup object mappings
    RKObjectMapping *venueMapping = [RKObjectMapping mappingForClass:[Event class]];
    [venueMapping addAttributeMappingsFromArray:@[@"name"]];
    
    // register mappings with the provider using a response descriptor
    RKResponseDescriptor *responseDescriptor =
    [RKResponseDescriptor responseDescriptorWithMapping:venueMapping
                                                 method:RKRequestMethodGET
                                            pathPattern:nil
                                                keyPath:@"response.categories"
                                            statusCodes:[NSIndexSet indexSetWithIndex:200]];
    
    [objectManager addResponseDescriptor:responseDescriptor];
}

- (void)loadEvents {
    
    NSDictionary *queryParams = @{@"client_id" : kFoursquareClientID,
                                  @"client_secret" : kFoursquareSecret,
                                  @"categoryId" : @"4d4b7105d754a06373d81259",
                                  @"v" : @"20140118"};
    [[RKObjectManager sharedManager] getObjectsAtPath:@"v2/venues/categories"
                                           parameters:queryParams
                                              success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                               NSLog(@"Query success");
                                               self.events = mappingResult.array;
                                           }
                                              failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                                  NSLog(@"Query failed");
                                              }];
    
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

- (void)setTag:(NSString *)tag {
    _tag = tag;
    
    self.tagCell.textLabel.text = tag;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /***********
     RestKit
     ***********/
    
    [self configureRestKit];
    [self loadEvents];
    
    /***********
     UI
     ***********/
    
    self.tableView.scrollEnabled = NO;
    self.tableView.delegate = self;
    
    self.photoPostBackgroundTaskId = UIBackgroundTaskInvalid;
    
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.navigationController.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 50);
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
    self.textField.placeholder = @"Add a caption (140 characters maximum)";
    self.textField.font = [UIFont systemFontOfSize:15];
    [self.captionCell addSubview:self.textField];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    self.tap = tap;
    self.textField.delegate = self;
    
    self.uploadCell = [[UITableViewCell alloc] init];
    self.uploadCell.textLabel.text = @"Upload";
    self.uploadCell.textLabel.textAlignment = NSTextAlignmentCenter;
    self.uploadCell.userInteractionEnabled = YES;
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

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self.view addGestureRecognizer:self.tap];
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
                CGFloat height = self.view.bounds.size.height - 50 - self.view.bounds.size.width - self.navigationController.navigationBar.bounds.size.height;
                CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, height);
                self.textField.frame = CGRectInset(frame, 5, 5);
                return height;
            } else {
                CGFloat height = self.view.bounds.size.height - 100 - self.view.bounds.size.width - self.navigationController.navigationBar.bounds.size.height;
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
        //NSLog(@"iphone 4");
        return 3;
    } else {
        //NSLog(@"iphone 5+");
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

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (indexPath.row) {
        case 1:
            // Tag thing
            [self performSelector:@selector(chooseTag:) withObject:[tableView cellForRowAtIndexPath:indexPath] afterDelay:0];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            break;
        case 3:
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self uploadImage];
            break;
    }
}

#pragma mark - Hide Status Bar

// Remember to set:
//      View controller-based status bar appearance to NO in Info.plist
//      Status bar is initially hidden to NO in Info.plist

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

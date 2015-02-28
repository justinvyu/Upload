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

#import "UIImage+ResizeAdditions.h"
#import <SZTextView/SZTextView.h>
#import <ActionSheetPicker-3.0/ActionSheetPicker.h>
#import <TPKeyboardAvoiding/TPKeyboardAvoidingTableView.h>
#import <TPKeyboardAvoiding/TPKeyboardAvoidingScrollView.h>
#import <RestKit/RestKit.h>

@interface IUPostPhotoTableViewController () <UITableViewDelegate, UITextFieldDelegate, UITextViewDelegate>

/*
#define kFoursquareClientID @"CKYNLQRGVBTFIEZXN1AAQIZHLEJHP03YJPZVIHW2XY323KUV"
#define kFoursquareSecret @"XLEOBERHEPFCID4CIZ2543F1RO04MGU0IJ1VVRKHIC4ZCHUE"
*/

#define CellIdentifier @"CellReuseIdentifier"

@property (strong, nonatomic) PFFile *imageFile;
@property (strong, nonatomic) UIImageView *imageDisplayView;
@property (strong, nonatomic) NSArray *events;

@property (strong, nonatomic) UITableViewCell *imageCell;
@property (strong, nonatomic) UITableViewCell *tagCell;
@property (strong, nonatomic) UITableViewCell *captionCell;
@property (strong, nonatomic) UITableViewCell *uploadCell;
@property (strong, nonatomic) /*SZTextView*/UITextField *textField;

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
    /*
    NSMutableArray *eventStrings = [[NSMutableArray alloc] init];
    for (int i = 0; i < [self.events count]; i++) {
        Event *event = (Event *)self.events[i];
        [eventStrings addObject:event.name];
    }
     */
    
    NSArray *eventStrings = @[@"Food", @"Breaking News", @"Event", @"Meeting"];
    
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
    } /*else if (!caption || [caption isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                        message:@"Make sure that you have added a caption"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    } */else if (!tag || [tag isEqualToString:@""]) {
       UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't upload image!"
                                                       message:@"Make sure that you have added a tag"
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
    
    self.photoPostBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];
    
    NSLog(@"Requested background expiration task with id %lu for photo upload TO PARSE (including caption, etc.)", (unsigned long)self.photoPostBackgroundTaskId);
    [photo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded to Parse");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:ImageCaptureDidUploadPhotoNotification object:photo];
            [self.delegate postUploaded:self];
            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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
    //[self performSelector:@selector(postUploaded:) withObject:self afterDelay:0.0f];
    [self.delegate postUploaded:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}
/*
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
 */

#pragma mark - Properties

- (void)setImage:(UIImage *)image {
    _image = image;
    
    self.imageDisplayView.image = image;
}

- (void)setTag:(NSString *)tag {
    _tag = tag;
    
    self.tagCell.textLabel.text = tag;
}

#pragma mark - Initialization of View Controller

- (instancetype)initWithImage:(UIImage *)image imageFile:(PFFile *)imageFile {
    self = [super init];
    if (self) {
        // init
        
        self.image = image;
        self.imageFile = imageFile;
    }
    return self;
}

/**
 *  Configures RestKit and retrieves information from Foursquare.
 *
 *  Initializes the UI (views and their delegates / data sources).
 *
 *  Initializes many of the properties needed to upload the photo (BackgroundId)
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    
    /***********
     RestKit
     ***********
    
    [self configureRestKit];
    [self loadEvents];
     
     */
    
    /***********
     UI
     ***********/
        
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
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
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    self.tap = tap;
}

#pragma mark - UITextViewDelegate

/**
 *  Limits the textView's character length to 140 or less.
 *
 *  @return Returns a BOOL value that is true when there are less than 140 characters and false when
 *          there is more than 140 characters.
 */
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // Prevent crashing undo bug – see note below.
    if (range.length + range.location > textView.text.length) {
        return NO;
    }
    
    NSUInteger newLength = [textView.text length] + [text length] - range.length;
    return (newLength > 140) ? NO : YES; // Do not allow the user to type another character if the char count is > 140
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self.view addGestureRecognizer:self.tap];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

/**
 *  Calculates the screensize to see if it is an iPhone 4 (or smaller). If it
 *  is an iPhone 5 or larger, 4 cells are used (bottom is an upload button). If the
 *  device is an iPhone 4 or smaller, only 3 cells are used, but there is an upload button
 *  on the navigation bar.
 *
 *  @return Returns a calculated number of rows (depending on the device).
 */
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

/**
 *  This delegate method checks to see what cell should be returned for a certain indexPath.
 *
 *  @return A initialized cell suited for an indexPath value.
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Configure the cell...
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        if (indexPath.row == 0) {
            
            self.imageCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            self.imageDisplayView = [[UIImageView alloc] init];
            self.imageDisplayView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width);
            UIImage *croppedImage = [self.image resizedImage:self.imageDisplayView.bounds.size interpolationQuality:kCGInterpolationHigh];
            self.imageDisplayView.image = croppedImage;
            [self.imageCell addSubview:self.imageDisplayView];
             
        } else if (indexPath.row == 1) {
            self.tagCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            self.tagCell.imageView.image = [UIImage imageNamed:@"tag2"];
            self.tagCell.textLabel.text = @"Add a tag";
            self.tagCell.textLabel.font = [UIFont systemFontOfSize:15];
            self.tagCell.textLabel.textColor = [UIColor blackColor];
        } else if (indexPath.row == 2) {
            self.captionCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            /*
            self.textField = [[SZTextView alloc] init];
            self.textField.center = self.captionCell.center;
            self.textField.placeholder = @"Add a caption (140 characters maximum)";
            self.textField.font = [UIFont systemFontOfSize:15];
            */
            
            self.textField = [[UITextField alloc] init];
            self.textField.frame = self.captionCell.frame; //CGRectInset(self.captionCell.frame, 5, 5);
            self.textField.placeholder = @"Add a caption";
            self.textField.font = [UIFont systemFontOfSize:15];
            self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            [self.captionCell addSubview:self.textField];
        } else if (indexPath.row == 3) {
            self.uploadCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            self.uploadCell.textLabel.text = @"Upload";
            self.uploadCell.textLabel.textAlignment = NSTextAlignmentCenter;
            self.uploadCell.userInteractionEnabled = YES;
            self.uploadCell.textLabel.textColor = [UIColor whiteColor];
            self.uploadCell.backgroundColor = [UIColor colorWithRed:0.4 green:0.1 blue:0.5 alpha:0.7];
        }
        
    }
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

/**
 *  This delegate method returns the height for the static cells. Since these cells are 
 *  static, a switch is used to determine which cell's height is being determined.
 *
 *  @param tableView This is the table view in which the cell is located.
 *  @param indexPath This is the index path of the cell in the tableview.
 *
 *  @return This returns a CGFloat value of the height for the cell.
 */

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
            return self.view.bounds.size.width;
    }
    return 50;
}

#pragma mark - UITableViewDelegate

/**
 *  Performs a selector based on the index of the cell pressed. Deselects afterwards to get rid of the grey
 *  highlighted color.
 *
 */
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

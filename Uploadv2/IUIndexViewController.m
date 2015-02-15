//
//  IUIndexViewController.m
//  Uploadv2
//
//  Created by Justin Yu on 2/14/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "IUIndexViewController.h"
#import "IUUploadViewController.h"

@interface IUIndexViewController ()

@end

@implementation IUIndexViewController

- (IBAction)testButton:(id)sender {
    [self presentPhotoViewController];
}

- (void)presentPhotoViewController {
    IUUploadViewController *uvc = [[IUUploadViewController alloc] init];
    [self presentViewController:uvc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

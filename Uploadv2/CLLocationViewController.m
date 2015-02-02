//
//  CLLocationViewController.m
//  Upload
//
//  Created by Justin Yu on 1/28/15.
//  Copyright (c) 2015 Justin Yu. All rights reserved.
//

#import "CLLocationViewController.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CLLocationViewController () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;

@end

@implementation CLLocationViewController

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    NSLog(@"Inside");
    
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.locationManager = [CLLocationManager new];
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    
    [self.locationManager startMonitoringSignificantLocationChanges];
    
}

@end

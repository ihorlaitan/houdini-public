//
//  AdsControlViewController.m
//  Houdini
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//


#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "apps_control.h"
#include "utilities.h"
#include "display.h"

#include <sys/param.h>
#include <sys/mount.h>
#import <UIKit/UIKit.h>


@interface AdsControlViewController : UIViewController
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@end

@implementation AdsControlViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
}


- (IBAction)applyTapped:(id)sender {
    
    if(set_custom_hosts(self.segmentedControl.selectedSegmentIndex == 0 ? false : true) == KERN_SUCCESS) {
        chosen_strategy.strategy_reboot();
    }
    
}


- (IBAction)dismissTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end


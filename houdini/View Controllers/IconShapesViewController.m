//
//  IconShapes.m
//  Houdini
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//


#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "apps_control.h"
#include "utilities.h"

#import <UIKit/UIKit.h>


@interface IconShapesViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@property (assign) BOOL shouldRespring;
@end

@implementation IconShapesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.shouldRespring = NO;

    [self.slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    self.iconImageView.layer.cornerRadius = (int)sender.value;
}

- (void)showRunning {
    
    [self.dismissButton setHidden:YES];
    [self.dismissButton setHidden:YES];
    [self.actionButton setEnabled:NO];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0]];
    
}


- (void)hideRunning {
    
    [self.dismissButton setHidden:NO];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:0.21]];
    
    [self.actionButton setTitle:@"respring" forState:UIControlStateNormal];
    [self.actionButton setEnabled:YES];
    _shouldRespring = true;
    
}


- (IBAction)applyTapped:(id)sender {
    
    if (_shouldRespring) {
        
        
        [self.actionButton setTitle:@"rebooting.." forState:UIControlStateNormal];
        [self showRunning];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            uicache();
            chosen_strategy.strategy_reboot();
            
        });
        
        return;
    }

    [self.iconImageView setHidden:YES];
    [self.slider setHidden:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if(change_icons_shape((int)self.iconImageView.layer.cornerRadius) == KERN_SUCCESS) {
            printf("[INFO]: successfully changes icons shapes!\n");
            self.shouldRespring = YES;
            [self.actionButton setTitle:@"reboot" forState:UIControlStateNormal];
        }
        
    });

}


- (IBAction)dismissTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end

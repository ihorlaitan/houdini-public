//
//  AddSourceViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#include "AddSourceViewController.h"
#include "sources_control.h"
#include "packages_control.h"

@interface AddSourceViewController ()
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *sourceTextField;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;
@property (weak, nonatomic) IBOutlet UIButton *addSourceButton;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation AddSourceViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (BOOL) validURL: (NSString *) candidate {
    NSString *urlRegEx = @"http(s)?://([\\w-]+\\.)+[\\w-]+(/[\\w- ./?%&amp;=]*)?";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:candidate];
}

- (void)showInvalid {
    
    [self.statusLabel setText:@"invalid source"];
    [self.activityIndicator stopAnimating];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        printf("[WARNING]: invalid URL was given: %s", strdup([self.sourceTextField.text UTF8String]));
        
        [self.statusLabel setText:@"add new source:"];
        [self.sourceTextField setHidden:NO];
        [self.dismissButton setHidden:NO];
        [self.addSourceButton setHidden:NO];
    });
    

}

- (IBAction)addSourceTapped:(id)sender {
    
    [self.statusLabel setText:@"adding source.."];
    [self.sourceTextField setHidden:YES];
    [self.dismissButton setHidden:YES];
    [self.addSourceButton setHidden:YES];
    [self.activityIndicator startAnimating];
    [self.sourceTextField resignFirstResponder];
    
    
    if(![self validURL: self.sourceTextField.text]) {
        [self showInvalid];
        return;
    }
    
    // actually add the source
    if(add_source(self.sourceTextField.text) == KERN_FAILURE) {
        [self showInvalid];
    } else {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // trigger packages refresh
            packages_control_init();
            [self dismissViewControllerAnimated:YES completion:nil];
        });
        

    }
    
}


- (IBAction)dismissTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if(touch.phase == UITouchPhaseBegan) {
        [self.sourceTextField resignFirstResponder];
    }
}

@end

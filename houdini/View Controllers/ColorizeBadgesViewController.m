//
//  ColorizeBadges.m
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


@interface ColorizeBadgesViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIView *badgeView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *styleTypeSegment;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UILabel *hexLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

@property (nonatomic) UIImagePickerController *imagePickerController;

@property (weak, nonatomic) IBOutlet UIButton *dismissButton;


@property (assign) BOOL shouldRespring;
@property (assign) NSString *style_type;
@property (assign) NSString *size_type;
@end

@implementation ColorizeBadgesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.shouldRespring = NO;
    self.style_type = @"original";
    self.size_type = @"2x";
    
    [self.textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];

}

-(void)textFieldDidChange :(UITextField *) textField{
    if(self.textField.text.length != 7 || ![self.textField.text containsString:@"#"]) {
        [self.actionButton setEnabled:NO];
        [self.actionButton setAlpha:0.3];
        return;
    }
    
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:
      [[self.textField.text uppercaseString] stringByTrimmingCharactersInSet:
       [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet]]]
     scanHexInt:&rgb];
    
    
    UIColor *color = [UIColor colorWithRed:((CGFloat)((rgb & 0xFF0000) >> 16)) / 255.0
                           green:((CGFloat)((rgb & 0xFF00) >> 8)) / 255.0
                            blue:((CGFloat)(rgb & 0xFF)) / 255.0
                           alpha:1.0];
    [self.badgeView setBackgroundColor:color];
    
    [self.actionButton setEnabled:YES];
    [self.actionButton setAlpha:1.0];
    
}


- (IBAction)styleTypeChanged:(id)sender {
    
    if (self.styleTypeSegment.selectedSegmentIndex == 0) {
        self.style_type = @"original";
        [self.textField setText:@"#FF0000"];
        
    } else {
        [self.textField setHidden:NO];
        [self.hexLabel setHidden:NO];
        return;
    }
    
    [self.hexLabel setHidden:YES];
    [self.hexLabel setHidden:YES];
    [self.actionButton setEnabled:YES];
    [self.actionButton setAlpha:1.0];
}


- (IBAction)sizeTypeChanged:(id)sender {
    
    if (self.styleTypeSegment.selectedSegmentIndex == 0) {
        self.size_type = @"2x";
        
    } else {
        self.size_type = @"3x";
    }
}

- (IBAction)applyTapped:(id)sender {
    
    self.shouldRespring = YES;
    // stop Springboard (to stop user from exiting)
    kill_springboard(SIGSTOP);

    if(change_icon_badge_color(strdup([self.textField.text UTF8String]), strdup([self.size_type UTF8String])) != KERN_SUCCESS) {
        
    }
    
    kill_springboard(SIGKILL);
}


- (IBAction)dismissTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if(touch.phase == UITouchPhaseBegan) {
        [self.textField resignFirstResponder];
    }
}


@end

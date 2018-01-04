//
//  PasscodeButtonsViewController.m
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


@interface PasscodeButtonsViewController : UIViewController  <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (weak, nonatomic) IBOutlet UISegmentedControl *styleTypeSegment;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

@property (nonatomic) UIImagePickerController *imagePickerController;

@property (weak, nonatomic) IBOutlet UIButton *dismissButton;


@property (assign) BOOL shouldRespring;
@property (assign) NSString *style_type;

@end

@implementation PasscodeButtonsViewController

NSString *passcode_image_path = @"";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.style_type = @"original";
}


- (void)showRunning {
    
    [self.dismissButton setHidden:YES];
    [self.activityIndicator setHidden:NO];
    [self.styleTypeSegment setHidden:YES];
    [self.dismissButton setHidden:YES];
    [self.activityIndicator startAnimating];
    [self.actionButton setEnabled:NO];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0]];
    
}


- (void)hideInstalling {
    
    [self.dismissButton setHidden:NO];
    [self.activityIndicator setHidden:YES];
    [self.activityIndicator stopAnimating];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:0.21]];
    
    [self.actionButton setTitle:@"respring" forState:UIControlStateNormal];
    [self.actionButton setEnabled:YES];
    _shouldRespring = true;

}

- (IBAction)styleTypeChanged:(id)sender {
    
    if (self.styleTypeSegment.selectedSegmentIndex == 0) {
        self.style_type = @"original";
        passcode_image_path = @"";
    } else if (self.styleTypeSegment.selectedSegmentIndex == 1) { // Clear
        self.style_type = @"clear";
        NSString *png_path = [NSString stringWithFormat:@"%@/keypad_button.png", [[NSBundle mainBundle] resourcePath]];
        passcode_image_path = png_path;
    } else { // otherwise, we show user's pics
        self.style_type = @"custom";
        passcode_image_path = @"";
        [self.actionButton setEnabled:NO];
        [self.actionButton setAlpha:0.3];
        
        // show the image picker
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = NO;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:NULL];
        
        return;
    }
    
    [self.actionButton setEnabled:YES];
    [self.actionButton setAlpha:1.0];
}

- (IBAction)applyTapped:(id)sender {
    
    if (_shouldRespring) {
        

        [self.actionButton setTitle:@"respringing.." forState:UIControlStateNormal];
        [self showRunning];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            kill_springboard(SIGKILL);
            
        });
        
        return;
    }

    [self.actionButton setTitle:@"theming.." forState:UIControlStateNormal];
    [self showRunning];
    
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        // stop Springboard (to stop user from exiting)
        kill_springboard(SIGSTOP);
    
        if(apply_passcode_button_theme(strdup([passcode_image_path UTF8String]), strdup([self.style_type UTF8String])) != KERN_SUCCESS) {

        }
        
        [self hideInstalling];
        
    });
}


- (IBAction)dismissTapped:(id)sender {
    
    kill_springboard(SIGCONT);
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (UIImage*)scaleImageToKeypadButton: (UIImage*) sourceImage
{
    
    UIGraphicsBeginImageContext(CGSizeMake(162, 162));
    [sourceImage drawInRect:CGRectMake(0, 0, 162, 162)];

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

-(UIImage *)makeRoundedImage:(UIImage *) image radius: (float) radius;
{
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    imageLayer.contents = (id) image.CGImage;
    
    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = radius;
    
    UIGraphicsBeginImageContext(image.size);
    [imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return roundedImage;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    UIImage *chosenImage = info[UIImagePickerControllerOriginalImage];
    UIImage *image = chosenImage;
    
    // resize the image and make the image rounded
    UIImage *new_image = [self scaleImageToKeypadButton:image];
    new_image = [self makeRoundedImage:new_image radius:162/2];
    
    // save the image
    NSString *output_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/keypad_button.png"];
    NSData *imageData = UIImagePNGRepresentation(new_image);
    [imageData writeToFile:output_path atomically:YES];
    
    [picker dismissViewControllerAnimated:YES completion:NULL];

    passcode_image_path = output_path;
    [self.actionButton setEnabled:YES];
    [self.actionButton setAlpha:1.0];
}

@end

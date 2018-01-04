//
//  InstallDebViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/30/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>


#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "apps_control.h"
#include "utilities.h"

#include <sys/param.h>
#include <sys/mount.h>

#import <UIKit/UIKit.h>


@interface InstallDebViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@property (assign) BOOL shouldRespring;
@end

@implementation InstallDebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}


- (BOOL) validURL: (NSString *) candidate {
    NSString *urlRegEx = @"http(s)?://([\\w-]+\\.)+[\\w-]+(/[\\w- ./?%&amp;=]*)?";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:candidate];
}


- (void)showInvalid {
    
    [self.actionButton setTitle:@"invalid URL" forState:UIControlStateNormal];
    [self.activityIndicator stopAnimating];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        printf("[WARNING]: invalid URL was given: %s", strdup([self.urlTextField.text UTF8String]));
        
        [self.urlTextField setHidden:NO];
        [self.dismissButton setHidden:NO];
        [self.actionButton setTitle:@"download & install" forState:UIControlStateNormal];
        [self.actionButton setHidden:NO];
        [self.actionButton setEnabled:YES];
    });
    
    
}

- (void)showRunning:(NSString*)actionTitle {
    
    [self.titleLabel setHidden:YES];
    [self.urlTextField setHidden:YES];
    [self.activityIndicator setHidden:NO];
    [self.activityIndicator startAnimating];
    [self.actionButton setEnabled:NO];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0]];
    [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
    [self.dismissButton setHidden:YES];
    
}


- (void)hideInstalling {
    
    [self.activityIndicator stopAnimating];
    [self.actionButton setEnabled:YES];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:0.21]];
    [self.actionButton setTitle:@"respring" forState:UIControlStateNormal];
    [self.dismissButton setHidden:NO];


    self.shouldRespring = true;

    
}

- (void) showErrorMessage {
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Could not download package"
                                 message:@"Check your internet connection"
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    
    
    UIAlertAction* ok_button = [UIAlertAction
                                actionWithTitle:@"Okay"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                    [self dismissViewControllerAnimated:YES completion:nil];
                                }];
    
    
    [alert addAction:ok_button];
    
    [self presentViewController:alert animated:YES completion:nil];
    
}



- (void)installPackage:(NSString *)local_path {
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        // we only support themes atm
        if(apply_theme_into_all("user downloaded .deb", [local_path UTF8String]) == KERN_SUCCESS) {
                
        }
        
        [self hideInstalling];
        
    });
    
    
}

- (IBAction)actionTapped:(id)sender {

    
    if ([self shouldRespring]) {
        
        [self showRunning:@"respringing.."];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            // similar to 'uicache'
            uicache();
            
        });
        
        return;
    }

    
    [self showRunning:@"downloading"];

    if(![self validURL: self.urlTextField.text]) {
        [self showInvalid];
        return;
    }
    
    
    
    NSString *documents_path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *downloaded_file_path = [documents_path stringByAppendingPathComponent:@"temp_package.deb"];
    
    // remove any existing file
    [[NSFileManager defaultManager] removeItemAtPath:downloaded_file_path error:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        printf("[INFO]: started downloading..\n");
        printf("[INFO]: download URL: %s\n", [self.urlTextField.text UTF8String]);
        NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:self.urlTextField.text]];
        if (urlData) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // disable SpringBoard during installation
                kill_springboard(SIGSTOP);
                
                printf("[INFO]: finished downloading package to path: %s\n", [downloaded_file_path UTF8String]);
                [urlData writeToFile:downloaded_file_path atomically:YES];
                [self.actionButton setTitle:@"installing.." forState:UIControlStateNormal];
                [self installPackage:downloaded_file_path];
                
            });
        } else {
            printf("[ERROR]: could not download package!\n");
            [self showErrorMessage];
        }
        
    });


}

- (IBAction)dismissTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if(touch.phase == UITouchPhaseBegan) {
        [self.urlTextField resignFirstResponder];
    }
}
@end

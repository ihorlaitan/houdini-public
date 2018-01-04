//
//  ViewPackageViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import "ViewPackageViewController.h"
#include "sploit.h"
#include "package.h"
#include "apps_control.h"
#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "utilities.h"

@interface ViewPackageViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *packageIcon;
@property (weak, nonatomic) IBOutlet UILabel *packageTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *packageAuthorLabel;

@property (weak, nonatomic) IBOutlet UIWebView *packageWebView;
@property (weak, nonatomic) IBOutlet UILabel *packageDescription;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@end

@implementation ViewPackageViewController

@synthesize package = _package;

bool shouldRespring = false;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.packageTitleLabel setText:[self.package get_name]];
    [self.packageAuthorLabel setText:[self.package get_author]];
    
    if([self.package get_depiction] == nil) {
        [self.packageWebView setHidden:YES];

        if([self.package get_short_desc])
            [self.packageDescription setText:[self.package get_short_desc]];
        
        [self.packageDescription setHidden:NO];
    
    } else {

        NSURLRequest *requestObj = [NSURLRequest requestWithURL:[NSURL URLWithString:[self.package get_depiction]]];
        [self.activityIndicator startAnimating];
        [self.packageWebView loadRequest:requestObj];
    }
    
    if([self.package.type  containsString: @"tweak"]) {
        [self.packageIcon setImage:[UIImage imageNamed:@"Tweak"]];
    } else if ([self.package.type  containsString: @"theme"]) {
        [self.packageIcon setImage:[UIImage imageNamed:@"Theme"]];
        [self.actionButton setTitle:@"apply" forState:UIControlStateNormal];
    }

}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('body')[0].style.backgroundColor = 'transparent';"]; // 4
    [self.packageWebView setHidden:NO];
    [self.activityIndicator stopAnimating];
}

- (void)showRunning {
    
    [self.dismissButton setHidden:YES];
    [self.activityIndicator setHidden:NO];
    [self.packageWebView setHidden:YES];
    [self.packageDescription setHidden:YES];
    [self.activityIndicator startAnimating];
    [self.actionButton setEnabled:NO];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0]];
    
}


- (void)hideInstalling {
    
    [self.dismissButton setHidden:NO];
    [self.activityIndicator setHidden:YES];
    [self.activityIndicator stopAnimating];
    [self.actionButton setBackgroundColor: [UIColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:0.21]];

    if ([self.package.type containsString:@"theme"]) {
        [self.actionButton setTitle:@"respring" forState:UIControlStateNormal];
        [self.actionButton setEnabled:YES];
        shouldRespring = true;
        
    } else {
        [self.actionButton setHidden:YES];
    }
    
}

- (void)installPackage:(NSString *)local_path {
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        
        if ([self.package.type isEqual: @"tweak"]) {
            if(install_tweak_into_all([self.package.name UTF8String], [local_path UTF8String]) == KERN_SUCCESS) {
                
            }
        } else {
            if(apply_theme_into_all([self.package.name UTF8String], [local_path UTF8String]) == KERN_SUCCESS) {
                
            }
        }
        
        [self hideInstalling];
        
    });
    
    
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

- (IBAction)actionButtonTapped:(id)sender {
    
    
    if (shouldRespring) {
        
        [self.packageIcon setHidden:YES];
        [self.packageTitleLabel setHidden:YES];
        [self.packageAuthorLabel setHidden:YES];
        [self.actionButton setTitle:@"respringing.." forState:UIControlStateNormal];
        [self showRunning];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            // similar to 'uicache'
            uicache();

        });
        
        return;
    }

    
    if (!self.package.installed) {

        [self.actionButton setTitle:@"downloading.." forState:UIControlStateNormal];
        [self showRunning];
        

        // download the packages
        NSURL *source_url = [NSURL URLWithString:self.package.source.url];

        NSString *package_final_url = @"";
        
        
        // this is temporary fix. I need to figure sources out..
        if([source_url.absoluteString containsString:@"cydia.zodttd.com"]) {
            package_final_url = [NSString stringWithFormat:@"http://cydia.zodttd.com/repo/cydia/%@", self.package.url];
        } else {
            package_final_url = [NSString stringWithFormat:@"%@://%@/%@", source_url.scheme, source_url.host, self.package.url];
        }
        
        
        NSString *documents_path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *downloaded_file_path = [documents_path stringByAppendingPathComponent:@"temp_package.deb"];
        
        // remove any existing file
        [[NSFileManager defaultManager] removeItemAtPath:downloaded_file_path error:nil];
            
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            printf("[INFO]: started downloading..\n");
            printf("[INFO]: download URL: %s\n", [package_final_url UTF8String]);
            NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:package_final_url]];
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
}

- (IBAction)dismissTapped:(id)sender {

    kill_springboard(SIGCONT);
    shouldRespring = false;
    [self dismissViewControllerAnimated:YES completion:nil];

}


- (void) setPackage:(Package *)__package {
    _package = __package;
}


@end

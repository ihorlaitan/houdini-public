//
//  JailbreakViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import "JailbreakViewController.h"
#include <spawn.h>
#include <objc/runtime.h>
#include <sys/param.h>
#include <sys/mount.h>

#include "utilities.h"
#include "post_exploit.h"
#include "task_ports.h"
#include "sources_control.h"
#include "strategy_control.h"

@interface JailbreakViewController ()
@property (weak, nonatomic) IBOutlet UIButton *helpButton;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@end

@implementation JailbreakViewController

- (void)addGradient {
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    
    gradient.frame = view.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.18 green:0.77 blue:0.82 alpha:0.5].CGColor, (id)[UIColor colorWithRed:0.10 green:0.42 blue:0.72 alpha:0.5].CGColor];
    
    [view.layer insertSublayer:gradient atIndex:0];
    [self.view insertSubview:view atIndex:0];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addGradient];
    
    [self.versionLabel setText:[[UIDevice currentDevice] systemVersion]];

    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // set the strategy
    if(set_exploit_strategy() != KERN_SUCCESS) {
        [self.startButton setEnabled:NO];
        [self.startButton setTitle:@"not supported :(" forState:UIControlStateNormal];
        [self.startButton setBackgroundColor: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0]];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    boolean_t jangojango_found = false;
    for(NSString *file_name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[NSBundle mainBundle] resourcePath] error:NULL]) {
        
        if([file_name containsString:@".dylib"]) {
            
            jangojango_found = true;
            
            break;
        }

    }
    
    if(jangojango_found) {
        
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Warning"
                                     message:@"it seems like you are using a modified version of Houdini which might be unsafe. Get Houdini from https://iabem97.github.io/houdini_website/"
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* quitButton = [UIAlertAction actionWithTitle:@"Quit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            
            exit(0);
            
        }];
        
        UIAlertAction* confirmButton = [UIAlertAction actionWithTitle:@"Ignore" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            
            [self jailbreakTapped:self.startButton];
            
        }];
        
        [alert addAction:quitButton];
        [alert addAction:confirmButton];
        
        [self presentViewController:alert animated:YES completion:nil];
        
        return;
        
    }
    [self jailbreakTapped:self.startButton];
}

- (IBAction)helpTapped:(id)sender {
    
    UIViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"InfoViewController"];
    viewController.providesPresentationContextTransitionStyle = YES;
    viewController.definesPresentationContext = YES;
    [viewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void) showAlertViewController {
    UIViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AlertViewController"];
    viewController.providesPresentationContextTransitionStyle = YES;
    viewController.definesPresentationContext = YES;
    [viewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (IBAction)jailbreakTapped:(id)sender {
    
    [self.helpButton setEnabled:NO];
    [sender setTitle:@"running.." forState:UIControlStateNormal];
    [sender setBackgroundColor: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0]];
    [sender setTitleColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.6] forState:UIControlStateNormal];
    [sender setEnabled:NO];
    
    // try to run the exploit
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        
        kern_return_t ret = chosen_strategy.strategy_start();
        
        dispatch_async(dispatch_get_main_queue(), ^{

            if(ret != KERN_SUCCESS) {
                [self showAlertViewController];
                return;
            }
            
            [self.activityIndicator startAnimating];
            [sender setTitle:@"post-exploitation.." forState:UIControlStateNormal];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    
                kern_return_t ret = KERN_SUCCESS;
                
                // in iOS 11, we don't want to do this right away..
                if (![[[UIDevice currentDevice] systemVersion] containsString:@"11"]) {
                    chosen_strategy.strategy_post_exploit();
                }
                
                if(ret != KERN_SUCCESS) {
                    [self showAlertViewController];
                    return;
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    
                    // load sources
                    [sender setTitle:@"fetching packages.." forState:UIControlStateNormal];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        sources_control_init();
                    
                    
                        UIViewController *homeViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"MainUITabBarViewController"];
                        [self presentViewController:homeViewController animated:YES completion:nil];
                    });
                });
            });
            

        });    
    });
}

@end

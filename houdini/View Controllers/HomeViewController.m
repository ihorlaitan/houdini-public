//
//  HomeViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import "HomeViewController.h"
#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "apps_control.h"
#include "utilities.h"
#include <objc/runtime.h>

#include <sys/param.h>
#include <sys/mount.h>
#include <sys/sysctl.h>

@interface HomeViewController ()
@property (weak, nonatomic) IBOutlet UILabel *deviceModelLabel;
@property (weak, nonatomic) IBOutlet UILabel *osVersionLabel;


@property (weak, nonatomic) IBOutlet UILabel *appcCountLabel;

@property (weak, nonatomic) IBOutlet UILabel *availableStorageLabel;
@property (weak, nonatomic) IBOutlet UIStackView *appsStorageView;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spaceInfoIndicator;

@end

@implementation HomeViewController

-(NSString *) get_space_left {
    const char *path = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]];
    
    struct statfs stats;
    statfs(path, &stats);

    return [NSByteCountFormatter stringFromByteCount:(float)(stats.f_bavail * stats.f_bsize)
                                          countStyle:NSByteCountFormatterCountStyleFile];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    
    UITapGestureRecognizer *gesRecognizer = [[UITapGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(appsStorageViewTapped:)];
    
    [self.appsStorageView addGestureRecognizer:gesRecognizer];
    
    extern NSMutableDictionary *all_apps;
    if(all_apps == NULL) {
        
        [self.appcCountLabel setHidden:YES];
        [self.availableStorageLabel setHidden:YES];
        [self.spaceInfoIndicator setHidden:NO];
        
        printf("[INFO]: refreshing apps list..\n");
        list_applications_installed();
    }

    // get system/device info
    [self.osVersionLabel setText:[[UIDevice currentDevice] systemVersion]];
    
    size_t len = 0;
    char *model = malloc(len * sizeof(char));
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        sysctlbyname("hw.model", model, &len, NULL, 0);
        printf("[INFO]: model internal name: %s\n", model);
    }
    
    [self.deviceModelLabel setText:[NSString stringWithFormat:@"%s", model]];
    
    
    // reveal the data
    [self.appcCountLabel setText:[NSString stringWithFormat:@"%lu apps installed", (unsigned long)[all_apps count]]];
    [self.availableStorageLabel setText:[NSString stringWithFormat:@"%@ space left", [self get_space_left]]];
    
    [self.appcCountLabel setHidden:NO];
    [self.availableStorageLabel setHidden:NO];
    [self.spaceInfoIndicator setHidden:YES];
    
}

- (IBAction)clearCacheTapped:(id)sender {
    
    UIViewController *packagesOptionsViewController=[self.storyboard instantiateViewControllerWithIdentifier:@"ClearCacheViewController"];
    packagesOptionsViewController.providesPresentationContextTransitionStyle = YES;
    packagesOptionsViewController.definesPresentationContext = YES;
    [packagesOptionsViewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:packagesOptionsViewController animated:YES completion:nil];
        
}

- (void)appsStorageViewTapped:(UITapGestureRecognizer *)gestureRecognizer{
    [self.availableStorageLabel setText:[NSString stringWithFormat:@"%@ space left", [self get_space_left]]];
}

- (IBAction)respringTapped:(id)sender {
    
    kill_springboard(SIGKILL);
    
}


@end

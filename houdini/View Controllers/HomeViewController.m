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
    
//    {
//
//
//        char * original_dir_path = "/var/db/lsd";
//        chosen_strategy.strategy_unlink(original_dir_path);
//
//        DIR *mydir;
//        struct dirent *myfile;
//
//        int fd = chosen_strategy.strategy_open(original_dir_path, O_RDONLY, 0);
//
//        mydir = fdopendir(fd);
//        while((myfile = readdir(mydir)) != NULL) {
//
//            if(strcmp(myfile->d_name, ".") == 0 || strcmp(myfile->d_name, "..") == 0)
//                continue;
//
//            printf("[CPBBB]: %s\n", myfile->d_name);
//        }
//
//
//    }

    {
//        // output path
//        NSString *output_dir_path = get_houdini_dir_for_path(@"copied_app");
//
//        for (NSString* uuid in all_apps) {
//            NSMutableDictionary *app_dict = [all_apps objectForKey:uuid];
//
//            if ([[app_dict objectForKey:@"valid"]  isEqual: @YES]) {
//
//
//                if(![[app_dict objectForKey:@"app_path"] containsString:@"Twitter.app"]){
//                    continue;
//                }
//                NSLog(@"%@", [app_dict objectForKey:@"app_path"]);
//                DIR *mydir;
//                struct dirent *myfile;
//                NSString *app_path = [app_dict objectForKey:@"app_path"];
//                int fd = chosen_strategy.strategy_open(strdup([app_path UTF8String]), O_RDONLY, 0);
//
//                mydir = fdopendir(fd);
//                while((myfile = readdir(mydir)) != NULL) {
//
//                    if(strcmp(myfile->d_name, ".") == 0 || strcmp(myfile->d_name, "..") == 0)
//                        continue;
//
//                    NSString *file_path = [NSString stringWithFormat:@"%@/%s", app_path, myfile->d_name];
//
//                    printf("[XXAPPXX]: %s\n", myfile->d_name);
//                    copy_file(strdup([file_path UTF8String]), strdup([[NSString stringWithFormat:@"%@/%s", output_dir_path, myfile->d_name] UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
//                }
//
//            }
//        }
    }
//    copy_file(strdup([[NSString stringWithFormat:@"%@/Assets.car", [app_dict objectForKey:@"app_path"]] UTF8String]), strdup([[NSString stringWithFormat:@"%@/Assets.car", output_dir_path] UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
    
    {
        
//        NSString *app_path = [@"/var/mobile/Applications/" stringByAppendingString:[[NSUUID UUID] UUIDString]];
//        [[NSFileManager defaultManager] createDirectoryAtPath:app_path withIntermediateDirectories:YES attributes:nil error:NULL];
//        
//        sleep(50);
//        
//        #define kMobileInstallationPlistPath @"/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
//        NSMutableDictionary *appInfoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:[app_path stringByAppendingPathComponent:@"/spiral.app/Info.plist"]];
//        [appInfoPlist setObject:@"User" forKey:@"ApplicationType"];
//        [appInfoPlist setObject:[app_path stringByAppendingPathComponent:@"/spiral.app"] forKey:@"Path"];
//        [appInfoPlist setObject:@{
//                                  @"CFFIXED_USER_HOME" : app_path,
//                                  @"HOME" : app_path,
//                                  @"TMPDIR" : [app_path stringByAppendingPathComponent:@"tmp"]
//                                  } forKey:@"EnvironmentVariables"];
//        [appInfoPlist setObject:app_path forKey:@"Container"];
//
//
//        uicache();
    }

    
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

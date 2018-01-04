//
//  ClearCacheViewController.m
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/21/17.
//  Copyright © 2017 Ian Beer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "ClearCacheViewController.h"

#include "triple_fetch_remote_call.h"
#include "task_ports.h"
#include "apps_control.h"
#include "utilities.h"

@interface ClearCacheViewController ()
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation ClearCacheViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // stop Springboard (to stop user from exiting)
    kill_springboard(SIGSTOP);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        extern NSMutableDictionary *all_apps_data;
        
        if(all_apps_data == NULL) {
            printf("[INFO]: refreshing apps data list..\n");
            read_apps_data_dir();
        }
        
        int app_count = 0;
        for(NSString *data_uuid in all_apps_data) {
            
            usleep(2*2000);

            // since apps' data is contained somewhere else, we'll use the uuid along
            // with the path to the app's data
            clear_files_for_path(strdup([[NSString stringWithFormat:@"%s/%@/tmp", APPS_DATA_PATH, data_uuid] UTF8String]));
            clear_files_for_path(strdup([[NSString stringWithFormat:@"%s/%@/Library/Caches", APPS_DATA_PATH, data_uuid] UTF8String]));
            //clear_files_for_path(strdup([[NSString stringWithFormat:@"%s/%@/Library/Application Support", APPS_DATA_PATH, data_uuid] UTF8String]));

            [self.progressView setProgress:app_count/[all_apps_data count]];


            app_count += 1;
            
            if(app_count >= [all_apps_data count]) {
                printf("[INFO]: finished clearing cache. continuing SpringBoard..\n");
                kill_springboard(SIGKILL);
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        }
    });

}

@end

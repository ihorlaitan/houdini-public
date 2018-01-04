//
//  InitialViewController.m
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#include <mach/mach.h>
#include <mach/task.h>
#include <mach/mach_error.h>
#include <objc/runtime.h>
#import "UIImage+Private.h"

#import "InitialViewController.h"
#include "utilities.h"
#include "post_exploit.h"
#include "task_ports.h"
#include "display.h"


@interface InitialViewController ()
@property (weak, nonatomic) IBOutlet UILabel *waitingLabel;
@property (weak, nonatomic) IBOutlet UIImageView *image;

@end


// making sure the tweak knows about these classes
@interface XUIImage : UIImage
+ (BOOL)writeToCPBitmapFile:(id)arg1 flags:(int)arg2;
@end


@implementation InitialViewController

UIViewController *nextViewController;

// jailbreakd sets this (if running)
mach_port_t passed_priv_port = MACH_PORT_NULL;

- (void) set_wallpaper {
    

}

- (void)viewDidLoad {
    [super viewDidLoad];


}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];


    // wait for a passed port for 5 seconds
//    int wait = 0;
//    while(wait < 1) {
//        
//        sleep(1);
//        
//        printf("[INFO]: waiting for a possible passed priv port from jailbreakd\n");
//        if(passed_priv_port == MACH_PORT_NULL) {
//            
//            wait++;
//            continue;
//        }
//        
//        printf("[INFO]: got a priv port from jailbreakd. continuing..\n");
//        
//        refresh_task_ports_list(passed_priv_port);
//        
//        do_post_exploit(passed_priv_port);
//        
//        
//        // we got the port, refresh then move to MainUITabBarViewController
//        nextViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"MainUITabBarViewController"];
//        [self presentViewController:nextViewController animated:YES completion:nil];
//        
//        return;
//        
//    }
//    
    nextViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"JailbreakViewController"];
    [self presentViewController:nextViewController animated:YES completion:nil];
    
}
@end

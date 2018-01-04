//
//  strategy_control.m
//  houdini
//
//  Created by Abraham Masri on 12/7/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "triple_fetch_strategy.h"
#include "async_wake_strategy.h"
#include "strategy_control.h"

strategy chosen_strategy;

kern_return_t set_exploit_strategy() {
    
    NSString *system_version = [[UIDevice currentDevice] systemVersion];
    
    if([system_version isEqualToString:@"10.3.3"] || [system_version isEqualToString:@"11.2"]) {
        return KERN_FAILURE;
    }
    
    memset(&chosen_strategy, 0, sizeof(chosen_strategy));
    
    // if 10.x, use triple fetch
    // if 11.x, use XXXX
    if([system_version containsString:@"10"]) {
        chosen_strategy = triple_fetch_strategy();
        printf("[INFO]: chose triple_fetch_strategy!\n");
        
    } else if ([system_version containsString:@"11"]) {
        chosen_strategy = async_wake_strategy();
        printf("[INFO]: chose async_wake_strategy!\n");
    } else {
        return KERN_FAILURE;
    }
 
    return KERN_SUCCESS;
}

//
//  packages_control.m
//  houdini
//
//  Created by Abraham Masri on 11/23/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "PackagesViewController.h"
#include "source.h"
#include "package.h"

NSMutableArray *packages_list;
NSMutableArray *tweaks_list;
NSMutableArray *themes_list;

/*
 * Description:		Sorts packages into each tweaks/themes list
 */
void sort_packages() {
    
    for(Package *package in packages_list) {

        if([package.type containsString:@"tweaks"]) {
            [tweaks_list addObject:package];
        } else if ([package.type containsString:@"theme"]) {
            [themes_list addObject:package];
        }
    }
    
}

/*
 * Description:		Reads the 'Packages' of a given URL
 */
void read_raw_packages_list(Source *source) {
    
    NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:source.packages_url]];
    
    if (urlData) {
        
        NSString* output_raw = [[NSString alloc] initWithData:urlData encoding:NSASCIIStringEncoding];
        
        if([output_raw containsString:@"<!DOCTYPE html PUBLIC"])
            return;
        
        NSArray *aryPackages = [output_raw componentsSeparatedByString:@"\n\n"];

        for (NSString *package_raw in aryPackages) {
            
            NSArray *packageItems = [package_raw componentsSeparatedByString:@"\n"];
            
            Package *package = [[Package alloc] init];
            
            package.source = source;
            
            
            for (NSString *item in packageItems) {
                if ([item containsString:@": "]) {
                    NSArray *aryDictkey = [item componentsSeparatedByString:@": "];
                    
                    if([aryDictkey count] < 2)
                        continue;
                    
                    NSString *key = aryDictkey[0];
                    NSString *value = aryDictkey[1];
                    
                    if([key isEqual: @"Name"]) {
                        package.name = value;
                    } else if([key isEqual: @"Description"]) {
                        package.short_desc = value;
                    } else if([key isEqual: @"Author"]) {
                        package.author = value;
                    } else if([key isEqual: @"Section"]) {
                        package.type = value.lowercaseString;
                    } else if([key isEqual: @"Version"]) {
                        package.version = value;
                    } else if([key isEqual: @"Filename"]) {
                        package.url = value;
                    } else if([key isEqual: @"Depiction"]) {
                        package.depiction = value;
                    }

                }
            }
            
            if(package != NULL) {
                [packages_list addObject:package];
            }
        }

    }
    
}


void reload_packages() {
    
    extern NSMutableArray *sources_list;
    
    if([sources_list count] <= 0) {
        return;
    }
    
    for(Source *source in sources_list) {

        // TODO: All should be async
        if([source.packages_url containsString:@".bz2"]) {
            
        } else {
            read_raw_packages_list(source);
        }
    }
    
}


void packages_control_init() {
    
    if(packages_list == NULL) {
        packages_list = [[NSMutableArray alloc] init];
    }
    
    if(tweaks_list == NULL) {
        tweaks_list = [[NSMutableArray alloc] init];
    }
    
    if(themes_list == NULL) {
        themes_list = [[NSMutableArray alloc] init];
    }
    
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
    
        reload_packages();
        sort_packages();
        printf("[INFO]: done loading packages!\n");
//    });
    
}

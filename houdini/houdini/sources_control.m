//
//  sources_control.m
//  houdini
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "source.h"
#include "packages_control.h"

NSMutableArray *sources_list;

kern_return_t parse_release(NSString * url, NSString * source_content, Source * source) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    NSArray *aryFile = [source_content componentsSeparatedByString:@"\n"];
    
    NSString *packagesURL = @"";
    
    NSMutableDictionary *dictItems = [NSMutableDictionary new];
    for (NSString *line in aryFile) {
        if ([line containsString:@": "]) {
            NSArray *aryDictkey = [line componentsSeparatedByString:@": "];
            if ([[aryDictkey objectAtIndex:0] isEqualToString:@"MD5Sum"] || [[aryDictkey objectAtIndex:0] isEqualToString:@"SHA1"] || [[aryDictkey objectAtIndex:0] isEqualToString:@"SHA256"]) continue;
            [dictItems setObject:[aryDictkey objectAtIndex:1] forKey:[aryDictkey objectAtIndex:0]];
        }

        if([line containsString:@"/Packages"] && [packagesURL isEqualToString:@""])
            packagesURL = [NSString stringWithFormat:@"%@/%@", url, [line componentsSeparatedByString:@" "][3]];
    }

    NSString * origin = [dictItems objectForKey:@"Origin"];
    NSString * architectures = [dictItems objectForKey:@"Architectures"];
    NSString * description = [dictItems objectForKey:@"Description"];
    NSString * URL = url;
    
    // this only happens during loading existing sources
    if(url == NULL) {
        URL = [dictItems objectForKey:@"URL"];
    }

    
    
    if ([packagesURL isEqualToString:@""]) {
        packagesURL = [NSString stringWithFormat:@"%@/Packages", URL];
        if (![NSData dataWithContentsOfURL:[NSURL URLWithString:packagesURL]]) {
            packagesURL = [NSString stringWithFormat:@"%@/Packages.bz2", URL];
        }
    }
    
    // validate the architecture
    if(![architectures containsString:@"iphoneos-arm"]) {
        printf("[ERROR]: the given URL does not have iphoneos-arm architecure: %s", [url UTF8String]);
        return KERN_FAILURE;
    }
    
    source.name = origin;
    source.desc = description;
    source.url = url;
    source.packages_url = packagesURL;
    
    printf("%s\n\n", [packagesURL UTF8String]);
    return ret;
    
}

kern_return_t download_release(NSString * url, NSString ** release_path, Source * source) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:[url stringByAppendingString:@"/Release"]]];
    
    if (urlData) {
        if ([[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding] containsString:@"<!DOCTYPE html PUBLIC"])
            return KERN_FAILURE;
        
        // Create a unique dir for our source to store data in
        NSString *documents_path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *source_dir_path = [documents_path stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];

        [[NSFileManager defaultManager] createDirectoryAtPath:source_dir_path withIntermediateDirectories:NO attributes:nil error:nil];
        
        
        NSString* output_raw = [[NSString alloc] initWithData:urlData encoding:NSASCIIStringEncoding];

        NSString *source_info_path = [source_dir_path stringByAppendingPathComponent:@"/sourceinfo"];

        ret = parse_release(url, output_raw, source);
        
        if(ret != KERN_SUCCESS) {
            printf("[INFO]: could not parse release info from URL: %s", [url UTF8String]);
            return ret;
        }
        
        NSMutableArray *source_array = [[NSMutableArray alloc] init];
        
        [source_array addObject:[NSString stringWithFormat:@"Origin: %@", source.name]];
        [source_array addObject:@"Architectures: iphoneos-arm"];
        [source_array addObject:[NSString stringWithFormat:@"Description: %@", source.desc]];
        [source_array addObject:[NSString stringWithFormat:@"URL: %@", source.url]];
        [source_array addObject:[NSString stringWithFormat:@"PackagesURL: %@", source.packages_url]];
        
        NSString *source_output = [source_array componentsJoinedByString:@"\n"];
        
        BOOL ret = [source_output writeToFile:source_info_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        if (!ret){
            return KERN_FAILURE;
        }

        *release_path = source_info_path;
    }

    return ret;
}

kern_return_t add_source(NSString * url) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    if(sources_list == NULL)
        sources_list = [[NSMutableArray alloc] init];
    
    NSString *_url;
    if (![[url substringFromIndex:[url length] - 1] isEqualToString:@"/"]) {
        _url = [url stringByAppendingString:@"/"];
    } else {
        _url = url;
    }
    
    NSString *release_path = [[NSString alloc] init];
    Source *source = [[Source alloc] initWithURL:_url];
    ret = download_release(_url, &release_path, source);
    
    if(ret != KERN_SUCCESS) {
        printf("[INFO]: failed downloading and saving release from given URL: %s", [_url UTF8String]);
        return ret;
    }
    

    [sources_list addObject:source];

    return ret;
}

void remove_source(Source *source) {
    [[NSFileManager defaultManager] removeItemAtPath:source.sourceinfo_path error:nil];
    [sources_list removeObject:source];
}


void sources_control_init() {
    
    if(sources_list == NULL)
        sources_list = [[NSMutableArray alloc] init];
    
    // default sources (shouldn't be here but eh)
    if([sources_list count] <= 0) {
        Source *modmyi_source = [[Source alloc] init];
        modmyi_source.name = @"ModMyi (Archive)";
        modmyi_source.desc = @"ModMyi.com - they hosted your apps!";
        modmyi_source.url = @"http://apt.modmyi.com/dists/stable/";
        modmyi_source.packages_url = @"http://apt.modmyi.com/dists/stable/main/binary-iphoneos-arm/Packages";
    
        [sources_list addObject:modmyi_source];
    }
    
    NSString *documents_path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    
    NSArray* sources_dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documents_path error:nil];

    for(NSString *dir_name in sources_dirs) {
        
        NSString *source_info_content = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/sourceinfo", documents_path, dir_name] encoding:NSUTF8StringEncoding error:nil];
        
        NSArray *aryFile = [source_info_content componentsSeparatedByString:@"\n"];
        
        NSMutableDictionary *dictItems = [NSMutableDictionary new];
        for (NSString *line in aryFile) {
            if ([line containsString:@": "]) {
                NSArray *aryDictkey = [line componentsSeparatedByString:@": "];
                [dictItems setObject:[aryDictkey objectAtIndex:1] forKey:[aryDictkey objectAtIndex:0]];
            }
        }
        
        
        Source *source = [[Source alloc] init];
        
        source.name = [dictItems objectForKey:@"Origin"];
        source.desc = [dictItems objectForKey:@"Description"];
        source.url = [dictItems objectForKey:@"URL"];
        source.packages_url = [dictItems objectForKey:@"PackagesURL"];
        source.sourceinfo_path = [NSString stringWithFormat:@"%@/%@", sources_dirs, dir_name];
        
        if(source.url == NULL)
            continue;
        
        [sources_list addObject:source];
    }
    
//    Source *bigboss_source = [[Source alloc] init];
//    bigboss_source.name = @"BigBoss";
//    bigboss_source.desc = @"For hosting your apps, see our website.";
//    bigboss_source.url = @"http://apt.thebigboss.org/repofiles/cydia/dists/stable/";
//    bigboss_source.packages_url = @"http://apt.modmyi.com/dists/stable/main/binary-iphoneos-arm/Packages";
//    
//    [sources_list addObject:bigboss_source];
    
    // Get packages (TODO: should be moved to packages_control)
    printf("[INFO]: reloading packages..\n");
//    packages_control_init();
}

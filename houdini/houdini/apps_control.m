//
//  apps_control.m
//  Houdini
//
//  Created by Abraham Masri(cheesecakeufo) on 11/16/17.
//  Copyright © 2017 Abraham Masri(cheesecakeufo). All rights reserved.
//

#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <libgen.h>
#include <dlfcn.h>
#include <objc/runtime.h>

#import <mach-o/loader.h>

#include "remote_file.h"
#include "triple_fetch_remote_call.h"
#include "remote_memory.h"
#include "remote_ports.h"
#include "apps_control.h"
#include "task_ports.h"
#include "binary_control.h"
#include "strategy_control.h"
#include "utilities.h"
#include "package.h"

#import "UIImage+Private.h"

/* 
 an app's structure (all_apps):
 
 'uuid': {
     'raw_display_name': NSString,
     'identifier': NSString,
     'uuid': NSString,
     'full_path': NSString,
     'executable': NSString,
     'icon_names': NSSArray,
     'valid': BOOL
 }
 
 */

// contains list of apps taken from INSTALLED_APPS_DIR
NSMutableDictionary *all_apps;


// contains list of apps (bundle data uuid) taken from APPS_DATA_PATH
NSMutableArray *all_apps_data;


void read_apps_root_dir() {
    
    DIR *mydir;
    struct dirent *myfile;
    
    int fd = chosen_strategy.strategy_open(INSTALLED_APPS_PATH, O_RDONLY, 0);
    
    if (fd < 0)
        return;
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        char *dir_name = myfile->d_name;
        
        // skip dirs that start with '.'
        if(strncmp(".", dir_name, 1) == 0 || myfile->d_type != DT_DIR) {
            continue;
        }
        
        NSString *app_uuid =  [NSString stringWithFormat:@"%s" , strdup(dir_name)];
        NSString *full_path = [NSString stringWithFormat:@"%s/%@" , INSTALLED_APPS_PATH, app_uuid];
        NSMutableDictionary *app_dict = [[NSMutableDictionary alloc]
                                         initWithObjectsAndKeys:
                                         app_uuid, @"uuid",
                                         full_path, @"full_path",
                                         nil];

        [all_apps setObject:app_dict forKey:app_uuid];

    }
    
    closedir(mydir);
    close(fd);
}

char * list_child_dirs(NSMutableDictionary *app_dict) {
    
    DIR *mydir;
    struct dirent *myfile;
    
    char *full_path = strdup([[app_dict objectForKey:@"full_path"] UTF8String]);
    int fd = chosen_strategy.strategy_open(full_path, O_RDONLY, 0);
    
    if (fd < 0)
        goto failed;
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        char *dir_name = myfile->d_name;
        char *ext = strrchr(dir_name, '.');
        if (ext && !strcmp(ext, ".app")) {
            
            printf("listing dir_name: %s\n", dir_name);
            [app_dict setObject:[NSString stringWithFormat:@"%s/%s" , full_path, strdup(dir_name)] forKey:@"app_path"];
            break;
        }
        
    }
    
    closedir(mydir);
    close(fd);
    
failed:
    return "";
}

/*
 *  Purpose: reads all apps along with their container_manager metadata
 *  then appends to all_apps_data
*/
void read_apps_data_dir() {
    
    if (all_apps_data == NULL) {
        all_apps_data = [[NSMutableArray alloc] init];
    }
    
    DIR *mydir;
    struct dirent *myfile;
    
    int fd = chosen_strategy.strategy_open(APPS_DATA_PATH, O_RDONLY, 0);
    
    if (fd < 0)
        return;

    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        char *data_uuid = myfile->d_name;
        
        if(strcmp(data_uuid, ".") == 0 || strcmp(data_uuid, "..") == 0)
            continue;
        
        [all_apps_data addObject:[NSString stringWithFormat:@"%s", data_uuid]];
        
    }
    
    closedir(mydir);
    close(fd);
    
}


kern_return_t read_app_info(NSMutableDictionary *app_dict, NSString *local_app_info_path) {
    
    
    FILE *info_file;
    long plist_size;
    char *plist_contents;
    
    char *info_path = strdup([[NSString stringWithFormat:@"%@/Info.plist" , [app_dict objectForKey:@"app_path"]] UTF8String]);
    int fd = chosen_strategy.strategy_open(info_path, O_RDONLY, 0);
    
    if (fd < 0)
        return KERN_FAILURE;
    
    info_file = fdopen(fd, "r");
    
    fseek(info_file, 0, SEEK_END);
    plist_size = ftell(info_file);
    rewind(info_file);
    plist_contents = malloc(plist_size * (sizeof(char)));
    fread(plist_contents, sizeof(char), plist_size, info_file);
    
    
    close(fd);
    fclose(info_file);
    
    NSString *plist_string = [NSString stringWithFormat:@"%s", plist_contents];
    NSData *data = [plist_string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSPropertyListFormat format;
    NSDictionary *dict = [NSPropertyListSerialization
                          propertyListWithData:data
                          options:kNilOptions
                          format:&format
                          error:&error];
    
    // check if we're null or not
    if(dict == NULL) { // probably a binary plist
        
        NSString *local_info_path = [NSString stringWithFormat:@"%@/Info.plist", local_app_info_path];
        
        // try to copy the file to our dir then read it
        copy_file(info_path, strdup([local_info_path UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
        
        dict = [NSDictionary dictionaryWithContentsOfFile:local_info_path];
        
        if(dict == NULL) {
            [app_dict setValue:@NO forKey:@"valid"];
            return KERN_FAILURE;
        }
    }
    
    
    // Some apps don't use "CFBundleDisplayName"
    if([dict objectForKey:@"CFBundleDisplayName"] != nil) {
        [app_dict setObject:[dict objectForKey:@"CFBundleDisplayName"] forKey:@"raw_display_name"];
        
    } else {
        
        if([dict objectForKey:@"CFBundleName"] != nil) {
            [app_dict setObject:[dict objectForKey:@"CFBundleName"] forKey:@"raw_display_name"];
        } else {
            [app_dict setValue:@NO forKey:@"valid"];
            return KERN_FAILURE;
        }
    }
    
//    NSLog(@"%@", [app_dict objectForKey:@"raw_display_name"]);
    
    NSMutableArray *app_icons_list = [[NSMutableArray alloc] init];
    
    // Lookup Icon names
    if([dict objectForKey:@"CFBundleIcons"] != nil) {

        NSDictionary *icons_dict = [dict objectForKey:@"CFBundleIcons"];
        if([icons_dict objectForKey:@"CFBundlePrimaryIcon"] != nil) {
            

            NSDictionary *primary_icon_dict = [icons_dict objectForKey:@"CFBundlePrimaryIcon"];

            if([primary_icon_dict objectForKey:@"CFBundleIconFiles"] != nil) {
                
                for(NSString *raw_icon in [primary_icon_dict valueForKeyPath:@"CFBundleIconFiles"]){
                    
                    
                    NSString *icon = [raw_icon stringByReplacingOccurrencesOfString:@".png" withString:@""];
                    
                    // regular icon
                    if(![app_icons_list containsObject:icon]){
//                        NSLog(@"[INFO]: adding icon: %@", icon);
                        [app_icons_list addObject:icon];
                    }
                    
                    // 2x icon
                    NSString *_2xicon = [icon stringByAppendingString:@"@2x"];
                    
                    if(![app_icons_list containsObject:_2xicon]){
//                        NSLog(@"[INFO]: adding icon 2x: %@", _2xicon);
                        [app_icons_list addObject:_2xicon];
                    }
                    
                    // 3x icon
                    NSString *_3xicon = [icon stringByAppendingString:@"@3x"];
                    if(![app_icons_list containsObject:_3xicon]){
//                        NSLog(@"[INFO]: adding icon 3x: %@", _3xicon);
                        [app_icons_list addObject:_3xicon];
                    }
                }
            }
        }
    }

    if([dict objectForKey:@"CFBundleIcons~ipad"] != nil) {
        
        NSDictionary *icons_dict = [dict objectForKey:@"CFBundleIcons~ipad"];
        if([icons_dict objectForKey:@"CFBundlePrimaryIcon"] != nil) {
            
            
            NSDictionary *primary_icon_dict = [icons_dict objectForKey:@"CFBundlePrimaryIcon"];
            
            if([primary_icon_dict objectForKey:@"CFBundleIconFiles"] != nil) {
                
                for(NSString *raw_icon in [primary_icon_dict valueForKeyPath:@"CFBundleIconFiles"]){
                    
                    
                    NSString *icon = [raw_icon stringByReplacingOccurrencesOfString:@".png" withString:@""];

                    // regular icon
                    if(![app_icons_list containsObject:icon]){
//                        NSLog(@"[INFO]: adding icon: %@", icon);
                        [app_icons_list addObject:icon];
                    }
                    
                    // 2x icon
                    NSString *_2xicon = [icon stringByAppendingString:@"@2x"];
                    
                    if(![app_icons_list containsObject:_2xicon]){
//                        NSLog(@"[INFO]: adding icon 2x: %@", _2xicon);
                        [app_icons_list addObject:_2xicon];
                    }
                    
                    // 2x~ipad icon
                    NSString *_2x_ipad_icon = [_2xicon stringByAppendingString:@"~ipad"];
                    if(![app_icons_list containsObject:_2x_ipad_icon]){
//                        NSLog(@"[INFO]: adding icon 2x~ipad: %@", _2x_ipad_icon);
                        [app_icons_list addObject:_2x_ipad_icon];
                    }
                    
                    // 3x icon
                    NSString *_3xicon = [icon stringByAppendingString:@"@3x"];
                    if(![app_icons_list containsObject:_3xicon]){
//                        NSLog(@"[INFO]: adding icon 3x: %@", _3xicon);
                        [app_icons_list addObject:_3xicon];
                    }
                    
                    // 3x~ipad icon
                    NSString *_3x_ipad_icon = [_3xicon stringByAppendingString:@"~ipad"];
                    if(![app_icons_list containsObject:_3x_ipad_icon]){
//                        NSLog(@"[INFO]: adding icon 3x~ipad: %@", _3x_ipad_icon);
                        [app_icons_list addObject:_3x_ipad_icon];
                    }
                }
            }
        }
    }
    
//    [app_icons_list addObject:@"AppIcon40x40~ipad"];
//    [app_icons_list addObject:@"AppIcon29x29~ipad"];
//    [app_icons_list addObject:@"AppIcon76x76~ipad"];
    [app_dict setObject:app_icons_list forKey:@"icons"];
//    NSLog(@"%@", app_icons_list);
    [app_dict setObject:[dict objectForKey:@"CFBundleIdentifier"] forKey:@"identifier"];
    [app_dict setObject:[dict objectForKey:@"CFBundleExecutable"] forKey:@"executable"];
    [app_dict setValue:@YES forKey:@"valid"];

    return KERN_SUCCESS;
}

void list_applications_installed() {
    
    if (all_apps == NULL) {
        all_apps = [[NSMutableDictionary alloc] init];
    }
    
    read_apps_root_dir();
    

    // used for reading binary Info.plist files
    NSString *local_app_info_path = get_houdini_dir_for_path(@"app_info");
    
    for (NSString* uuid in all_apps) {
        NSMutableDictionary *app_dict = [all_apps objectForKey:uuid];
        list_child_dirs(app_dict);
        read_app_info(app_dict, local_app_info_path);
    }
}

void create_jdylib_dir(struct app_dir *_app_dir) {
    
    printf("[INFO]: creating dylibs directory for %s\n", _app_dir->display_name);
    
    char dylib_dir_path[160];
    sprintf(dylib_dir_path, "%s/Dylibs" /* jdylibs */, strdup(_app_dir->app_path));
    
    chosen_strategy.strategy_mkdir(dylib_dir_path);
    
    set_file_permissions(dylib_dir_path, INSTALL_UID, INSTALL_GID, 0755);
    
    sprintf(_app_dir->jdylib_path, "%s", strdup(dylib_dir_path));

}

kern_return_t install_tweak_into_all(const char *package_name, const char *package_path) {
    
    printf("[INFO]: installing %s into all available apps\n", package_name);
    printf("[INFO]: Path: %s\n", package_path);

    printf("[INFO]: refreshing apps list..\n");
    list_applications_installed();


//    struct app_dir* entry = all_app_dirs;
//    while(entry != NULL) {
//
//        if(entry->valid) {
//            printf("[INFO]: app: %s/identifier: %s\n", entry->display_name, entry->identifier);
//
//            // TODO: this is temporary
//            if(strstr("com.cactosapp.aai", entry->identifier)) {
//
//                printf("[INFO]: found: %s\n", entry->identifier);
//
//                sleep(4);
//                create_jdylib_dir(entry);
//
//                // Add the basename to the jdylib path
//                char full_jdylib_path[256];
////                sprintf(full_jdylib_path, "/private/var/containers/Bundle/Application/14E3ECEA-900F-42C7-BB6B-7CFE3E4441AE/grindrx.app/Dylibs/%s", basename(strdup(package_path)));
//                sprintf(full_jdylib_path, "%s/%s", entry->jdylib_path, basename(strdup(package_path)));
//
//
//                sprintf(entry->jdylib_path, "%s", full_jdylib_path);
//                printf("[INFO]: full jdylib path is: %s\n", entry->jdylib_path);
//
//                copy_file(strdup(package_path), entry->jdylib_path);
//
//                // TODO: delete (this is just testing..)
////                sprintf(entry->app_path, "%s", "/private/var/containers/Bundle/Application/14E3ECEA-900F-42C7-BB6B-7CFE3E4441AE/grindrx.app");
//
//                // Inject our new dylib into the app's binary
//                if(inject_binary(entry) == KERN_SUCCESS) {
//                    printf("[INFO]: successfully injected %s!\n", entry->identifier);
//                } else {
//                    printf("[ERROR]: could not inject %s\n", entry->identifier);
//                }
//
//                sleep(10);
//            }
//        }
//        entry = entry->next;
//    }
//
    return KERN_SUCCESS;
}

// SECTION: Clear Cache
void clear_files_for_path(char *path) {
    
    DIR *mydir;
    struct dirent *myfile;
    
    printf("[INFO]: opening %s for removal\n", path);
    int fd = chosen_strategy.strategy_open(path, O_RDONLY, 0);
    
    if (fd < 0)
        return;
    
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        char *name = myfile->d_name;
        
        if(strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
            continue;
        
        const char *file_path = [[NSString stringWithFormat:@"%s/%s", path, name] UTF8String];
        
        if(myfile->d_type == DT_DIR) {
            clear_files_for_path(strdup(file_path));
        }
        
        // remove the file (path + name)
        printf("[INFO]: removing %s\n", file_path);
        chosen_strategy.strategy_unlink(strdup(file_path));
        
    }
    
    closedir(mydir);
    close(fd);
}


// SECTION: Theme
NSMutableArray * list_icons_in_theme(NSString *path) {

    printf("[INFO]: passed: %s\n", strdup([path UTF8String]));
    
    NSMutableArray *icons = [[NSMutableArray alloc] init];
    
    for(NSString *icon_name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL]) {
        [icons addObject:[NSString stringWithFormat:@"%@/%@", path, icon_name]];
    }

    return icons;
}


@interface LSApplicationWorkspace : NSObject
+ (id) defaultWorkspace;
- (BOOL) registerApplication:(id)application;
- (BOOL) unregisterApplication:(id)application;
- (BOOL) invalidateIconCache:(id)bundle;
- (BOOL) registerApplicationDictionary:(id)application;
- (BOOL) installApplication:(id)application withOptions:(id)options;
- (BOOL) _LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)system internal:(BOOL)internal user:(BOOL)user;
@end

Class lsApplicationWorkspace = NULL;
LSApplicationWorkspace* workspace = NULL;

void invalidate_icon_cache(char *identifier) {
    
    // TODO (this won't work in iOS 11)

    if(lsApplicationWorkspace == NULL || workspace == NULL) {

        lsApplicationWorkspace = (objc_getClass("LSApplicationWorkspace"));
        workspace = [lsApplicationWorkspace performSelector:@selector(defaultWorkspace)];
        
    }
    
    if ([workspace respondsToSelector:@selector(invalidateIconCache:)]) {
        [workspace invalidateIconCache:nil];
    }
    

}

void uicache() {

    // remove all cached icons
    char *path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.lsd.iconscache/Library/Caches/com.apple.IconsCache";
    
    DIR *target_dir;
    struct dirent *file;
    
    int fd = chosen_strategy.strategy_open(path, O_RDONLY, 0);
    
    if (fd >= 0) {
    
        target_dir = fdopendir(fd);
        while((file = readdir(target_dir)) != NULL) {
            
            NSString *file_name = [NSString stringWithFormat:@"%s", strdup(file->d_name)];
            
            NSString *full_path = [NSString stringWithFormat:@"%s/%@", path, file_name];
            printf("[INFO]: unlinking: %s\n", strdup([full_path UTF8String]));
            chosen_strategy.strategy_unlink(strdup([full_path UTF8String]));
            
        }
        
        closedir(target_dir);
        close(fd);
    }
    
    // iOS 11 only
    if(chosen_strategy.strategy_posix_spawn != NULL) {

        printf("[INFO]: using traditional 'uicache' instead!: %d\n", getuid());
        chosen_strategy.strategy_posix_spawn(strdup([[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/uicache"] UTF8String]));
    }
    
    invalidate_icon_cache(nil);
    path = "/var/mobile/Library/Caches";
    
    DIR *mydir;
    struct dirent *myfile;
    
    fd = chosen_strategy.strategy_open(path, O_RDONLY, 0);
    
    if (fd < 0)
        return;
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        NSString *file_name = [NSString stringWithFormat:@"%s", strdup(myfile->d_name)];
        if ([file_name containsString:@".csstore"]) {
            
            printf("[INFO]: deleting csstore: %s\n", strdup([file_name UTF8String]));
            
            NSString *full_path = [NSString stringWithFormat:@"%s/%@", path, file_name];
            chosen_strategy.strategy_unlink(strdup([full_path UTF8String]));
            
        }
        
    }
    
    closedir(mydir);
    close(fd);
    
    // kill lsd
    pid_t lsd_pid = chosen_strategy.strategy_pid_for_name("lsd");
    chosen_strategy.strategy_kill(lsd_pid, SIGKILL);
    
    // remove caches
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/com.apple.springboard-imagecache-icons");
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/com.apple.springboard-imagecache-icons.plist");
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/com.apple.springboard-imagecache-smallicons");
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/com.apple.springboard-imagecache-smallicons.plist");
    
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/SpringBoardIconCache");
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/SpringBoardIconCache-small");
    chosen_strategy.strategy_unlink("/var/mobile/Library/Caches/com.apple.IconsCache");
    
    
    // kill installd
    pid_t installd_pid = chosen_strategy.strategy_pid_for_name("installd");
    chosen_strategy.strategy_kill(installd_pid, SIGKILL);
    
    // kill springboard
    kill_springboard(SIGKILL);
}



kern_return_t revert_theme_to_original(char * path, boolean_t revert_others) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    DIR *mydir;
    struct dirent *myfile;
    
    char *full_path = strdup(path);
    int fd = chosen_strategy.strategy_open(full_path, O_RDONLY, 0);
    
    if (fd < 0) {
        ret = KERN_FAILURE;
        return ret;
    }
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        NSString *file_name = [NSString stringWithFormat:@"%s/%s", path, strdup(myfile->d_name)];
        if ([file_name containsString:@"bck_"]) {
            
            NSString *original_icon_name = [file_name stringByReplacingOccurrencesOfString:@"bck_" withString:@""];
            
            printf("[INFO]: reverting %s back to %s\n", strdup([file_name UTF8String]), strdup([original_icon_name UTF8String]));
            
            
            // delete the theme icon file then rename the bck_ to the original one
            chosen_strategy.strategy_unlink(strdup([original_icon_name UTF8String]));
            
            chosen_strategy.strategy_rename([file_name UTF8String], [original_icon_name UTF8String]);
            
        }
        
    }
    
    closedir(mydir);
    close(fd);
    
    // only clear files for these pathes if the user really wants to
    if(revert_others) {
        clear_files_for_path("/var/mobile/Library/Caches/MappedImageCache/Persistent");
//        clear_files_for_path("/var/mobile/Library/Caches/MappedImageCache/com.apple.TelephonyUI.TPRevealingRingView");
    }
    
    return ret;
}

void inject_dylib_test() {
    
//    printf("[INFO]: starting injection method..\n");
//    
//    refresh_task_ports_list(PRIV_PORT());
//
//
//    mach_port_t target_task_port = find_task_port_for_path("test123");
//    if (target_task_port == MACH_PORT_NULL) {
//        printf("failed to get the new target's task port test123\n");
//        return;
//    }
//    NSLog(@"Found target app. going to inject..");
//    
//
//    char *dest_path = "/var/containers/Bundle/Application/C6877326-3269-4CA3-B6B8-5840BE81A228/test123.app/LocationSpoofing";
//    copy_file("/var/mobile/LocationSpoofing", dest_path, 501, 501, 0755);
//    
//    sleep(2);
//    void * dlopen_ret = (void *)call_remote(target_task_port, dlopen, 2,
//                                            REMOTE_CSTRING(dest_path),
//                                            REMOTE_LITERAL(RTLD_GLOBAL | RTLD_NOW));
//    if (dlopen_ret == NULL) {
//        printf("[ERROR]: (2) failed to dlopen in test123\n");
//        char * dlopen_err = (char *)call_remote(target_task_port, dlerror, 0);
//        if(dlopen_err != NULL)
//            
//            return;
//    }
//    printf("[SUCCESS]: (2) test123 dlopen at 0x%llx\n", (uint64_t)dlopen_ret);
//    
//    
    
    
}

/*
    Purpose: searched for a given directory name at a given path
*/
NSString * get_dir_in_theme_path(NSString *theme_path, NSString *dir_name) {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL URLWithString:theme_path]; // URL pointing to the directory you want to browse
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSNumber *isDirectory;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        if ([isDirectory boolValue]) {
            
            if([url.absoluteString containsString:dir_name]) {
                return [[url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""] stringByRemovingPercentEncoding];
            }
        }
    }
    
    return nil;
}

/*
    Purpose: searched for a given directory name at a given path
    TODO: this is really not the way to do it. we have to iterate through
    for EVERY file we need. that's just painful. if you have time, improve dis :)
 */
NSString * get_file_in_theme_path(NSString *theme_path, NSString *file_name) {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL URLWithString:theme_path]; // URL pointing to the directory you want to browse
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
            
        if([url.absoluteString containsString:file_name]) {
            return [[url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""] stringByRemovingPercentEncoding];
        }
    }
    
    return nil;
}

UIImage *change_image_tint_to(UIImage *src_image, UIColor *color) {
    
    CGRect rect = CGRectMake(0, 0, src_image.size.width, src_image.size.height);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClipToMask(context, rect, src_image.CGImage);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *colorized_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return colorized_image;
}

/*
 *  Purpose: copies a persistent asset from the theme into the system
 */
void copy_persistent_asset(const char *data_path, NSString *theme_asset_name, NSString *destination_name, BOOL make_white) {

    NSString *theme_next_path = get_file_in_theme_path([NSString stringWithFormat:@"%s", data_path], theme_asset_name);
    
    if(theme_next_path != nil) {
        
        NSString *cpbitmap_path = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject], destination_name];
        UIImage *image = [UIImage imageWithContentsOfFile:theme_next_path];
    
        if(make_white) {
            // since the image is most likely black, we'll make it white
            image = change_image_tint_to(image, [UIColor whiteColor]);
        }
        
        [image writeToCPBitmapFile:cpbitmap_path flags:0];
        
        copy_file(strdup([cpbitmap_path UTF8String]), strdup([[NSString stringWithFormat:@"/var/mobile/Library/Caches/MappedImageCache/Persistent/%@", destination_name] UTF8String]), MOBILE_UID, MOBILE_GID, 0666);
        
    }
    
}

/*
    Purpose: deletes the cached wallpaper
 */
void delete_cached_wallpaper() {
    

    char *path = "/var/mobile/Library/Caches/MappedImageCache/Wallpaper";
    
    DIR *mydir;
    struct dirent *myfile;
    
    int fd = chosen_strategy.strategy_open(path, O_RDONLY, 0);
    
    if (fd < 0)
        return;
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        NSString *file_name = [NSString stringWithFormat:@"%s", strdup(myfile->d_name)];
        if ([file_name containsString:@".cpbitmap"]) {
            
            printf("[INFO]: deleting cached cpbitmap: %s\n", strdup([file_name UTF8String]));
            
            NSString *full_path = [NSString stringWithFormat:@"%s/%@", path, file_name];
            chosen_strategy.strategy_unlink(strdup([full_path UTF8String]));
            
        }
        
    }
    
    closedir(mydir);
    close(fd);
    
    // remove SpringBoard background
    
    chosen_strategy.strategy_unlink("/var/mobile/Library/SpringBoard/LockBackground.cpbitmap");
    chosen_strategy.strategy_unlink("/var/mobile/Library/SpringBoard/LockBackgroundThumbnail.jpg");
    chosen_strategy.strategy_unlink("/var/mobile/Library/SpringBoard/OriginalLockBackground.cpbitmap");

    chosen_strategy.strategy_unlink("/var/mobile/Library/SpringBoard/HomeBackground.cpbitmap");
    chosen_strategy.strategy_unlink("/var/mobile/Library/SpringBoard/HomeBackgroundThumbnail.jpg");
    chosen_strategy.strategy_unlink("/var/mobile/Library/SpringBoard/OriginalHomeBackground.cpbitmap");

}



/*
    Purpose: extracts a theme at a given path and installs it for all applications
*/
kern_return_t apply_theme_into_all(const char *package_name, const char *package_path) {
    
    printf("[INFO]: applying %s into all available apps\n", package_name);
    printf("[INFO]: package path: %s\n", package_path);
    
    // decompress the package
    const char *data_path = decompress_deb_file(strdup(package_path));
    
    // find the IconBundles directory
    NSString *icon_bundles_path = get_dir_in_theme_path([NSString stringWithFormat:@"%s", data_path], @"IconBundles");
    
    printf("[INFO]: IconBundles path is: %s", [icon_bundles_path UTF8String]);
    
    if(all_apps == NULL) {
        printf("[INFO]: refreshing apps list..\n");
        list_applications_installed();
    }
    

    NSMutableArray *icons = list_icons_in_theme(icon_bundles_path);

    for (NSString* uuid in all_apps) {
        NSMutableDictionary *app_dict = [all_apps objectForKey:uuid];
        
        if ([[app_dict objectForKey:@"valid"]  isEqual: @YES]) {
            
            if ([app_dict objectForKey:@"identifier"] == nil) {
                continue;
            }
            
            printf("[INFO]: reverting to original theme for %s\n", strdup([[app_dict objectForKey:@"raw_display_name"] UTF8String]));
            
            // revert to the original icons first
            revert_theme_to_original(strdup([[app_dict objectForKey:@"app_path"] UTF8String]), false);
            
            
            // check if we have a theme for this icon
            for (NSString *theme_icon_path in icons) {
                if ([theme_icon_path containsString:[app_dict objectForKey:@"identifier"]] &&
                    ([theme_icon_path containsString:@"2x"] || [theme_icon_path containsString:@"large"]) &&
                    ![theme_icon_path containsString:@"~"]) {
                    
                    printf("[INFO]: themeing %s..\n", strdup([[app_dict objectForKey:@"raw_display_name"] UTF8String]));
                    
                    if([app_dict objectForKey:@"icons"] == nil) {
                        continue;
                    }

                    
                    // backup the existing icons
                    for (NSString *original_icon_name in [app_dict objectForKey:@"icons"]) {
                        
                        // '@' causes issues copying the file
                        NSMutableString *original_icon_full_name = [NSMutableString stringWithString:original_icon_name];
//                            [NSMutableString stringWithString:[original_icon_name stringByReplacingOccurrencesOfString:@"@" withString:@"\\@"]];
                        
                        // add extenstion if we don't have one from the app's Info.plist
                        if (![original_icon_name containsString:@".png"]) {
                            [original_icon_full_name appendString:@".png"];
                        }

                        // rename the original files to bck_...
                        NSString *original_icon_path = [NSString stringWithFormat:@"%@/%@", [app_dict objectForKey:@"app_path"], original_icon_full_name];
                        NSString *renamed_icon_path = [NSString stringWithFormat:@"%@/bck_%@", [app_dict objectForKey:@"app_path"], original_icon_full_name];
                        
                        printf("[INFO]: renaming: %s ---> %s\n", strdup([original_icon_path UTF8String]), strdup([renamed_icon_path UTF8String]));
                        
                        chosen_strategy.strategy_rename([original_icon_path UTF8String],
                                                        [renamed_icon_path UTF8String]);
                        
                        
                        // the fun part
                        copy_file(strdup([theme_icon_path UTF8String]), strdup([original_icon_path UTF8String]), INSTALL_UID, INSTALL_GID, 0755);
                        
                        // remove Assets.car?
//                        chosen_strategy.strategy_unlink(strdup([[NSString stringWithFormat:@"%@/Assets.car", [app_dict objectForKey:@"app_path"]] UTF8String]));
                    }
                }
            }
            
            // invalidate cache
            invalidate_icon_cache(strdup([[app_dict objectForKey:@"identifier"] UTF8String]));
        }
        
    }
    
    // find the Wallpaper directory
    NSString *theme_wallpaper_path = get_dir_in_theme_path([NSString stringWithFormat:@"%s", data_path], @"Wallpaper");
    
    if(theme_wallpaper_path == nil) {
        return KERN_SUCCESS;
    }
    
    NSString *final_theme_wallpaper_path = nil;
    for (NSString *device_name in [NSArray arrayWithObjects:@"iPhone", @"iPad", @"iPod", nil]) {
        
        if(final_theme_wallpaper_path != nil)
            break;
        
        NSString *path = [NSString stringWithFormat:@"%@/%@", theme_wallpaper_path, device_name];
        for(NSString *wallpaper_name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL]) {
            
            final_theme_wallpaper_path = [NSString stringWithFormat:@"%@/%@", path, wallpaper_name];
            break; // we got the first wallpaper we found, stop.
        }
    }

    if (final_theme_wallpaper_path == nil)
        return KERN_SUCCESS; // no wallpaper in the theme
    
    // turn the wallpaper into cpbitmap format (private framework)
    NSString *cpbitmap_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/LockBackground.cpbitmap"];
    [[UIImage imageWithContentsOfFile:final_theme_wallpaper_path] writeToCPBitmapFile:cpbitmap_path flags:0];

    // delete the cached wallpaper
    delete_cached_wallpaper();
    
    copy_file(strdup([cpbitmap_path UTF8String]), "/var/mobile/Library/SpringBoard/LockBackground.cpbitmap", MOBILE_UID, MOBILE_GID, 0666);


    // install other assets
    {
        char *path = "/var/mobile/Library/Caches/MappedImageCache/Persistent/";
        
        DIR *mydir;
        struct dirent *myfile;
        
        int fd = chosen_strategy.strategy_open(path, O_RDONLY, 0);
        
        if (fd < 0)
            return KERN_SUCCESS; // even if we fail here, we still managed to do a lot!
        
        NSMutableArray *toggles_cpbitmap_list = [[NSMutableArray alloc] init];
        
        mydir = fdopendir(fd);
        while((myfile = readdir(mydir)) != NULL) {
            
            if(strcmp(myfile->d_name, ".") == 0 || strcmp(myfile->d_name, "..") == 0)
                continue;
            
            NSString *file_name = [NSString stringWithFormat:@"%s", strdup(myfile->d_name)];
            [toggles_cpbitmap_list addObject:file_name];
            
            // remove the file
            chosen_strategy.strategy_unlink(strdup([[NSString stringWithFormat:@"%s/%@", path, file_name] UTF8String]));

        }
        
        // find the IconBundles directory
        copy_persistent_asset(data_path, @"SBBadgeBG@2x.png", @"SBIconBadgeView.BadgeBackground.cpbitmap", NO); // icon badges
        copy_persistent_asset(data_path, @"SystemMediaControl-Play@2x.png", @"play.png-3.cpbitmap", NO); // CC play
        copy_persistent_asset(data_path, @"SystemMediaControl-Pause@2x.png", @"pause.png-3.cpbitmap", NO); // CC pause
        copy_persistent_asset(data_path, @"SystemMediaControl-Forward@2x.png", @"next.png-3.cpbitmap", NO); // CC next
        copy_persistent_asset(data_path, @"volume-slider-thumb-view@2x.png", @"previous.png-3.cpbitmap", NO); // CC previous
        copy_persistent_asset(data_path, @"ControlCenterSliderThumb@2x.png", @"ControlCenterSliderThumb.cpbitmap", NO); // CC Slider
        
        
        // now we loop through the list to find what we need
        for(NSString *toggle_cpbitmap_name in toggles_cpbitmap_list) {
            
            if([toggle_cpbitmap_name containsString:@"airplane"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphAirplane@2x.png", toggle_cpbitmap_name, YES); // CC airplane
            } else if([toggle_cpbitmap_name containsString:@"bluetooth"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphBluetooth@2x.png", toggle_cpbitmap_name, YES); // CC bluetooth
            } else if([toggle_cpbitmap_name containsString:@"calculator"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphCalculator@2x.png", toggle_cpbitmap_name, YES); // CC calculator
            } else if([toggle_cpbitmap_name containsString:@"camera"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphCamera@2x.png", toggle_cpbitmap_name, YES); // CC camera
            } else if([toggle_cpbitmap_name containsString:@"timer"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphClock@2x.png", toggle_cpbitmap_name, YES); // CC timer/clock
            } else if([toggle_cpbitmap_name containsString:@"doNotDisturb"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphMoon@2x.png", toggle_cpbitmap_name, YES); // CC DND
            } else if([toggle_cpbitmap_name containsString:@"orientationLock"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphOrientationUnlocked@2x.png", toggle_cpbitmap_name, YES); // CC orientation
            } else if([toggle_cpbitmap_name containsString:@"wifi"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphWifi@2x.png", toggle_cpbitmap_name, YES); // CC wifi
            } else if([toggle_cpbitmap_name containsString:@"flashlight"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphFlashlight@2x.png", toggle_cpbitmap_name, YES); // CC flashlight
            }

            else if([toggle_cpbitmap_name containsString:@"SBLockScreenTimerDial"]) {
                copy_persistent_asset(data_path, @"ControlCenterGlyphClock@2x.png", toggle_cpbitmap_name, YES); // LS countdown timer
            }
            
//            else if([toggle_cpbitmap_name containsString:@"Multitasking_Shadow"]) {
//                copy_persistent_asset(data_path, @"SBBadgeBG@2x.png", toggle_cpbitmap_name); // Multitasking_Shadow
//            }
        }
    }

    return KERN_SUCCESS;
}


/*
 *  Purpose: returns an image with a given radius/width/height
 */
UIImage *get_image_for_radius(int radius, int width, int height) {
    
    printf("[INFO]: image for width and height: %d %d\n", width, height);
    CGRect rect = CGRectMake(0, 0, width, height);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextFillRect(context, rect);
    UIImage *src_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CALayer *image_layer = [CALayer layer];
    image_layer.frame = CGRectMake(0, 0, src_image.size.width, src_image.size.height);
    image_layer.contents = (id) src_image.CGImage;
    
    image_layer.masksToBounds = YES;
    image_layer.cornerRadius = radius;
    
    UIGraphicsBeginImageContext(src_image.size);
    [image_layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *rounded_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return rounded_image;
}


/*
 *  Purpose: changes the color of icon badges
 */
kern_return_t change_icon_badge_color(const char *color_raw, const char *size_type) {

    UIImage *badge;
    NSString *file_name;
    
    if (strcmp("2x", size_type) == 0) {
        badge = get_image_for_radius(12, 24, 24);
        file_name = @"SBBadgeBG@2x.png";
    } else if (strcmp("3x", size_type) == 0) {
        badge = get_image_for_radius(24, 48, 48);
        file_name = @"SBBadgeBG@3x.png";
    }

    unsigned int rgb = 0;
    [[NSScanner scannerWithString:
      [[[NSString stringWithFormat:@"%s", color_raw] uppercaseString] stringByTrimmingCharactersInSet:
       [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet]]]
     scanHexInt:&rgb];

    UIColor *uiColor = [UIColor colorWithRed:((CGFloat)((rgb & 0xFF0000) >> 16)) / 255.0
                                     green:((CGFloat)((rgb & 0xFF00) >> 8)) / 255.0
                                      blue:((CGFloat)(rgb & 0xFF)) / 255.0
                                     alpha:1.0];
    badge = change_image_tint_to(badge, uiColor);
    
    
    // iOS 11, save as png and copy to SpringBoard (EDIT: 11 now stores files in Assets.car :( )
    // iOS 10, save as cpbitmap and copy to Caches
//    if ([[[UIDevice currentDevice] systemVersion] containsString:@"11"]) {
//
//        NSString *saved_png_path = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject], file_name];
//
//        NSData *image_data = UIImagePNGRepresentation(badge);
//        [image_data writeToFile:saved_png_path atomically:YES];
//
//
//        copy_file(strdup([saved_png_path UTF8String]), strdup([[@"/System/Library/CoreServices/SpringBoard.app/" stringByAppendingString:file_name] UTF8String]), MOBILE_UID, MOBILE_GID, 0666);
//
//    } else {
        NSString *saved_cpbitmap_path = [NSString stringWithFormat:@"%@/SBIconBadgeView.BadgeBackground.cpbitmap", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];

        [badge writeToCPBitmapFile:saved_cpbitmap_path flags:1];
        
        copy_file(strdup([saved_cpbitmap_path UTF8String]), "/var/mobile/Library/Caches/MappedImageCache/Persistent/SBIconBadgeView.BadgeBackground.cpbitmap", MOBILE_UID, MOBILE_GID, 0666);
//    }
    
    return KERN_SUCCESS;
    
}

/*
 *  Purpose: changes the radius of icons
 */
kern_return_t change_icons_shape(int radius) {
    
    printf("[INFO]: given radius: %d\n", radius);
    
    char *framework_path = "/System/Library/PrivateFrameworks/MobileIcons.framework";
    NSArray *icon_names = [[NSArray alloc] initWithObjects:@{@"name": @"AppIconMask@2x~iphone.png", @"size": @120},
                                                           @{@"name": @"AppIconMask@3x~iphone.png", @"size": @180},
                                                           @{@"name": @"AppIconMask@3x~ipad.png", @"size": @152},
                                                           @{@"name": @"NotificationAppIconMask@2x.png", @"size": @40},
                                                           @{@"name": @"NotificationAppIconMask@3x.png", @"size": @60},
                                                           @{@"name": @"SpotlightAppIconMask@2x.png", @"size": @80},
                                                           @{@"name": @"SpotlightAppIconMask@3x.png", @"size": @120},
                                                           nil];
    
//    // restore the originals first
//    for(NSDictionary *icon_dict in icon_names) {
//        NSString *icon_name = [icon_dict objectForKey:@"name"];
//        copy_file(strdup([[NSString stringWithFormat:@"%s/bck_%@", framework_path, icon_name] UTF8String]), strdup([[NSString stringWithFormat:@"%s/%@", framework_path, icon_name] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
//    }
    
    for(NSDictionary *icon_dict in icon_names) {
        
        NSString *icon_name = [icon_dict objectForKey:@"name"];
        int icon_size = [[icon_dict objectForKey:@"size"] intValue];
        
        // fix radius for small icons (only if radius is big enough)
        if(icon_size < 100 && radius >= 10)
            radius /= 2;
        
        UIImage *converted_image = get_image_for_radius(radius, icon_size, icon_size);
        NSData *image_data = UIImagePNGRepresentation(converted_image);
        
        // save the image in our path then copy it
        NSString *saved_png_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/icon_mask.png"];
        [image_data writeToFile:saved_png_path atomically:YES];
        
        // copy the mask to each of the icon masks
        copy_file(strdup([saved_png_path UTF8String]), strdup([[NSString stringWithFormat:@"%s/%@", framework_path, icon_name] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
    }
    
    // profit??!
    
    return KERN_SUCCESS;
    
}

// Utilities ---

kern_return_t revert_icon_label_to_original(char * lproj_path) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    // .strings in .app/xxx.lproj
    NSString *strings_path = [NSString stringWithFormat:@"%s/InfoPlist.strings", lproj_path];
    
    // .backup in .app's .lproj
    NSString *backup_path = [NSString stringWithFormat:@"%s/InfoPlist.strings.backup", lproj_path];
    
    // check if we have a .backup file or not
    int fd = chosen_strategy.strategy_open(strdup([backup_path UTF8String]), O_RDONLY, 0);
    
    if(fd == -1) { // file doesn't exist, delete the .strings file then return
        
        // remove the .strings file
        chosen_strategy.strategy_unlink(strdup([strings_path UTF8String]));
        
        return ret;
    
    } else { // file exists
        
        // remove the .strings file
        chosen_strategy.strategy_unlink(strdup([strings_path UTF8String]));
        
        // rename the .backup back to .strings
        chosen_strategy.strategy_rename([backup_path UTF8String],
                                        [strings_path UTF8String]);
        
        
    }
    
    
    return ret;
}

kern_return_t rename_all_icons(const char * name, char * type) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    printf("[INFO]: renaming all app icons to %s\n", name);
    
    if(all_apps == NULL) {
        printf("[INFO]: refreshing apps list..\n");
        list_applications_installed();
    }
    
    // get the device's current language
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    
    // output path
    NSString *output_dir_path = get_houdini_dir_for_path(@"icons_renamer");
    
    for (NSString* uuid in all_apps) {
        NSMutableDictionary *app_dict = [all_apps objectForKey:uuid];
        
        if ([[app_dict objectForKey:@"valid"]  isEqual: @YES]) {
            
            if ([app_dict objectForKey:@"identifier"] == nil) {
                continue;
            }

            printf("[INFO]: renaming %s\n", strdup([[app_dict objectForKey:@"raw_display_name"] UTF8String]));
            
            char *lproj_path = strdup([[NSString stringWithFormat:@"%@/%@.lproj", [app_dict objectForKey:@"app_path"], language] UTF8String]);
            
            
            // revert to the original icon label first
            revert_icon_label_to_original(lproj_path);
            
            // if the type is 'original', we just revert
            if(strcmp(type, "original") == 0) {
                continue;
            } else {

                // .strings in .app
                NSString *strings_path = [NSString stringWithFormat:@"%s/InfoPlist.strings", lproj_path];
                
                // .strings in our temporary directory
                NSString *saved_strings_path = [NSString stringWithFormat:@"%@/InfoPlist.strings", output_dir_path];
                
                // check if the app has a dir with the device's language
                int fd = chosen_strategy.strategy_open(strdup([strings_path UTF8String]), O_RDONLY, 0);
                
                if(fd == -1) { // file doesn't exist, we'll create one
                    
                    // create an .lproj dir in the .app directory
                    chosen_strategy.strategy_mkdir(lproj_path);
                    set_file_permissions(lproj_path, INSTALL_UID, INSTALL_GID, 0755);
                    
                    // replace the values of a default strings with the user's
                    NSString *strings_content = @"\"CFBundleDisplayName\"=\"NEW_NAME\";\"CFBundleName\"=\"NEW_NAME\";";
                    strings_content = [strings_content stringByReplacingOccurrencesOfString:@"NEW_NAME" withString:[NSString stringWithFormat:@"%s", name]];
                    
                    
                    // save .strings
                    printf("[INFO]: creating .strings to: %s", strdup([saved_strings_path UTF8String]));
                    [strings_content writeToFile:saved_strings_path atomically:NO encoding:NSStringEncodingConversionAllowLossy error:nil];

                } else { // file exists, we modify it
                    
                    // copy the file to our directory
                    copy_file(strdup([strings_path UTF8String]), strdup([saved_strings_path UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
                    
                    // read the file
                    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:saved_strings_path];
                    [dict setValue:[NSString stringWithFormat:@"%s", name] forKey:@"CFBundleDisplayName"];
                    [dict setValue:[NSString stringWithFormat:@"%s", name] forKey:@"CFBundleName"];
                    
                    printf("[INFO]: saving .strings to: %s\n", strdup([saved_strings_path UTF8String]));
                    [dict writeToFile:saved_strings_path atomically:YES];
                    
                    // backup the original file
                    chosen_strategy.strategy_rename(strdup([strings_path UTF8String]),
                                                    strdup([[NSString stringWithFormat:@"%@.backup", strings_path] UTF8String]));
                    
                }
                
                // copy the new file to the .app/xxx.lproj directory
                copy_file(strdup([saved_strings_path UTF8String]), strdup([strings_path UTF8String]), INSTALL_UID, INSTALL_GID, 0755);
                
                // delete our saved .strings file
                chosen_strategy.strategy_unlink(strdup([saved_strings_path UTF8String]));
                
            }
        }
    }
    
    if(strcmp(type, "original") == 0) {
        return ret;
    }
    
    // next step - rename folders in IconState.plist
    char *icon_state_plist = "/var/mobile/Library/SpringBoard/IconState.plist";
    
    // .plist in our temporary directory
    NSString *saved_plist_path = [NSString stringWithFormat:@"%@/IconState.plist", output_dir_path];
    
    // copy the IconState.plist to our temporary directory
    copy_file(icon_state_plist, strdup([saved_plist_path UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
    
    // read the copied file
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:saved_plist_path];

    if([dict objectForKey:@"buttonBar"] != nil) { // dock
        
        for(NSObject *object in [dict objectForKey:@"buttonBar"]) {
            if([object isKindOfClass:[NSMutableDictionary class]]){
                if([(NSMutableDictionary *)object objectForKey:@"displayName"] != nil) {
                    [(NSMutableDictionary *)object setValue:@" " forKey:@"displayName"];
                }
            }
        }
    }
    
    if([dict objectForKey:@"iconLists"] != nil) { // home screen
        
        for(NSArray *array in [dict objectForKey:@"iconLists"]) {
            
            for(NSObject *object in array) {
                if([object isKindOfClass:[NSMutableDictionary class]]){
                    if([(NSMutableDictionary *)object objectForKey:@"displayName"] != nil) {
                        [(NSMutableDictionary *)object setValue:@" " forKey:@"displayName"];
                    }
                }
            }
            
        }
    }
    
    // save the dict into a plist in our dir
    printf("[INFO]: saving IconState.plist to: %s\n", strdup([saved_plist_path UTF8String]));
    [dict writeToFile:saved_plist_path atomically:YES];
    
    // copy the temporary IconState.plist to the original place
    copy_file(strdup([saved_plist_path UTF8String]), icon_state_plist, MOBILE_UID, MOBILE_GID, 0755);
    
    
    return ret;
}

/*
 *  Purpose: renames all 3D touch shortcuts
 */
kern_return_t rename_all_3d_touch_shortcuts(const char * name, char * type) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    char * original_dir_path = "/var/mobile/Library/SpringBoard/ApplicationShortcuts";
    
    DIR *mydir;
    struct dirent *myfile;
    
    int fd = chosen_strategy.strategy_open(original_dir_path, O_RDONLY, 0);
    
    if (fd < 0) {
        ret = KERN_FAILURE;
        return ret;
    }
    
    // output path
    NSString *output_dir_path = get_houdini_dir_for_path(@"shortcuts_renamer");
    
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        NSString *file_name = [NSString stringWithFormat:@"%s", strdup(myfile->d_name)];
        if ([file_name containsString:@".plist"] && ![file_name containsString:@"bck_"]) {
            
            // full original path of the .plist file
            NSString *original_path = [NSString stringWithFormat:@"%s/%@", original_dir_path, file_name];
            
            // path of the destination
            NSString *destination_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, file_name];

            
            copy_file(strdup([original_path UTF8String]), strdup([destination_path UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
            
        }
        
    }
    
    // read each file we copied
    NSArray *directory_content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:output_dir_path error:NULL];
    for (NSString *plist_name in directory_content) {
        
        NSString *copied_plist_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, plist_name];
        printf("COPIEDFILE: %s\n", strdup([copied_plist_path UTF8String]));
        
        // read each plist and do the renaming
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:copied_plist_path];
        
        if([dict objectForKey:@"applicationShortcutItems"] != nil) {
            
            for(NSMutableDictionary *item in [dict objectForKey:@"applicationShortcutItems"]) {
                [item setValue:[NSString stringWithFormat:@"%s", name] forKey:@"title"];
                [item setValue:@" " forKey:@"subtitle"]; // keep subtitle clean
            }
        }
        
        printf("[INFO]: saving the .plist to: %s\n", strdup([copied_plist_path UTF8String]));
        [dict writeToFile:copied_plist_path atomically:YES];
        
        // copy the file back to the original location (read only for others so apps can't overwrite us)
        copy_file(strdup([copied_plist_path UTF8String]), strdup([[NSString stringWithFormat:@"%s/%@", original_dir_path, plist_name] UTF8String]), INSTALL_UID, INSTALL_GID, 0644);
        
    }
    
    // set original_dir_path permissions (_installd:_installd) (read-only for others)
    set_file_permissions(original_dir_path, INSTALL_UID, INSTALL_GID, 0644);
    
    return ret;
}


/*
 *  Purpose: renames all 3D touch shortcuts
 */
kern_return_t apply_passcode_button_theme(char * image_path, char * type) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    char * original_dir_path = "/var/mobile/Library/Caches/MappedImageCache/com.apple.TelephonyUI.TPRevealingRingView";
    
        
    DIR *mydir;
    struct dirent *myfile;
    
    int fd = chosen_strategy.strategy_open(original_dir_path, O_RDONLY, 0);
    
    if (fd < 0)
        return KERN_FAILURE;
    
    // list of "buttons"
    NSMutableArray *cpbitmap_list = [[NSMutableArray alloc] init];
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        if(strcmp(myfile->d_name, ".") == 0 || strcmp(myfile->d_name, "..") == 0)
            continue;
        
        NSString *cpbitmap_filename = [NSString stringWithFormat:@"%s", strdup(myfile->d_name)];
        NSString *cpbitmap_path = [NSString stringWithFormat:@"%s/%@", original_dir_path, cpbitmap_filename];
        
        if(strcmp("original", type) == 0) {
        
            // remove the file
            printf("[INFO]: removing %s\n", [cpbitmap_path UTF8String]);
            chosen_strategy.strategy_unlink(strdup([cpbitmap_path UTF8String]));
            
            continue;
        }
        
        if(![cpbitmap_filename containsString:@"drawsOutside:0"])
            continue;
        
        // bite me
        NSString *key_raw = [cpbitmap_filename stringByReplacingOccurrencesOfString:@"__key{size={" withString:@""];
        NSArray *cpbitmap_size_array = [key_raw componentsSeparatedByString:@"}"];
        if([cpbitmap_size_array count] <= 0)
            continue;
        
        float cpbitmap_size = [[cpbitmap_size_array[0] componentsSeparatedByString:@","][0] floatValue];
        
        if(cpbitmap_size < 50)
            continue;

        [cpbitmap_list addObject:cpbitmap_filename];


    }

    if(strcmp("original", type) == 0)
        return KERN_SUCCESS;
    

    printf("[INFO]: image_path: %s\n", image_path);
    
    
    // convert our image into a cpbitmap, save it then copy it to the original_dir_path
    NSString *saved_cpbitmap_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/passcode_cpbitmap.cpbitmap"];
    [[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%s", image_path]] writeToCPBitmapFile:saved_cpbitmap_path flags:0];

    for (NSString *cpbitmap_path in cpbitmap_list) {
        NSString *combined_path = [NSString stringWithFormat:@"%s/%@", original_dir_path, cpbitmap_path];
        copy_file(strdup([saved_cpbitmap_path UTF8String]), strdup([combined_path UTF8String]), MOBILE_UID, MOBILE_GID, 0555);
    }

    return ret;
}

// Other --

/*
 *  Purpose: sets the active hosts file
 */
kern_return_t set_custom_hosts(boolean_t use_custom) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    // revert first
    copy_file("/etc/bck_hosts", "/etc/hosts", ROOT_UID, WHEEL_GID, 0644);
    
    // delete the old 'bck_hosts' file
    chosen_strategy.strategy_unlink("/etc/bck_hosts");
    
    if(use_custom) {
        
        printf("[INFO]: requested a custom hosts file!\n");
        
        // backup the original one
        copy_file("/etc/hosts", "/etc/bck_hosts", ROOT_UID, WHEEL_GID, 0644);
        
        // copy our custom hosts file
        char *custom_hosts_path = strdup([[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/custom_hosts"] UTF8String]);
        copy_file(custom_hosts_path, "/etc/hosts", ROOT_UID, WHEEL_GID, 0644);
    }
 
    return ret;
}

/*
 *  Purpose: sets a custom emoji font
 */
kern_return_t set_emoji_font(char *font_path) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    printf("[INFO]: using the original AppleColorEmoji@2x.ttc\n");
    
    // revert first
    ret = copy_file("/System/Library/Fonts/Core/bck_AppleColorEmoji@2x.ttc", "/System/Library/Fonts/Core/AppleColorEmoji@2x.ttc", ROOT_UID, WHEEL_GID, 0644);
    
    // delete the old 'bck_hosts' file
    chosen_strategy.strategy_unlink("/System/Library/Fonts/Core/bck_AppleColorEmoji@2x.ttc");
    
    // check if we were given a path
    if(strcmp(font_path, "") != 0) {
        
        // make a backup!
        ret = copy_file("/System/Library/Fonts/Core/AppleColorEmoji@2x.ttc", "/System/Library/Fonts/Core/bck_AppleColorEmoji@2x.ttc", ROOT_UID, WHEEL_GID, 0644);
        
        // ok. now we can copy
        printf("[INFO]: using %s as a default emoji\n", font_path);
        ret = copy_file(font_path, "/System/Library/Fonts/Core/AppleColorEmoji@2x.ttc", ROOT_UID, WHEEL_GID, 0644);
        
    }
    
    return ret;
}
/*
 *  Purpose: returns a scaled image with a given size
 */
UIImage *get_scaled_image(UIImage *original_image, CGSize new_size) {
    
    CGRect scaledImageRect = CGRectZero;
    
    CGFloat aspectWidth = new_size.width / original_image.size.width;
    CGFloat aspectHeight = new_size.height / original_image.size.height;
    CGFloat aspectRatio = MIN ( aspectWidth, aspectHeight );
    
    scaledImageRect.size.width = original_image.size.width * aspectRatio;
    scaledImageRect.size.height = original_image.size.height * aspectRatio;
    scaledImageRect.origin.x = (new_size.width - scaledImageRect.size.width) / 2.0f;
    scaledImageRect.origin.y = (new_size.height - scaledImageRect.size.height) / 2.0f;
    
    UIGraphicsBeginImageContextWithOptions( new_size, NO, 0 );
    [original_image drawInRect:scaledImageRect];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
    
}

/*
 *  Purpose: sets a custom bootlogo
 */
kern_return_t set_bootlogo(char *bootlogo_path) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    NSArray *bootlogo_files = [[NSArray alloc] initWithObjects:
                                    @{@"name": @"apple-logo-black@2x~iphone.png", @"width": @80, @"height": @80},
                                    @{@"name": @"apple-logo-black@3x~iphone.png", @"width": @80, @"height": @80},
                                    @{@"name": @"apple-logo@2x~iphone.png", @"width": @80, @"height": @80},
                                    @{@"name": @"apple-logo@3x~iphone.png", @"width": @80, @"height": @80},
                                    nil];
    
    
    printf("[INFO]: restoring original bootlogos\n");
    
    // restore the originals first
    for(NSDictionary *bootlogo_file_dict in bootlogo_files) {
        
        NSString *bootlogo_name = [bootlogo_file_dict objectForKey:@"name"];
        
         ret = copy_file(strdup([[@"/System/Library/PrivateFrameworks/ProgressUI.framework/bck_" stringByAppendingString:bootlogo_name] UTF8String]), strdup([[@"/System/Library/PrivateFrameworks/ProgressUI.framework/" stringByAppendingString:bootlogo_name] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
        usleep(70000);
    }
    
    // check if we were given a path
    if(strcmp(bootlogo_path, "") != 0) {
        
        for(NSDictionary *bootlogo_file_dict in bootlogo_files) {
            
            NSString *bootlogo_name = [bootlogo_file_dict objectForKey:@"name"];
            int bootlogo_width = [[bootlogo_file_dict objectForKey:@"width"] intValue];
            int bootlogo_height = [[bootlogo_file_dict objectForKey:@"height"] intValue];
            
            // resize the image
            UIImage *original_image = [[UIImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%s", bootlogo_path]];
            UIImage *converted_image = get_scaled_image(original_image, CGSizeMake(bootlogo_width, bootlogo_height));
            
            

            NSData *image_data = UIImagePNGRepresentation(converted_image);
            
            // save the image in our path then copy it
            NSString *saved_png_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/bootlogo.png"];
            [image_data writeToFile:saved_png_path atomically:YES];
            
            // backup the original file first
            ret = copy_file(strdup([[@"/System/Library/PrivateFrameworks/ProgressUI.framework/" stringByAppendingString:bootlogo_name] UTF8String]), strdup([[@"/System/Library/PrivateFrameworks/ProgressUI.framework/bck_" stringByAppendingString:bootlogo_name] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
            
            // copy the mask to each of the icon masks
            ret = copy_file(strdup([saved_png_path UTF8String]), strdup([[NSString stringWithFormat:@"/System/Library/PrivateFrameworks/ProgressUI.framework/%@", bootlogo_name] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
            
        }
        
        
    }
    
 
    return ret;
}

/*
 *  Purpose: creates/replaces a custom Animoji
 */
kern_return_t add_custom_animoji(char *thumbnail_path, char *head_diffuse_path, char *head_AO_path, char *head_SPECROUGHLW_path, char *scnz_file) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    // TODO: allow multiple
    printf("[INFO]: creating new Animoji: 'customanimoji'\n");
    
    // create our dir
    char *puppet_custom_animoji_path = "/System/Library/PrivateFrameworks/AvatarKit.framework/puppets/customanimoji";
    chosen_strategy.strategy_mkdir(puppet_custom_animoji_path);
    chosen_strategy.strategy_chmod(puppet_custom_animoji_path, 0755);
    chosen_strategy.strategy_chown(puppet_custom_animoji_path, ROOT_UID, WHEEL_GID);
    
    // copy the scnz file
    ret = copy_file(scnz_file, strdup([[NSString stringWithFormat:@"%s/customanimoji.scnz", puppet_custom_animoji_path] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
    
    // copy the diffuse file
    ret = copy_file(head_diffuse_path, strdup([[NSString stringWithFormat:@"%s/alien_head_DIFFUSE.jpg", puppet_custom_animoji_path] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
    
    // copy the AO file
    ret = copy_file(head_AO_path, strdup([[NSString stringWithFormat:@"%s/alien_head_AO.jpg", puppet_custom_animoji_path] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
    
    // copy the SPECROUGHLW file
    ret = copy_file(head_SPECROUGHLW_path, strdup([[NSString stringWithFormat:@"%s/alien_head_SPECROUGHLW.jpg", puppet_custom_animoji_path] UTF8String]), ROOT_UID, WHEEL_GID, 0644);
    
    // create thumbnail
    char *thumbnails_custom_animoji_path = "/System/Library/PrivateFrameworks/AvatarKit.framework/thumbnails/customanimoji.png";
    
    ret = copy_file(thumbnail_path, thumbnails_custom_animoji_path, ROOT_UID, WHEEL_GID, 0644);
    

    return ret;
}

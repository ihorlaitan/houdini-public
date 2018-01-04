//
//  utilities.m
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/17/17.
//  Copyright © 2017 Ian Beer. All rights reserved.
//


#include "utilities.h"
#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "drop_payload.h"
#include "sources_control.h"
#include "strategy_control.h"

#import "archive.h"
#import "archive_entry.h"

//#include "LzmaSDKObjC.h"


#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <UIKit/UIKit.h>


mach_port_t priv_port = MACH_PORT_NULL;

kern_return_t set_file_permissions (char * destination_path, int uid, int gid, int perm_num) {
    
    // Chown the destination
    int ret = chosen_strategy.strategy_chown(destination_path, uid, gid);
    
    if (ret == -1) {
        printf("[ERROR]: could not chown destination file: %s\n", destination_path);
        return KERN_FAILURE;
    }
    
    // Chmod the destination
    ret = chosen_strategy.strategy_chmod(destination_path, perm_num);
    
    if (ret == -1) {
        printf("[ERROR]: could not chmod destination file: %s\n", destination_path);
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}

kern_return_t copy_file(char * source_path, char * destination_path, int uid, int gid, int num_perm) {
    
    printf("[INFO]: deleting %s\n", destination_path);
    
    // unlink destination first
    chosen_strategy.strategy_unlink(destination_path);
    
    printf("[INFO]: copying files from (%s) to (%s)..\n", source_path, destination_path);
                                                                  
    size_t read_size, write_size;
    char buffer[100];
    
    int read_fd = chosen_strategy.strategy_open(source_path, O_RDONLY, 0);
    int write_fd = chosen_strategy.strategy_open(destination_path, O_RDWR | O_CREAT | O_APPEND, 0777);

    FILE *read_file = fdopen(read_fd, "r");
    FILE *write_file = fdopen(write_fd, "wb");
    
    if(read_file == NULL) {
        printf("[INFO]: can't copy. failed to read file from path: %s\n", source_path);
        return KERN_FAILURE;
        
    }
    
    if(write_file == NULL) {
        printf("[INFO]: can't copy. failed to write file with path: %s\n", destination_path);
        return KERN_FAILURE;
    }
    
    while(feof(read_file) == 0) {
        
        if((read_size = fread(buffer, 1, 100, read_file)) != 100) {
            
            if(ferror(read_file) != 0) {
                printf("[ERROR]: could not read from: %s\n", source_path);
                return KERN_FAILURE;
            }
        }
        
        if((write_size = fwrite(buffer, 1, read_size, write_file)) != read_size) {
            printf("[ERROR]: could not write to: %s\n", destination_path);
            return KERN_FAILURE;
        }
    }	
    
    fclose(read_file);
    fclose(write_file);
    
    close(read_fd);
    close(write_fd);
    

    // Chown the destination
    kern_return_t ret = set_file_permissions(destination_path, uid, gid, num_perm);
    if (ret != KERN_SUCCESS) {
        return KERN_FAILURE;
    }
    

    return KERN_SUCCESS;
}


NSString* get_houdini_dir_for_path(NSString *dir_name) {
    
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *final_path = [docDir stringByAppendingPathComponent:dir_name];
    
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:final_path isDirectory:&isDir])
    {
        if([fm createDirectoryAtPath:final_path withIntermediateDirectories:YES attributes:nil error:nil])
            printf("[INFO]: created houdini dir with name: %s\n", [dir_name UTF8String]);
        else
            printf("[ERROR]: could not create dir with name: %s\n", [dir_name UTF8String]);
    }

    return final_path;
}

NSMutableData * get_current_wallpaper() {
    
    FILE *binary_file;
    long binary_size;
    void *binary_raw;

    int fd = chosen_strategy.strategy_open("/var/mobile/Library/SpringBoard/LockBackgroundThumbnail.jpg", O_RDONLY, 0);

    if (fd < 0)
        return nil;

    binary_file = fdopen(fd, "r");

    fseek(binary_file, 0, SEEK_END);
    binary_size = ftell(binary_file);
    rewind(binary_file);
    binary_raw = malloc(binary_size * (sizeof(void*)));
    fread(binary_raw, sizeof(char), binary_size, binary_file);


    close(fd);
    fclose(binary_file);

    return [NSData dataWithBytesNoCopy:binary_raw length:binary_size].mutableCopy;
}

void dlopen_it() {
    
}

void kill_springboard(int sig) {
    
//    if ([[[UIDevice currentDevice] systemVersion] containsString:@"11"] && sig == SIGSTOP) {
//        printf("[INFO]: got a SIGSTOP signal to SpringBoard. Not allowed!\n");
//        return;
//    }
    
    printf("[INFO]: requested to kill SpringBoard!\n");
    pid_t springboard_pid = chosen_strategy.strategy_pid_for_name("SpringBoard");
    printf("springboard's pid: %d", springboard_pid);
    sleep(1);
    chosen_strategy.strategy_kill(springboard_pid, sig);
    
    if(sig == SIGKILL)
        exit(0);
}




// TODO: move to its own utility file
void change_carrier_name(NSString *new_name) {
    
    char *path = "/var/mobile/Library/Carrier Bundles/Overlay";
    
    DIR *mydir;
    struct dirent *myfile;
    
    printf("[INFO]: opening %s carriers folder\n", path);
    int fd = remote_open(PRIV_PORT(), path, O_RDONLY, 0);
    
    if (fd < 0)
        return;
    
    // output path
    NSString *output_dir_path = get_houdini_dir_for_path(@"carriers");
    
    mydir = fdopendir(fd);
    while((myfile = readdir(mydir)) != NULL) {
        
        char *name = myfile->d_name;
        
        if(strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
            continue;
        
        // get the file (path + name)
        copy_file(strdup([[NSString stringWithFormat:@"%s/%s", path, name] UTF8String]), strdup([[NSString stringWithFormat:@"%@/%s", output_dir_path, name] UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
        
        // backup the original file
        chosen_strategy.strategy_rename(strdup([[NSString stringWithFormat:@"%s/%s", path, name] UTF8String]),
                                        strdup([[NSString stringWithFormat:@"%s/%s.backup", path, name] UTF8String]));

        
    }
    
    closedir(mydir);
    close(fd);
    
    // read each file we copied
    NSArray *directory_content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:output_dir_path error:NULL];
    for (NSString *plist_name in directory_content) {
        
        
        NSString *copied_plist_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, plist_name];
        printf("[INFO]: copied file: %s\n", strdup([copied_plist_path UTF8String]));
        
        // read each plist and do the renaming
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:copied_plist_path];
        
        if(dict == NULL)
            continue;
        
        [dict setObject:new_name forKey:@"CarrierName"];
        
        if ([dict objectForKey:@"MVNOOverrides"]) {
            
            NSObject *object = [dict objectForKey:@"MVNOOverrides"];
            
            if([object isKindOfClass:[NSMutableDictionary class]]){
                NSMutableDictionary *mv_no_overriders_dict = (NSMutableDictionary *)object;
                
                if([mv_no_overriders_dict objectForKey:@"StatusBarImages"]) {
                    
                    NSMutableArray *status_bar_images_array = [mv_no_overriders_dict objectForKey:@"StatusBarImages"];
                    
                    for (NSMutableDictionary *item in status_bar_images_array) {
                        
                        if([item objectForKey:@"StatusBarCarrierName"]) {
                             [item setObject:new_name forKey:@"StatusBarCarrierName"];
                        }
                        
                        if([item objectForKey:@"CarrierName"]) {
                            [item setObject:new_name forKey:@"CarrierName"];
                        }
                    }
                }
                
            }
        }
        
        [dict setObject:new_name forKey:@"OverrideOperatorName"];
        [dict setObject:new_name forKey:@"OverrideOperatorWiFiName"];
        
        if ([dict objectForKey:@"IMSConfigSecondaryOverlay"]) {
            
            NSMutableDictionary *ims_config_dict = (NSMutableDictionary *)[dict objectForKey:@"IMSConfigSecondaryOverlay"];
            
            if([ims_config_dict objectForKey:@"CarrierName"]) {
                [ims_config_dict setValue:new_name forKey:@"CarrierName"];
            }
        }
        
        if ([dict objectForKey:@"StatusBarImages"]) {
            
            NSMutableArray *status_bar_images_array = [dict objectForKey:@"StatusBarImages"];
            
            for (NSMutableDictionary *item in status_bar_images_array) {
                
                if([item objectForKey:@"StatusBarCarrierName"]) {
                    [item setObject:new_name forKey:@"StatusBarCarrierName"];
                }
                
                if([item objectForKey:@"CarrierName"]) {
                    [item setObject:new_name forKey:@"CarrierName"];
                }
            }

        }
        
        
        NSString *saved_plist_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, [plist_name lastPathComponent]];

        printf("[INFO]: saving carrier plist to: %s\n", strdup([saved_plist_path UTF8String]));
        [dict writeToFile:saved_plist_path atomically:YES];
        
        // move the file back
        copy_file(strdup([saved_plist_path UTF8String]), strdup([[NSString stringWithFormat:@"%s/%@", path, plist_name] UTF8String]), INSTALL_UID, INSTALL_GID, 0755);
        
    }
}

/*
 *  Purpose: used by 'extract' to read archive data and write it
 */
kern_return_t copy_data(struct archive *ar, struct archive *aw) {
    int r;
    const void *buff;
    size_t size;
    la_int64_t offset;
    
    for (;;) {
        r = archive_read_data_block(ar, &buff, &size, &offset);
        if (r == ARCHIVE_EOF)
            return KERN_SUCCESS;
        if (r < ARCHIVE_OK)
            return KERN_FAILURE;
        r = archive_write_data_block(aw, buff, size, offset);
        if (r < ARCHIVE_OK)
            return KERN_FAILURE;
    }
}

/*
 *  Purpose: extracts a file at a given path
 */
kern_return_t extract(char *path, char* extracted_dir_name) {
    
    struct archive_entry *entry;
    int r;
    
    struct archive *a = archive_read_new();
    struct archive *ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, 0);
    
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    
    if ((r = archive_read_open_filename(a, path, 10240)))
        printf("[ERROR]: could not open archive file: %s\n", archive_error_string(a));
    
    NSString *documents_path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    for (;;) {
        r = archive_read_next_header(a, &entry);
        
        if (r == ARCHIVE_EOF)
            break;
        
        if (r != ARCHIVE_OK) {
            printf("[ERROR]: could not extract files: %s\n", archive_error_string(a));
            return KERN_FAILURE;
        }
        
        archive_entry_set_pathname(entry, [[NSString stringWithFormat:@"%@/%s/%s", documents_path, extracted_dir_name, archive_entry_pathname(entry)] UTF8String ]);
        printf("[INFO]: extracting: %s\n", archive_entry_pathname(entry));
        
        r = archive_write_header(ext, entry);
        if (r != ARCHIVE_OK)
            printf("[ERROR]: could not write header of extracted file: %s\n", archive_error_string(ext));
        else {
            copy_data(a, ext);
            r = archive_write_finish_entry(ext);
            if (r != ARCHIVE_OK)
                printf("[ERROR]: could not write data of extracted file: %s\n", archive_error_string(ext));
        }
    }
    
    archive_read_close(a);
    archive_read_free(a);
    
    archive_write_close(ext);
    archive_write_free(ext);
    
    return KERN_SUCCESS;
}


/*
 *  Purpose: decompresses a debian package and returns the path to the data folder
 */
const char * decompress_deb_file(char *path) {
    
    NSString *documents_path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    NSString *extracted_deb_path = [documents_path stringByAppendingString:@"/extracted_deb"];
    NSString *extracted_data_path = [extracted_deb_path stringByAppendingString:@"/extracted_data"];
    
    // delete the content of both directories
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:extracted_deb_path error:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[extracted_deb_path stringByAppendingPathComponent:file] error:nil];
    }
    
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:extracted_data_path error:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[extracted_data_path stringByAppendingPathComponent:file] error:nil];
    }
    
    // create extracted_deb and extracted_data (if they don't exist)
    [[NSFileManager defaultManager] createDirectoryAtPath:extracted_deb_path withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:extracted_data_path withIntermediateDirectories:YES attributes:nil error:nil];
    
    
    kern_return_t ret = KERN_SUCCESS;
    ret = extract(path, "extracted_deb");
    
    if(ret != KERN_SUCCESS) {
        printf("[ERROR]: extracting .deb failed!\n");
        return "";
    }
    
    NSString *data_file_name = @"";
    NSArray *directory_content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:extracted_deb_path error:NULL];
    for (NSString *name in directory_content) {
        if([name containsString:@"data."]) {
            data_file_name = name;
            break;
        }
    }
    
    // lzma needs a different extraction method
    if([data_file_name containsString:@"lzmdqdwa"]) {
        
        // TODO: probably move this to extract_lzma
        
        NSString *data_file_path = [NSString stringWithFormat:@"%@/%@", extracted_deb_path, data_file_name];
//        [[NSFileManager defaultManager] moveItemAtPath:data_file_path toPath:[data_file_path stringByReplacingOccurrencesOfString:@".lzma" withString:@".lzma.7z"] error:nil];
        
//        data_file_path = [data_file_path stringByReplacingOccurrencesOfString:@".lzma" withString:@".lzma.7z"];
//        
//        LzmaSDKObjCReader *reader = [[LzmaSDKObjCReader alloc] initWithFileURL:[NSURL fileURLWithPath:data_file_path] andType:LzmaSDKObjCFileType7z];
//        
//        NSLog(@"reader init path: %@", data_file_path);
//        
//
//        NSError * error = nil;
//        [reader open:&error];
//        
//        if(error != nil) {
//            printf("[ERROR]: opening file using lzma reader: %s\n", [[error localizedDescription] UTF8String]);
//            return "";
//        }
//        
//        NSMutableArray * items = [NSMutableArray array]; // Array with selected items.
//        // Iterate all archive items, track what items do you need & hold them in array.
//        [reader iterateWithHandler:^BOOL(LzmaSDKObjCItem * item, NSError * error){
//            NSLog(@"[LZMA]: \n%@", item);
//            if (item) [items addObject:item]; // if needs this item - store to array.
//            return YES; // YES - continue iterate, NO - stop iteration
//        }];
//        
//        [reader extract:items toPath:[NSString stringWithFormat: @"%@/extracted_deb/extracted_data/", documents_path] withFullPaths:NO];
//        
    } else {
        ret = extract(strdup([[NSString stringWithFormat:@"%@/%@", extracted_deb_path, data_file_name] UTF8String]), "extracted_deb/extracted_data");
    
        if(ret != KERN_SUCCESS) {
            printf("[ERROR]: extracting .data.x failed!\n");
            return "";
        }
    }
    
    
    
    return [extracted_data_path UTF8String];
}


/*
    Purpose: returns the path to .app of Houdini
*/
char* get_houdini_app_path() {
    
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
    int len = 4096;
    char* path = malloc(len);
    
    CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8*)path, len);
    
    return path;
}

/*
    Purpose: persists the privileged port for later uses by running jailbreakd
*/
void persist_priv_port() {
    return;
    printf("[INFO]: running jailbreakd daemon..\n");
    
    mach_port_t launchd_task_port = find_task_port_for_path("/sbin/launchd");
    mach_port_t springboard_task_port = find_task_port_for_path("SpringBoard");
    
    spawn_bundle_binary_with_priv_port(launchd_task_port, springboard_task_port, "jailbreakd", (char**)&(const char*[]){"jailbreakd", NULL}, (char**)&(const char*[]){NULL});
    
}

mach_port_t get_priv_port() {
    return priv_port;
}

void utilities_init(mach_port_t sport) {
    priv_port = sport;


    
}

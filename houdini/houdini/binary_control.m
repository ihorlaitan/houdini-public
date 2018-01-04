//
//  binary_control.m
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/16/17.
//  Copyright © 2017 Ian Beer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

#include "remote_file.h"
#include "triple_fetch_remote_call.h"
#include "remote_memory.h"
#include "remote_ports.h"
#include "NSData+Reading.h"
#include "binary_control.h"
#include "utilities.h"

struct thin_header headerAtOffset(NSData *binary, uint32_t offset) {
    struct thin_header macho;
    macho.offset = offset;
    macho.header = *(struct mach_header *)(binary.bytes + offset);
    if (macho.header.magic == MH_MAGIC || macho.header.magic == MH_CIGAM) {
        macho.size = sizeof(struct mach_header);
    } else {
        macho.size = sizeof(struct mach_header_64);
    }
    if (macho.header.cputype != CPU_TYPE_X86_64 && macho.header.cputype != CPU_TYPE_I386 && macho.header.cputype != CPU_TYPE_ARM && macho.header.cputype != CPU_TYPE_ARM64){
        macho.size = 0;
    }
    
    return macho;
}

struct thin_header *headersFromBinary(struct thin_header *headers, NSData *binary, uint32_t *amount) {
    // In a MachO/FAT binary the first 4 bytes is a magic number
    // which gives details about the type of binary it is
    // CIGAM and co. mean the target binary has a byte order
    // in reverse relation to the host machine so we have to swap the bytes
    uint32_t magic = [binary intAtOffset:0];
    
    uint32_t numArchs = 0;
    
    // a FAT file is basically a collection of thin MachO binaries
    if (magic == MH_MAGIC || magic == MH_MAGIC_64) {
        struct thin_header macho = headerAtOffset(binary, 0);
        if (macho.size > 0) {
            printf("[INFO]: Found XX thin header...\n");
            
            numArchs++;
            headers[0] = macho;
        }
        
    } else {
        printf("[ERROR]: no headers found\n");
    }
    
    *amount = numArchs;
    
    return headers;
}

BOOL binaryHasLoadCommandForDylib(NSMutableData *binary, NSString *dylib, uint32_t *lastOffset, struct thin_header macho) {
    binary.currentOffset = macho.size + macho.offset;
    unsigned int loadOffset = (unsigned int)binary.currentOffset;
    
    // Loop through compatible LC_LOAD commands until we find one which points
    // to the given dylib and tell the caller where it is and if it exists
    for (int i = 0; i < macho.header.ncmds; i++) {
        if (binary.currentOffset >= binary.length ||
            binary.currentOffset > macho.offset + macho.size + macho.header.sizeofcmds)
            break;
        
        uint32_t cmd  = [binary intAtOffset:binary.currentOffset];
        uint32_t size = [binary intAtOffset:binary.currentOffset + 4];
        
        switch (cmd) {
            case LC_REEXPORT_DYLIB:
            case LC_LOAD_UPWARD_DYLIB:
            case LC_LOAD_WEAK_DYLIB:
            case LC_LOAD_DYLIB: {
                struct dylib_command command = *(struct dylib_command *)(binary.bytes + binary.currentOffset);
                char *name = (char *)[[binary subdataWithRange:NSMakeRange(binary.currentOffset + command.dylib.name.offset, command.cmdsize - command.dylib.name.offset)] bytes];
                
                if ([@(name) isEqualToString:dylib]) {
                    *lastOffset = (unsigned int)binary.currentOffset;
                    return YES;
                }
                
                binary.currentOffset += size;
                loadOffset = (unsigned int)binary.currentOffset;
                break;
            }
            default:
                binary.currentOffset += size;
                break;
        }
    }
    
    if (lastOffset != NULL)
        *lastOffset = loadOffset;
    
    return NO;
}

// TODO: REMOVE THIS
#define LC(LOADCOMMAND) ({ \
const char *c = ""; \
if (LOADCOMMAND == LC_REEXPORT_DYLIB) \
c = "LC_REEXPORT_DYLIB";\
else if (LOADCOMMAND == LC_LOAD_WEAK_DYLIB) \
c = "LC_LOAD_WEAK_DYLIB";\
else if (LOADCOMMAND == LC_LOAD_UPWARD_DYLIB) \
c = "LC_LOAD_UPWARD_DYLIB";\
else if (LOADCOMMAND == LC_LOAD_DYLIB) \
c = "LC_LOAD_DYLIB";\
c;\
})

BOOL insertLoadEntryIntoBinary(char *dylib_path, NSMutableData *binary, struct thin_header macho) {

    uint32_t type = LC_LOAD_DYLIB;
    NSString *dylibPath = [NSString stringWithFormat:@"%s", dylib_path];
    
    // parse load commands to see if our load command is already there
    uint32_t lastOffset = 0;
    if (binaryHasLoadCommandForDylib(binary, dylibPath, &lastOffset, macho)) {
        // there already exists a load command for this payload so change the command type
        uint32_t originalType = *(uint32_t *)(binary.bytes + lastOffset);
        if (originalType != type) {
            printf("[INFO]: a load command already exists for %s. Changing command type from %s to desired %s\n", dylibPath.UTF8String, LC(originalType), LC(type));
            [binary replaceBytesInRange:NSMakeRange(lastOffset, sizeof(type)) withBytes:&type];
        } else {
            printf("[INFO]: load command already exists\n");
        }
        
        return YES;
    }
    
    // create a new load command
    unsigned int length = (unsigned int)sizeof(struct dylib_command) + (unsigned int)dylibPath.length;
    unsigned int padding = (8 - (length % 8));
    
    // check if data we are replacing is null
    NSData *occupant = [binary subdataWithRange:NSMakeRange(macho.header.sizeofcmds + macho.offset + macho.size,
                                                            length + padding)];
    
    // All operations in optool try to maintain a constant byte size of the executable
    // so we don't want to append new bytes to the binary (that would break the executable
    // since everything is offset-based–we'd have to go in and adjust every offset)
    // So instead take advantage of the huge amount of padding after the load commands
    if (strcmp([occupant bytes], "\0")) {
        printf("cannot inject payload into %s because there is no room\n", dylibPath.fileSystemRepresentation);
        return NO;
    }
    
    printf("[INFO]: injecting given binary..\n");
    
    struct dylib_command command;
    struct dylib dylib;
    dylib.name.offset = sizeof(struct dylib_command);
    dylib.timestamp = 2; // load commands I've seen use 2 for some reason
    dylib.current_version = 0;
    dylib.compatibility_version = 0;
    command.cmd = type;
    command.dylib = dylib;
    command.cmdsize = length + padding;
    
    unsigned int zeroByte = 0;
    NSMutableData *commandData = [NSMutableData data];
    [commandData appendBytes:&command length:sizeof(struct dylib_command)];
    [commandData appendData:[dylibPath dataUsingEncoding:NSASCIIStringEncoding]];
    [commandData appendBytes:&zeroByte length:padding];
    
    // remove enough null bytes to account of our inserted data
    [binary replaceBytesInRange:NSMakeRange(macho.offset + macho.header.sizeofcmds + macho.size, commandData.length)
                      withBytes:0
                         length:0];
    // insert the data
    [binary replaceBytesInRange:NSMakeRange(lastOffset, 0) withBytes:commandData.bytes length:commandData.length];
    
    // fix the existing header
    macho.header.ncmds += 1;
    macho.header.sizeofcmds += command.cmdsize;
    
    // this is safe to do in 32bit because the 4 bytes after the header are still being put back
    [binary replaceBytesInRange:NSMakeRange(macho.offset, sizeof(macho.header)) withBytes:&macho.header];
    
    return YES;
}


kern_return_t inject_binary() {
//    
//    char executable_path[160];
//    sprintf(executable_path, "%s/%s", strdup(_app_dir->app_path), strdup(_app_dir->executable));
//    
//    printf("exec: %s\n", executable_path);
//    
//    FILE *binary_file;
//    long binary_size;
//    void *binary_raw;
//    
//    //    int fd = open(executable_path, O_RDONLY);
//    int fd = remote_open(PRIV_PORT(), executable_path, O_RDONLY, 0);
//    
//    if (fd < 0)
//        return KERN_FAILURE;
//    
//    binary_file = fdopen(fd, "r");
//    
//    fseek(binary_file, 0, SEEK_END);
//    binary_size = ftell(binary_file);
//    rewind(binary_file);
//    binary_raw = malloc(binary_size * (sizeof(void*)));
//    fread(binary_raw, sizeof(char), binary_size, binary_file);
//    
//    
//    close(fd);
//    fclose(binary_file);
//    
//    NSMutableData *binary_data = [NSData dataWithBytesNoCopy:binary_raw length:binary_size].mutableCopy;
//    
//    if (!binary_data)
//        return KERN_FAILURE;
//    
//    struct thin_header headers[4];
//    uint32_t numHeaders = 0;
//    headersFromBinary(headers, binary_data, &numHeaders);
//    
//    if (numHeaders == 0) {
//        printf("[ERROR]: could not get headers from given binary\n");
//        return KERN_FAILURE;
//    }
//    
//    printf("[INFO]: using the gived dylib with path: %s\n", _app_dir->jdylib_path);
//    
//    // Loop through all of the thin headers we found for each operation
//    for (uint32_t i = 0; i < numHeaders; i++) {
//        struct thin_header macho = headers[i];
//        
//        if (insertLoadEntryIntoBinary(_app_dir->jdylib_path, binary_data, macho)) {
//            printf("[INFO]: successfully injected %s's binary\n", _app_dir->display_name);
//        } else {
//            printf("[INFO]: could not inject %s's binary\n", _app_dir->display_name);
//            return KERN_FAILURE;
//        }
//    }
//    
//    // TODO: make a backup first
//    
//    // write binary to our directory (since we have r/w permissions)
//    char output_path[256];
//    sprintf(output_path, "%s/%s", get_houdini_binaries_path(), strdup(_app_dir->executable));
//
//    printf("[INFO]: writing our new binary to our directory: %s\n", output_path);
//    if (![binary_data writeToFile:[NSString stringWithFormat:@"%s", output_path] atomically:NO]) {
//        printf("[ERROR]: could not write our new binary for %s to (%s)\n", _app_dir->identifier, output_path);
//        return KERN_FAILURE;
//    }
//    
//    // copy our binary to the app's folder
////    copy_file(output_path, executable_path);
    return KERN_SUCCESS;
}


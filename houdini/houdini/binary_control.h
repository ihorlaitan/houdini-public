//
//  binary_control.h
//  Houdini
//
//  Created by Abraham Masri on 11/16/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//


#import <Foundation/Foundation.h>
#include "apps_control.h"

#ifndef binary_control_h
#define binary_control_h

// we pass around this header which includes some extra information
// and a 32-bit header which we used for both 32-bit and 64-bit files
// since the 64-bit just adds an extra field to the end which we don't need
struct thin_header {
    uint32_t offset;
    uint32_t size;
    struct mach_header header;
};

struct thin_header *headersFromBinary(struct thin_header *, NSData *, uint32_t *);
kern_return_t inject_binary();
void binary_control_init(mach_port_t);

#endif /* binary_control_h */

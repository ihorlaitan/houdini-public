//
//  sources_control.h
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#ifndef sources_control_h
#define sources_control_h

#include "source.h"

kern_return_t add_source(NSString * url);

void remove_source(Source *source);
void sources_control_init();
#endif /* sources_control_h */

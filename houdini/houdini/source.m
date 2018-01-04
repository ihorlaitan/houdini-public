//
//  source.m
//  houdini
//
//  Created by Abraham Masri on 11/17/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "source.h"

@implementation Source

- (id)initWithURL:(NSString *)url
 {
    
    self = [self init];
    if (self) {
        self.url = url;
    }
    return self;
}

- (NSString *) get_name
{
    return self.name;
}
- (NSString *) get_url
{
    return self.url;
}

- (NSString *) get_desc
{
    return self.desc;
}

- (NSString *) get_packages_url
{
    return self.packages_url;
}

- (NSString *) get_sourceinfo_path
{
    return self.sourceinfo_path;
}
@end

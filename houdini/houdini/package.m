//
//  package.m
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/17/17.
//  Copyright © 2017 Ian Beer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "package.h"

@implementation Package

- (id)initWithName:(NSString *)name type:(NSString *)type short_desc:(NSString *)short_desc url:(NSString *)url;
 {
    
    self = [self init];
    if (self) {
        self.name = name;
        self.type = type;
        self.short_desc = short_desc;
        self.url = url;
    }
    return self;
}

- (NSString *) get_name
{
    return self.name;
}

- (NSString *) get_author
{
    return self.author;
}

- (Source *) get_source
{
    return self.source;
}

- (NSString *) get_version
{
    return self.version;
}

- (NSString *) get_type
{
    return self.type;
}

- (NSString *) get_short_desc
{
    return self.short_desc;
}

- (NSString *) get_url
{
    return self.url;
}

- (UIImage *) get_thumbnail_image
{
    return self.thumbnail_image;
}


- (NSString *) get_thumbnail
{
    return self.thumbnail;
}


- (NSString *) get_depiction
{
    return self.depiction;
}

- (BOOL) get_installed
{
    return self.installed;
}
@end

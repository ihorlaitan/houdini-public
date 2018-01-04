//
//  package.h
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/17/17.
//  Copyright © 2017 Ian Beer. All rights reserved.
//

#ifndef package_h
#define package_h

#include "source.h"
#include <UIKit/UIKit.h>

@interface Package : NSObject

@property(nonatomic, strong) NSString *name; // Package name
@property(nonatomic, strong) NSString *author; // The author of the package
@property(nonatomic, strong) Source *source; // The source of the package
@property(nonatomic, strong) NSString *version; // The version the package
@property(nonatomic, strong) NSString *depiction; // The URL of the package's description
@property(nonatomic, strong) NSString *short_desc; // Short package description (shown in table view cell)
@property(nonatomic, strong) NSString *long_desc; // Long package description (shown when package is being viewed)
@property(nonatomic, strong) NSString *type; // can be: tweak/theme
@property(nonatomic, strong) NSString *url; // URL to the package
@property(nonatomic, strong) NSString *thumbnail; // Thumbnail URL to the package
@property(nonatomic, strong) UIImage *thumbnail_image; // Thumbnail Image to the package
@property BOOL *installed;

- (id) initWithName:(NSString *)name type:(NSString *)type short_desc:(NSString *)short_desc url:(NSString *)url;

- (NSString *) get_name;
- (NSString *) get_author;
- (NSString *) get_source;
- (NSString *) get_version;
- (NSString *) get_short_desc;
- (NSString *) get_type;
- (NSString *) get_depiction;
- (NSString *) get_url;
- (NSString *) get_thumbnail;
- (UIImage *) get_thumbnail_image;
- (BOOL) get_installed;

@end

#endif /* package_h */

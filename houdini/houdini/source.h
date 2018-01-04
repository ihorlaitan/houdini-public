//
//  source.h
//  houdini
//
//  Created by Abraham Masri on 11/17/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#ifndef source_h
#define source_h

@interface Source : NSObject

@property(nonatomic, strong) NSString *name; // Source name
@property(nonatomic, strong) NSString *url; // Source's URL
@property(nonatomic, strong) NSString *desc; // Source's Description
@property(nonatomic, strong) NSString *packages_url; // URL to the source's packages
@property(nonatomic, strong) NSString *sourceinfo_path; // Path to the local sourceinfo file

- (id) initWithURL:(NSString *)url;

- (NSString *) get_name;
- (NSString *) get_url;
- (NSString *) get_desc;
- (NSString *) get_packages_url;
- (NSString *) get_sourceinfo_path;

@end

#endif /* source_h */

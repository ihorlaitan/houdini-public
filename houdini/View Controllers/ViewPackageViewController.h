//
//  ViewPackageViewController.h
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "package.h"


@interface ViewPackageViewController : UIViewController


@property(nonatomic, strong) Package *package; // The package associated to this

- (void) setPackage:(Package *) __package;

@end



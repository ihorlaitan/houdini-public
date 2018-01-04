//
//  PackagesViewController.h
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "package.h"


@interface PackagesViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UISegmentedControl *packageTypeSegmentedControl;
- (void) presentPackageView:(Package *) package;

@end


@protocol packageCellButtonTapped <NSObject>
-(void)presentPackageView:(Package *) package;
@end


@interface PackageCell : UITableViewCell


@property (weak, nonatomic) IBOutlet UIImageView *packageIcon;

@property (weak, nonatomic) IBOutlet UILabel *packageTitle;
@property (weak, nonatomic) IBOutlet UILabel *packageSource;
@property (weak, nonatomic) IBOutlet UILabel *packageDesc;
@property (weak, nonatomic) IBOutlet UIButton *packageButton;

@property(nonatomic, strong) Package *package; // The package associated to this cell

- (void) setPackage:(Package *) __package;

@property (nonatomic, retain) PackagesViewController *mainViewController;
@end



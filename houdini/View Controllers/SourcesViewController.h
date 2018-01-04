//
//  SourcesViewController.h
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "source.h"


@interface SourcesViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>


@end

@interface SourceCell : UITableViewCell


@property (weak, nonatomic) IBOutlet UIImageView *sourceIcon;

@property (weak, nonatomic) IBOutlet UILabel *sourceTitle;
@property (weak, nonatomic) IBOutlet UILabel *sourceURL;

@property(nonatomic, strong) Source *source; // The source associated to this cell

- (void) setSource:(Source *) __source;

@property (nonatomic, retain) SourcesViewController *mainViewController;
@end



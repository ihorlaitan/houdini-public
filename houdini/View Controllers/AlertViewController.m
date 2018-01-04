//
//  AlertViewController.m
//  Saigon
//
//  Created by Abraham Masri on 11/29/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "Utilities.h"

@interface AlertViewController : UIViewController
@property (retain, nonatomic) IBOutlet UIView *containerView;

@property (retain, nonatomic) IBOutlet UILabel *titleLabel;
@property (retain, nonatomic) IBOutlet UILabel *descriptionLabel;

@property (retain, nonatomic) IBOutlet UIButton *rebootButton;

@end

@interface AlertViewController ()

@end

@implementation AlertViewController


- (void)viewDidLoad {
    [super viewDidLoad];
   
    extern NSString * error_message;

    [self.containerView setAlpha:0.0];
    self.containerView.transform = CGAffineTransformMakeTranslation(0, 50);


}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [UIView animateWithDuration:0.8 animations:^{
        [self.view setAlpha:1];
        [self.containerView setAlpha:1.0];
        self.containerView.transform = CGAffineTransformMakeTranslation(0, 0);
    } completion:nil];
}



@end

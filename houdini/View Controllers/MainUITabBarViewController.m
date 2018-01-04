//
//  MainUITabBarViewController.m
//  nsxpc2pc
//
//  Created by Abraham Masri on 11/21/17.
//  Copyright © 2017 Ian Beer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "utilities.h"

@interface MainUITabBarViewController : UITabBarController
@end

@implementation UIImage(Overlay)

- (UIImage *)imageWithColor:(UIColor *)color1
{
    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, self.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
    CGContextClipToMask(context, rect, self.CGImage);
    [color1 setFill];
    CGContextFillRect(context, rect);
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
@end

@implementation MainUITabBarViewController


- (void)addGradient {
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    
    gradient.frame = view.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.0941 green:0.5882 blue:0.7765 alpha:1.0].CGColor, (id)[UIColor colorWithRed:0.1686 green:0.1255 blue:0.3216 alpha:1.0].CGColor];
    
    [view.layer insertSublayer:gradient atIndex:0];
    [self.view insertSubview:view atIndex:0];
    
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // set our background as the user's wallpaper
    NSMutableData *currentWallpaper = get_current_wallpaper();
    
    if(currentWallpaper != nil) {
        
        UIGraphicsBeginImageContext(self.view.frame.size);
        [[UIImage imageWithData:currentWallpaper] drawInRect:self.view.bounds];
        UIImage *wallpaperImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [self.view setBackgroundColor:[UIColor colorWithPatternImage: wallpaperImage]];
        
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.frame = self.view.bounds;
        blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [self.view insertSubview:blurEffectView atIndex:0];
    } else {
        [self addGradient];
    }
    

    [self.tabBar setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.0f]];
    [self.tabBar setBackgroundImage:[UIImage new]];
    
    UIColor * unselectedColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.4f];

    [[UITabBarItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:unselectedColor, NSForegroundColorAttributeName, nil]
                                             forState:UIControlStateNormal];
    
    for(UITabBarItem *item in self.tabBar.items)
        item.image = [[item.selectedImage imageWithColor:unselectedColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

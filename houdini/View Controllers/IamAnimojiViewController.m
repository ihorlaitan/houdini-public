//
//  IamAnimojiViewController.m
//  Houdini
//
//  Created by Abraham Masri on 12/02/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//


#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "apps_control.h"
#include "utilities.h"
#include "package.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define ANIMOJIOUTLINE_SIZE                         300
#define ANIMOJIOUTLINE_EYE_WIDTH                    500
#define ANIMOJIOUTLINE_EYE_HEIGHT                   450

#define ALIEN_HEAD_AO_SIZE                          512

@interface IamAnimojiViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>


@property (weak, nonatomic) IBOutlet UISegmentedControl *skintoneSegmentedControl;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *imagePreview;
@property (weak, nonatomic) IBOutlet UIButton *openCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@end

@implementation IamAnimojiViewController

- (void)hideInstalling {
    
    [self.actionButton setHidden:NO];
    [self.activityIndicator setHidden:YES];
    [self.dismissButton setHidden:NO];
}

- (IBAction)openCameraTapped:(id)sender {

    UIView *overlay_view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
    [overlay_view setUserInteractionEnabled:NO];
    
    UIImageView *overlay_imageview = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.frame.size.width / 2 - (ANIMOJIOUTLINE_SIZE / 2), self.view.frame.size.height / 2 - (ANIMOJIOUTLINE_SIZE / 2), ANIMOJIOUTLINE_SIZE, ANIMOJIOUTLINE_SIZE)];
    
    [overlay_imageview setImage:[UIImage imageNamed:@"AnimojiOutline"]];
    
    [overlay_view addSubview:overlay_imageview];
    
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = NO;
    
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    picker.cameraOverlayView = overlay_view;
    picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    [self presentViewController:picker animated:YES completion:nil];
    
}

-(UIImage *)cropImage:(UIImage*)image cropRect:(CGRect)rect
{
    
    CGImageRef subImage = CGImageCreateWithImageInRect(image.CGImage, rect);
    UIImage *croppedImage = [UIImage imageWithCGImage:subImage];
    CGImageRelease(subImage);
    return croppedImage;
}


-(UIImage *)colorizeImage:(UIImage*)image
{
    UIColor *color = [UIColor redColor];
    
    switch (self.skintoneSegmentedControl.selectedSegmentIndex) {
        case 0: // white
            color = [UIColor colorWithRed:245.0f/255.0f green:231.0f/255.0f blue:105.0f/255.0f alpha:1.0];
            break;
            
        case 1: // bit dark
            color = [UIColor colorWithRed:231.0f/255.0f green:192.0f/255.0f blue:149.0f/255.0f alpha:1.0];
            break;
            
        case 2: // dark
            color = [UIColor colorWithRed:172.0f/255.0f green:140.0f/255.0f blue:104.0f/255.0f alpha:1.0];
            break;
            
        case 3: // black
            color = [UIColor colorWithRed:39.0f/255.0f green:29.0f/255.0f blue:18.0f/255.0f alpha:1.0];
            break;
        default:
            break;
    }
    
    
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClipToMask(context, rect, image.CGImage);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *colorized_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIImage *rotated_image = [UIImage imageWithCGImage:[colorized_image CGImage] scale:1.0f orientation:UIImageOrientationRight];
    return rotated_image;
}

/*
 *  Note: the code is really ... merdique but it works so ¯\_(ツ)_/¯
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    [self.skintoneSegmentedControl setHidden:YES];
    [self.openCameraButton setHidden:YES];
    [self.activityIndicator startAnimating];
    [self.actionButton setTitle:@"animoji-ing.." forState:UIControlStateNormal];
    [self.actionButton setHidden:NO];
    [self.dismissButton setHidden:YES];
    

    UIImage *chosen_image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // shitty stuff
    NSString *output_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/my_ugly_face.jpg"];

    UIImage *cropped_image = [self cropImage:chosen_image cropRect:CGRectMake(chosen_image.size.width / 2 + ANIMOJIOUTLINE_SIZE - 50, chosen_image.size.height / 2 - (ANIMOJIOUTLINE_SIZE * 3), 1000, 1000)];
    
    UIImage *rotated_image = [UIImage imageWithCGImage:[cropped_image CGImage] scale:1.0f orientation:UIImageOrientationRight];
    [self.imagePreview setImage:rotated_image];
    NSData *imageData = UIImageJPEGRepresentation(rotated_image, 0.7);
    [imageData writeToFile:output_path atomically:YES];
    
    UIImage *original_AO_image = [UIImage imageNamed:@"customanimoji_head_AO"];
    
    // place the image on top of the original AO one
    UIGraphicsBeginImageContextWithOptions(original_AO_image.size, FALSE, 0.0);
    [original_AO_image drawInRect:CGRectMake( 0, 0, original_AO_image.size.width, original_AO_image.size.height)];
    [rotated_image drawInRect:CGRectMake( 64, 308, 239, 207)];
    UIImage *new_AO_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // save the AO image
    NSString *AO_output_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/alien_head_AO.jpg"];
    imageData = UIImageJPEGRepresentation(new_AO_image, 0.7);
    [imageData writeToFile:AO_output_path atomically:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        UIImage *colorized_diffuse = [self colorizeImage:[UIImage imageNamed:@"customanimoji_head_AO"]];
    
        // save the diffused version
        NSString *diffused_output_path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/customanimoji_head_AO"];
        NSData *imageData = UIImageJPEGRepresentation(colorized_diffuse, 0.7);
        [imageData writeToFile:diffused_output_path atomically:YES];
    
        // wait (this is tmp tmp tmp tmp) abe fix this
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
           
            // scnz path (TMP)
            char *scnz_path = "/System/Library/PrivateFrameworks/AvatarKit.framework/puppets/alien/alien.scnz";
            
            add_custom_animoji(strdup([output_path UTF8String]), strdup([diffused_output_path UTF8String]), strdup([AO_output_path UTF8String]), strdup([AO_output_path UTF8String]),scnz_path);
            
            [self.actionButton setHidden:YES];
            [self.activityIndicator setHidden:YES];
            [self.dismissButton setHidden:NO];
        });
    
    });
}

- (IBAction)applyTapped:(id)sender {
    

}


- (IBAction)dismissTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end


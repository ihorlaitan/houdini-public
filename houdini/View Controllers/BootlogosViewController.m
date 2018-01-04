//
//  BootlogosViewController.m
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

@interface BootlogosViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITableView *bootlogosTableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@end



@interface BootlogoCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *packageIcon;

@property (weak, nonatomic) IBOutlet UILabel *packageTitle;
@property (weak, nonatomic) IBOutlet UILabel *packageSource;

@property(nonatomic, strong) Package *package; // The package associated to this cell

- (void) setPackage:(Package *) __package;

@property (nonatomic, retain) BootlogosViewController *mainViewController;


@end

@implementation BootlogoCell

@synthesize package = _package;

- (void) setBootlogo:(Package *)__package {
    _package = __package;
}

- (IBAction)bootlogoCellButtonTapped:(id)sender {
    
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:NO];
    [self setSelectedBackgroundView:[[UIView alloc] init]];
}

@end


@implementation BootlogosViewController

NSMutableArray *bootlogos_list;

kern_return_t download_bootlogos_list() {
    
    kern_return_t ret = KERN_SUCCESS;
    
    NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://iabem97.github.io/houdini_website/bootlogos/bootlogos_list.plist"]];
    
    if (urlData) {
        if ([[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding] containsString:@"<!DOCTYPE html PUBLIC"])
            return KERN_FAILURE;
        
        NSError *error;
        NSPropertyListFormat format;
        NSDictionary *dict = [NSPropertyListSerialization
                              propertyListWithData:urlData
                              options:kNilOptions
                              format:&format
                              error:&error];
        
        // check if we're null or not
        if(dict == NULL) {
            printf("[ERROR]: could not read dict from emojis data\n");
            return KERN_FAILURE;
        }
        
        if([dict objectForKey:@"bootlogos_list"] != nil) {
            
            NSArray *bootlogos_array = [dict objectForKey:@"bootlogos_list"];
            
            
            for(NSDictionary *bootlogo_dict in bootlogos_array){
            
                Package *bootlogo_package = [[Package alloc] initWithName:[bootlogo_dict objectForKey:@"name"] type:@"bootlogo" short_desc:@"" url:[bootlogo_dict objectForKey:@"url"]];
                
                [bootlogo_package setAuthor:[bootlogo_dict objectForKey:@"author"]];
                [bootlogo_package setThumbnail:[bootlogo_dict objectForKey:@"thumbnail"]];
                
                [bootlogos_list addObject:bootlogo_package];
            }
        }
        
    }
    
    return ret;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    bootlogos_list = [[NSMutableArray alloc] init];
    
//    Package *original_bootlogo = [[Package alloc] initWithName:@"Original" type:@"bootlogo" short_desc:@"" url:nil];
//
//    [original_bootlogo setAuthor:@"Apple"];
//
//    // should be on top of the list
//    [bootlogos_list addObject:original_bootlogo];
//
    
    // download the bootlogos list
    download_bootlogos_list();
    
    // refresh the table view
    [self.bootlogosTableView reloadData];
}

- (void)hideInstalling {
    
    [self.actionButton setHidden:NO];
    [self.activityIndicator setHidden:YES];
    [self.dismissButton setHidden:NO];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [bootlogos_list count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    BootlogoCell *cell = (BootlogoCell *)[tableView dequeueReusableCellWithIdentifier:@"BootlogoCell"];
    
    Package *package = NULL;
    package = (Package *)[bootlogos_list objectAtIndex:indexPath.row];
        
    [cell.packageTitle setText:[package get_name]];
    [cell.packageSource setText:[@"by " stringByAppendingString:[package get_author]]];
    
    // get the image
    if([[package get_name] isEqualToString:@"Original"] == NO) {
        NSURL * imageURL = [NSURL URLWithString:[package get_thumbnail]];
        NSData * imageData = [NSData dataWithContentsOfURL:imageURL];
        cell.packageIcon.image = [UIImage imageWithData:imageData];
        
        [cell.packageIcon setContentMode:UIViewContentModeScaleAspectFit];
        
    }
    cell.package = package;
    cell.mainViewController = self;
    
    return cell;
}


- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath {
    
    BootlogoCell *cell = (BootlogoCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Change bootlogo?"
                                 message:[cell.packageTitle.text stringByAppendingString:@" will be used as your bootlogo"]
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelButton = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
    
    
    UIAlertAction* confirmButton = [UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {

        // (TODO: better way to detect 'Original')
        if([[cell.package get_name] isEqualToString:@"Original"]) {
            
            // just reset to default
            set_bootlogo("");
            [self hideInstalling];
            
            return;
        }
        
        NSString *documents_path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *downloaded_file_path = [documents_path stringByAppendingPathComponent:@"temp_bootlogo.png"];
        
        // remove any existing file
        [[NSFileManager defaultManager] removeItemAtPath:downloaded_file_path error:nil];
        
        [self.activityIndicator startAnimating];
        [self.bootlogosTableView setHidden:YES];
        [self.dismissButton setHidden:YES];
        
        // download and set bootlogo
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSString *package_final_url = [NSString stringWithFormat:@"%@", [cell.package get_url]];
            
            printf("[INFO]: started downloading..\n");
            printf("[INFO]: download URL: %s\n", [package_final_url UTF8String]);
            NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:package_final_url]];
            if (urlData) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    printf("[INFO]: finished downloading emoji package to path: %s\n", [downloaded_file_path UTF8String]);
                    [urlData writeToFile:downloaded_file_path atomically:YES];
                    
                    // set the bootlogo using the downloaded file
                    set_bootlogo(strdup([downloaded_file_path UTF8String]));
                    
                    [self hideInstalling];
                });
            }
        });
        
        
    }];
    
    [alert addAction:cancelButton];
    [alert addAction:confirmButton];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)applyTapped:(id)sender {
    
    printf("[INFO]: rebooting!\n");
    
    // reboot
    chosen_strategy.strategy_reboot();
}


- (IBAction)dismissTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end


//
//  SiriSuggestionsViewController.m
//  Houdini
//
//  Created by Abraham Masri on 11/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//


#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "utilities.h"

#include <sys/param.h>
#include <sys/mount.h>
#import <UIKit/UIKit.h>


@interface SiriSuggestionsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

//@property (assign) BOOL shouldRespring;

@end

@implementation SiriSuggestionsViewController

NSMutableArray *siri_suggestions_list;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    siri_suggestions_list = [[NSMutableArray alloc] init];
    
    // output path
    NSString *output_dir_path = get_houdini_dir_for_path(@"siri_suggestion");
    
    NSString *siri_suggestions_filename = [NSString stringWithFormat:@"com.apple.siri.suggestions-%@.plist", [[NSLocale preferredLanguages] firstObject]];
    
    // our local copy's path
    NSString *local_copy_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, siri_suggestions_filename];
    
    // original plist path
    NSString *original_path = [NSString stringWithFormat:@"/var/mobile/Library/Caches/%@", siri_suggestions_filename];
    
    // copy the file to our dir then open it
    kern_return_t ret = copy_file(strdup([original_path UTF8String]), strdup([local_copy_path UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
    
    if(ret != KERN_SUCCESS) {
        return;
    }
    
    // read the file
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:local_copy_path];
    
    NSMutableArray *array = [[dict allValues] firstObject];
    
    if([array count] <= 0)
        return;
    
    for(NSString *suggestion in array)
        [siri_suggestions_list addObject:suggestion];
    
    [self.tableView reloadData];
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    return [siri_suggestions_list count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"SiriSuggestionCell"];

    NSString *suggestion = (NSString *)[siri_suggestions_list objectAtIndex:indexPath.row];;

    [cell.textLabel setText:suggestion];

    return cell;
}

- (IBAction)addTapped:(id)sender {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Suggestion Text" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"";

    }];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [siri_suggestions_list addObject: [[alertController textFields][0] text]];
        [self.tableView reloadData];
        
    }];
    [alertController addAction:confirmAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}


- (IBAction)applyTapped:(id)sender {
    
    // not the way to do it but I'm tired and I'm not gonna bother doing it the "right" way
    NSString *plist_content = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><array>STRINGS_ARRAY</array></plist>""";
    
    NSString *strings_array = @"";
    for(NSString *suggestion in siri_suggestions_list) {
        strings_array = [NSString stringWithFormat:@"%@<string>%@</string>", strings_array, suggestion];
    }
    
    plist_content = [plist_content stringByReplacingOccurrencesOfString:@"STRINGS_ARRAY" withString:strings_array];
    
    
    // output path
    NSString *output_dir_path = get_houdini_dir_for_path(@"siri_suggestion");
    
    NSString *siri_suggestions_filename = [NSString stringWithFormat:@"com.apple.siri.suggestions-%@.plist", [[NSLocale preferredLanguages] firstObject]];
    
    // our local copy's path
    NSString *output_path = [NSString stringWithFormat:@"%@/%@", output_dir_path, siri_suggestions_filename];
    
    // save the plist
    [plist_content writeToFile:output_path atomically:NO encoding:NSStringEncodingConversionAllowLossy error:nil];
    
    // original plist path
    NSString *original_path = [NSString stringWithFormat:@"/var/mobile/Library/Caches/%@", siri_suggestions_filename];
    
    
    // copy the file to the original directory
    kern_return_t ret = copy_file(strdup([output_path UTF8String]), strdup([original_path UTF8String]), MOBILE_UID, MOBILE_GID, 0755);
    
    if(ret != KERN_SUCCESS) {
        return;
    }
}


- (IBAction)dismissTapped:(id)sender {
    
    kill_springboard(SIGCONT);
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end

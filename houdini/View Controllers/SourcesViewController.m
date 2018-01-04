//
//  PackagesViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import "SourcesViewController.h"
#include "sploit.h"
#include "sources_control.h"
#include "packages_control.h"

@implementation SourceCell

@synthesize source = _source;

- (void) setSource:(Source *)__source {
    _source = __source;
}

- (IBAction)sourceCellButtonTapped:(id)sender {
    
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:NO];
    [self setSelectedBackgroundView:[[UIView alloc] init]];
}

@end



@interface SourcesViewController ()
@property (weak, nonatomic) IBOutlet UIButton *reloadButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;

@property (weak, nonatomic) IBOutlet UIButton *addButton;

@property (weak, nonatomic) IBOutlet UITableView *sourcesTableView;

@end

@implementation SourcesViewController

extern NSMutableArray *sources_list;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.sourcesTableView reloadData];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    return [sources_list count];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    Source *source = (Source *)[sources_list objectAtIndex:indexPath.row];
    
    // default sources are here to stay
    if([source.url containsString:@"apt.modmyi.com"])
        return NO;
    
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        
        Source *source = (Source *)[sources_list objectAtIndex:indexPath.row];;
        
        remove_source(source);
        [self.sourcesTableView reloadData];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    SourceCell *cell = (SourceCell *)[tableView dequeueReusableCellWithIdentifier:@"SourceCell"];
    
    Source *source = (Source *)[sources_list objectAtIndex:indexPath.row];;
    
    [cell.sourceTitle setText:[source get_name]];
    [cell.sourceURL setText:[source get_url]];
    
    // TODO: get the icon from the source itself
    //    [cell.sourceIcon setImage:[UIImage imageNamed:@"Tweak"]];
    
    [cell.imageView setContentMode:UIViewContentModeScaleAspectFit];
    cell.source = source;
//    cell.mainViewController = self;
    
    return cell;
}

- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath {
    
    // TODO: would be nice in the future to view list of packages for this source
    //    SourceCell *cell = (SourceCell *)[tableView cellForRowAtIndexPath:indexPath];
    //    [self presentSourceView:cell.package];
    
}

- (IBAction)reloadTapped:(id)sender {
    
    [self.activityIndicatorView startAnimating];
    [self.reloadButton setHidden:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        sources_control_init();
    });
}


- (IBAction)addSourceTapped:(id)sender {
    
    UIViewController *addSourceViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AddSourceViewController"];
    addSourceViewController.providesPresentationContextTransitionStyle = YES;
    addSourceViewController.definesPresentationContext = YES;
    [addSourceViewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:addSourceViewController animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [self.sourcesTableView reloadData];
        
    });
}

@end

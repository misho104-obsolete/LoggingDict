//
//  SecondViewController.m
//  LoggingDict
//
//  Created by Sho IWAMOTO on 6/18/15.
//  Copyright © 2015 Sho IWAMOTO. All rights reserved.
//

#import "SecondViewController.h"
#import <DropboxSDK/DropboxSDK.h>

@interface SecondViewController () <DBRestClientDelegate>
@property (weak, nonatomic) IBOutlet UIButton *dropboxLink;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxStatusUpdate) name:@"refreshSecondView" object:nil];
    [self dropboxStatusUpdate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)dropboxToggleLink:(id)sender {
    if (![[DBSession sharedSession] isLinked]) {
        [[DBSession sharedSession] linkFromController:self];
    }else{
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Confirmation"
                                                                         message:@"Really unlink?"
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
                                                             [[DBSession sharedSession] unlinkAll];
                                                             [self dropboxStatusUpdate];
                                                         }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {}];
        [confirm addAction:okAction];
        [confirm addAction:cancelAction];
        [self presentViewController:confirm animated:YES completion:nil];
    }
}

- (void)dropboxStatusUpdate {
    if ([[DBSession sharedSession] isLinked]) {
        [_dropboxLink setTitle:@"Linked" forState:UIControlStateNormal];
    }else{
        [_dropboxLink setTitle:@"Not linked" forState:UIControlStateNormal];
    }
}

@end

//
//  SecondViewController.m
//  LoggingDict
//
//  Created by Sho IWAMOTO on 6/18/15.
//  Copyright © 2015 Sho IWAMOTO. All rights reserved.
//

#import "SecondViewController.h"
#import "AppDelegate.h"
#import <DropboxSDK/DropboxSDK.h>

@interface SecondViewController () <DBRestClientDelegate>
@property (weak, nonatomic) IBOutlet UIButton *dropboxLink;
@property (weak, nonatomic) IBOutlet UILabel *lastUpload;
@property (weak, nonatomic) IBOutlet UIButton *loadData;
@property (nonatomic, strong) AppDelegate *delegate;
@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _delegate = [[UIApplication sharedApplication] delegate];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxStatusUpdate) name:@"refreshSecondView" object:nil];
    [[NSNotificationCenter defaultCenter] addObserverForName: @"updateLastUpload"
                                                      object: nil
                                                       queue: nil
                                                  usingBlock: ^( NSNotification * notification )
    { [self updateLastUpload:[notification.object objectForKey:@"date"]]; }];
    [self dropboxStatusUpdate];

    _activityIndicator = [[UIActivityIndicatorView alloc] init];
    _activityIndicator.center = self.view.center;
    _activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [_activityIndicator setColor:[UIColor darkGrayColor]];
    [self.view addSubview:_activityIndicator];
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
        _lastUpload.text = @"Retrieving...";
    }else{
        [_dropboxLink setTitle:@"Not linked" forState:UIControlStateNormal];
        _lastUpload.text = @"Not linked";
        [_loadData setEnabled:NO];
    }
    [self setRestClient];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"setRestClient" object:nil];
    [_restClient loadMetadata:_delegate.dropboxFilePath];
}

- (void)updateLastUpload:(NSDate *)date {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd MMM HH:mm"];
    _lastUpload.text = [formatter stringFromDate: date];
}

- (IBAction)dropboxLoadData:(id)sender {
    if (![[DBSession sharedSession] isLinked]) {
        [[DBSession sharedSession] linkFromController:self];
    }else{
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Confirmation"
                                                                         message:@"Really load?"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action)
            {
                [self.restClient loadFile:_delegate.dropboxFilePath intoPath:_delegate.filePath];
                [_activityIndicator startAnimating];
            }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {}];
        [confirm addAction:okAction];
        [confirm addAction:cancelAction];
        [self presentViewController:confirm animated:YES completion:nil];
    }
}


- (void) setRestClient {
    DBSession *session = [DBSession sharedSession];
    if(session.isLinked){
        self.restClient = [[DBRestClient alloc] initWithSession:session];
        self.restClient.delegate = self;
    }else{
        self.restClient = nil;
    }
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata {
    NSLog(@"Metadata obtained: %@ %@ %@ %@",metadata.filename, metadata.path, metadata.rev, metadata.root);
    if([metadata.path compare:_delegate.dropboxFilePath] == NSOrderedSame){
        [self updateLastUpload:metadata.lastModifiedDate];
        [_loadData setEnabled:YES];
    }
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {
    _lastUpload.text = @"Unknown";
    NSLog(@"Error loading metadata: %@", error);
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)localPath contentType:(NSString *)contentType metadata:(DBMetadata *)metadata {
    NSLog(@"File loaded into path: %@", localPath);
    [_activityIndicator stopAnimating];

    if([metadata.path compare:_delegate.dropboxFilePath] == NSOrderedSame){
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadFile" object:nil];
    }
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error {
    NSLog(@"There was an error loading the file: %@", error);
    [_activityIndicator stopAnimating];

    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Error"
                                          message:[@"Load failed:" stringByAppendingString:[error description]]
                                          preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end

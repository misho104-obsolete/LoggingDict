//
//  FirstViewController.m
//  LoggingDict
//
//  Created by Sho IWAMOTO on 6/18/15.
//  Copyright © 2015 Sho IWAMOTO. All rights reserved.
//

#import "FirstViewController.h"
#import "AppDelegate.h"
#import <DropboxSDK/DropboxSDK.h>


@protocol searchViewDelegate <NSObject>
-(void) doSearchDone;
@end

@interface MyReferenceLibraryViewController : UIReferenceLibraryViewController { id delegate; }
@property (nonatomic,retain) id delegate;
@end

@implementation MyReferenceLibraryViewController
@synthesize delegate;
-(void) dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    [super dismissViewControllerAnimated:flag completion:completion];
    [delegate doSearchDone];
}
@end


@interface FirstViewController ()<UITableViewDelegate, UITableViewDataSource, DBRestClientDelegate>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UIButton *button;
@property (nonatomic, strong) NSMutableArray *wordList;
@property (nonatomic, strong) NSArray  *sortModes;
@property (nonatomic, strong) NSString *sortMode;
@property (nonatomic, strong) NSDictionary *sortComparators;
@property (nonatomic, strong) NSDate *dropboxLastUpload;
@property (nonatomic, strong) AppDelegate *delegate;
@property (nonatomic, strong) DBRestClient *restClient;
@end

@implementation FirstViewController

- (NSMutableDictionary*)newWord:(NSString*)word {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            word,          @"word",
            @1,            @"count",
            [NSDate date], @"firstLookUp",
            [NSDate date], @"lastLookUp",
            nil];
}

- (NSMutableDictionary*)increment:(NSMutableDictionary*)dict {
    NSDate *lastLookUp = [dict objectForKey:@"lastLookUp"], *now = [NSDate date];
    float timePassed = [now timeIntervalSinceDate: lastLookUp];
    if(timePassed > 60){
        [dict setObject:@([[dict objectForKey:@"count"] intValue] + 1) forKey:@"count"];
        [dict setObject:now forKey:@"lastLookUp"];
    }
    return dict;
}

- (NSMutableDictionary*)decrement:(NSMutableDictionary*)dict {
    int c = [[dict objectForKey:@"count"] intValue];
    if(c > 1){ [dict setObject:@(c - 1) forKey:@"count"]; }
    return dict;
}

- (void)setToCell:(UITableViewCell*)cell dict:(NSDictionary*)dict {
   cell.textLabel.text = [dict objectForKey:@"word"];
   cell.detailTextLabel.text = [[dict objectForKey:@"count"] stringValue];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    _delegate = [[UIApplication sharedApplication] delegate];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setRestClient) name:@"setRestClient" object:nil];

    [self loadFile];
    [self setRestClient];

    _sortModes = @[@"Recent", @"A-Z", @"Count", @"Older", @"Recent"];
    _sortMode = _sortModes[0];
    _sortComparators = [NSDictionary dictionaryWithObjectsAndKeys:
                        [[NSSortDescriptor alloc] initWithKey:@"lastLookUp"  ascending:NO ], @"Recent",
                        [[NSSortDescriptor alloc] initWithKey:@"word"        ascending:YES], @"A-Z",
                        [[NSSortDescriptor alloc] initWithKey:@"count"       ascending:NO ], @"Count",
                        [[NSSortDescriptor alloc] initWithKey:@"firstLookUp" ascending:YES], @"Older", nil];

    // tableView
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(viewWordDetail:)];
    [_tableView addGestureRecognizer:longPressGestureRecognizer];

    [_searchBar becomeFirstResponder];
    _searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;

    // button
    [_button setTitle:_sortMode forState:UIControlStateNormal];
    [_button addTarget:self action:@selector(button_Tapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)doSearch:(NSString*)term {
    MyReferenceLibraryViewController *ref = [[MyReferenceLibraryViewController alloc] initWithTerm:term ];
    ref.delegate = self;
    [self presentViewController: ref animated:NO completion:nil];

    __block NSInteger result = -1;
    [_wordList enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        if ([[obj objectForKey:@"word"] isEqualToString:term]) {
            result = idx;
            *stop = YES;
        }   
    }];

    if (result < 0) {
        [_wordList addObject:[self newWord:term]];
    } else {
        [self increment:_wordList[result]];
    }
    _sortMode = @"Recent";
    [_button setTitle:_sortMode forState:UIControlStateNormal];
    _wordList = [[_wordList sortedArrayUsingDescriptors:@[_sortComparators[_sortMode]]] mutableCopy];
    [self saveFile];
}

- (void)loadFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:_delegate.filePath]) {
        _wordList = [[NSArray arrayWithContentsOfFile:_delegate.filePath] mutableCopy];
    }else{
        _wordList = [[NSMutableArray alloc] init];
    }
}

- (void)saveFile {
    [_wordList writeToFile:_delegate.filePath atomically:NO];

    float timePassed = _dropboxLastUpload ? [_dropboxLastUpload timeIntervalSinceNow] : 9999;
    if(timePassed > 300 && _restClient){
        [_restClient loadMetadata:_delegate.dropboxFilePath];
    }
}

- (void)doSearchDone {
    [_tableView reloadData];
    [_searchBar becomeFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString* term = [[searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    searchBar.text = nil;
    [self doSearch:term];
}

-(void)searchBarCancelButtonClicked:(UISearchBar*)searchBar {
    [_searchBar resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger dataCount = _wordList.count;
    return dataCount;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    [self setToCell:cell dict:_wordList[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self doSearch:[tableView cellForRowAtIndexPath:indexPath].textLabel.text];
}

- (void)viewWordDetail:(UILongPressGestureRecognizer*)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) { return; }
    CGPoint p = [gestureRecognizer locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:p];

    if(indexPath.row < _wordList.count) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"dd MMM yyyy HH:mm:ss"];
        NSDictionary* w = _wordList[indexPath.row];
        NSString *message = [[[@"First look-up: "
                             stringByAppendingString:[formatter stringFromDate:[w objectForKey:@"firstLookUp"]]]
                             stringByAppendingString:@"\nLast look-up: "]
                              stringByAppendingString:[formatter stringFromDate:[w objectForKey:@"lastLookUp"]]];

        UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:[w objectForKey:@"word"]
                                          message:message preferredStyle:UIAlertControllerStyleAlert];
    
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {};

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @[
             [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                title:@"Delete"
                                              handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                                                  [_wordList removeObjectAtIndex:indexPath.row];
                                                  [self saveFile];
                                                  [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                                              }],
             [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                title:@"-1"
                                              handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                                                  [self decrement:_wordList[indexPath.row]];
                                                  [self saveFile];
                                                  [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
             }]];
}

- (void) button_Tapped: (UIButton*)sender {
    [_searchBar resignFirstResponder];
    BOOL flag = false;
    for (NSString *m in _sortModes) {
        if(flag){ _sortMode = m; break; }
        if(m==sender.titleLabel.text){ flag = true; }
    }
    [_button setTitle:_sortMode forState:UIControlStateNormal];
    _wordList = [[_wordList sortedArrayUsingDescriptors:@[_sortComparators[_sortMode]]] mutableCopy];
    [_tableView reloadData];
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
        [self.restClient uploadFile:[_delegate.dropboxFilePath lastPathComponent] toPath:[_delegate.dropboxFilePath stringByDeletingLastPathComponent] withParentRev:metadata.rev fromPath:_delegate.filePath];
    }
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {
    NSLog(@"Error loading metadata: %@", error);
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath
              from:(NSString *)srcPath metadata:(DBMetadata *)metadata {
    NSLog(@"File uploaded successfully to path: %@", metadata.path);
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error {
    NSLog(@"File upload failed with error: %@", error);
}

@end

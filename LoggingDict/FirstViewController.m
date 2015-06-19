//
//  FirstViewController.m
//  LoggingDict
//
//  Created by Sho IWAMOTO on 6/18/15.
//  Copyright © 2015 Sho IWAMOTO. All rights reserved.
//

#import "FirstViewController.h"


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


@interface FirstViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray *wordList;
@property (nonatomic, strong) NSString *filePath;
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
    [dict setObject:@([[dict objectForKey:@"count"] intValue] + 1) forKey:@"count"];
    [dict setObject:[NSDate date] forKey:@"lastLookUp"];
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
    // Do any additional setup after loading the view, typically from a nib.

    // Read file
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    _filePath = [directory stringByAppendingPathComponent:@"words.plist"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:_filePath]) {
        _wordList = [[NSArray arrayWithContentsOfFile:_filePath] mutableCopy];
    }else{
        _wordList = [[NSMutableArray alloc] init];
    }

    // tableView
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(viewWordDetail:)];
    [_tableView addGestureRecognizer:longPressGestureRecognizer];

    [_searchBar becomeFirstResponder];
    _searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
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
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastLookUp" ascending:NO];
    _wordList = [[_wordList sortedArrayUsingDescriptors:@[sortDescriptor]] mutableCopy];
    [_wordList writeToFile:_filePath atomically:NO];
}

- (void)doSearchDone {
    [_tableView reloadData];
    [_searchBar becomeFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self doSearch:searchBar.text];
    searchBar.text = nil;
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
                                                  [_wordList writeToFile:_filePath atomically:NO];
                                                  [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                                              }],
             [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                title:@"-1"
                                              handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                                                  [self decrement:_wordList[indexPath.row]];
                                                  [_wordList writeToFile:_filePath atomically:NO];
                                                  [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
             }]];
}



@end

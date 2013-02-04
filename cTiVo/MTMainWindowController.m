//
//  MTMainWindowController.m
//  cTiVo
//
//  Created by Scott Buchanan on 12/13/12.
//  Copyright (c) 2012 Scott Buchanan. All rights reserved.
//

#import "MTMainWindowController.h"
#import "MTDownloadTableView.h"
#import "MTProgramTableView.h"
#import "MTSubscriptionTableView.h"
#import "MTFormatPopUpButton.h"
#import "MTCheckBox.h"
#import "MTTiVo.h"

@interface MTMainWindowController ()

@end

@implementation MTMainWindowController

__DDLOGHERE__

@synthesize tiVoShowTable,subscriptionTable, downloadQueueTable;

-(id)initWithWindowNibName:(NSString *)windowNibName
{
	DDLogDetail(@"creating Main Window");
	self = [super initWithWindowNibName:windowNibName];
	if (self) {
		loadingTiVos = [NSMutableArray new];
        self.selectedTiVo = nil;
        _myTiVoManager = tiVoManager;
	}
	return self;
}

-(void)awakeFromNib
{
	DDLogDetail(@"MainWindow awakeFromNib");
	[self refreshFormatListPopup];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
	DDLogDetail(@"MainWindow windowDidLoad");
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
	[tiVoListPopUp removeAllItems];
	[tiVoListPopUp addItemWithTitle:@"Searching for TiVos..."];
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [searchingTiVosIndicator startAnimation:nil];
	[defaultCenter addObserver:self selector:@selector(refreshTiVoListPopup:) name:kMTNotificationTiVoListUpdated object:nil];
	[defaultCenter addObserver:self selector:@selector(buildColumnMenuForTables) name:kMTNotificationTiVoListUpdated object:nil];
	[defaultCenter addObserver:self selector:@selector(refreshTiVoListPopup:) name:kMTNotificationTiVoShowsUpdated object:nil];
    [defaultCenter addObserver:self selector:@selector(refreshFormatListPopup) name:kMTNotificationFormatListUpdated object:nil];
    [defaultCenter addObserver:self selector:@selector(reloadProgramData) name:kMTNotificationTiVoShowsUpdated object:nil];
	[defaultCenter addObserver:downloadQueueTable selector:@selector(reloadData) name:kMTNotificationTiVoListUpdated object:nil];
	[defaultCenter addObserver:downloadQueueTable selector:@selector(reloadData) name:kMTNotificationDownloadQueueUpdated object:nil];
	[defaultCenter addObserver:self selector:@selector(refreshAddToQueueButton:) name:kMTNotificationDownloadQueueUpdated object:nil];
    [defaultCenter addObserver:downloadQueueTable selector:@selector(updateProgress) name:kMTNotificationProgressUpdated object:nil];
	
	//Spinner Progress Handling 
    [defaultCenter addObserver:self selector:@selector(manageLoadingIndicator:) name:kMTNotificationShowListUpdating object:nil];
    [defaultCenter addObserver:self selector:@selector(manageLoadingIndicator:) name:kMTNotificationShowListUpdated object:nil];
    [defaultCenter addObserver:self selector:@selector(networkChanged:) name:kMTNotificationNetworkChanged object:nil];
	
    [defaultCenter addObserver:self selector:@selector(tableSelectionChanged:) name:NSTableViewSelectionDidChangeNotification object:nil];
    [defaultCenter addObserver:self selector:@selector(columnOrderChanged:) name:NSTableViewColumnDidMoveNotification object:nil];
     [tiVoManager addObserver:self forKeyPath:@"selectedFormat" options:NSKeyValueObservingOptionInitial context:nil];
	[tiVoManager addObserver:self forKeyPath:@"downloadDirectory" options:NSKeyValueObservingOptionInitial context:nil];
	
	[tiVoManager determineCurrentProcessingState];

	[self buildColumnMenuForTables ];
	[pausedLabel setNextResponder:downloadQueueTable];  //Pass through mouse events to the downloadQueueTable.
	
	[tiVoShowTable setTarget: self];
	[tiVoShowTable setDoubleAction:@selector(doubleClickForDetails:)];
	
	[downloadQueueTable setTarget: self];
	[downloadQueueTable setDoubleAction:@selector(doubleClickForDetails:)];

}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath compare:@"downloadDirectory"] == NSOrderedSame) {
		DDLogDetail(@"changing downloadDirectory");
		downloadDirectory.stringValue = tiVoManager.downloadDirectory;
		NSString *dir = tiVoManager.downloadDirectory;
		if (!dir) dir = @"Directory not available!";
		downloadDirectory.stringValue = dir;
		downloadDirectory.toolTip = dir;
	}
}

-(void)networkChanged:(NSNotification *)notification
{
	DDLogMajor(@"MainWindow network Changed");
	[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationTiVoListUpdated object:_selectedTiVo];
	[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationTiVoShowsUpdated object:nil];
	
}

-(void)manageLoadingIndicator:(NSNotification *)notification
{
	if (!notification) { //Don't accept nil notifications
		return;  
	}
    MTTiVo * tivo = (MTTiVo *) notification.object;
	DDLogDetail(@"LoadingIndicator: %@ for %@",notification.name, tivo);
    if ([notification.name  compare:kMTNotificationShowListUpdating] == NSOrderedSame) {
		if ([loadingTiVos indexOfObject:tivo] == NSNotFound) {
			[loadingTiVos addObject:tivo];
		}
	} else if ([notification.name compare:kMTNotificationShowListUpdated] == NSOrderedSame) {
		[loadingTiVos removeObject:tivo];
	}
    
	if (loadingTiVos.count) {
        [loadingProgramListIndicator startAnimation:nil];
        //note: this relies on [MTTivo description]
        NSString *message =[NSString stringWithFormat: @"Updating %@",[loadingTiVos componentsJoinedByString:@", "]];

        loadingProgramListLabel.stringValue = message;
    } else {
        [loadingProgramListIndicator stopAnimation:nil];
        loadingProgramListLabel.stringValue = @"";
    }
}

-(void)reloadProgramData
{
	[tiVoShowTable reloadData];
}

#pragma mark - Notification Responsders

-(void)refreshFormatListPopup {
	formatListPopUp.showHidden = NO;
	formatListPopUp.formatList =  tiVoManager.formatList;
	[formatListPopUp refreshMenu];
	[tiVoManager setValue:[formatListPopUp selectFormatNamed:tiVoManager.selectedFormat.name] forKey:@"selectedFormat"];

}

- (void) refreshAddToQueueButton: (NSNotification *) notification {
	addToQueueButton.title = @"Download";
	if (tiVoManager.processingPaused) {
		addToQueueButton.title =@"Add to Queue";
	} else {
		for (MTTiVoShow * show in tiVoManager.downloadQueue) {
			if (!show.isDone) {
				addToQueueButton.title =@"Add to Queue";
				break; //no real need to count them all
			}
		}
	}
}

-(void)refreshTiVoListPopup:(NSNotification *)notification
{
	if (notification) {
		self.selectedTiVo = notification.object;
		if (!_selectedTiVo) {
			self.selectedTiVo = [[NSUserDefaults standardUserDefaults] objectForKey:kMTSelectedTiVo];
			if (!_selectedTiVo) {
				self.selectedTiVo = kMTAllTiVos;
			}
		}
	}
	[tiVoListPopUp removeAllItems];
	BOOL lastTivoWasManual = NO;
	for (MTTiVo *ts in tiVoManager.tiVoList) {
		NSString *tsTitle = [NSString stringWithFormat:@"%@ (%ld)",ts.tiVo.name,ts.shows.count];
		if (!ts.manualTiVo && lastTivoWasManual) { //Insert a separator
			NSMenuItem *menuItem = [NSMenuItem separatorItem];
			[tiVoListPopUp.menu addItem:menuItem];
		}
		lastTivoWasManual = ts.manualTiVo;
		[tiVoListPopUp addItemWithTitle:tsTitle];
        [[tiVoListPopUp lastItem] setRepresentedObject:ts];
        NSMenuItem *thisItem = [tiVoListPopUp lastItem];
        if (!ts.isReachable) {
            NSFont *thisFont = [NSFont systemFontOfSize:13];
            NSString *thisTitle = [NSString stringWithFormat:@"%@ offline",ts.tiVo.name];
            NSAttributedString *aTitle = [[[NSAttributedString alloc] initWithString:thisTitle attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor redColor], NSForegroundColorAttributeName, thisFont, NSFontAttributeName, nil]] autorelease];
            [thisItem setAttributedTitle:aTitle];

        }
		if ([ts.tiVo.name compare:self.selectedTiVo] == NSOrderedSame) {
			[tiVoListPopUp selectItem:thisItem];
		}
		
	}
    if (tiVoManager.tiVoList.count == 1) {
        [searchingTiVosIndicator stopAnimation:nil];
		MTTiVo *ts = tiVoManager.tiVoList[0];
        [tiVoListPopUp selectItem:[tiVoListPopUp lastItem]];
        [tiVoListPopUp setHidden:YES];
        tiVoListPopUpLabel.stringValue = [NSString stringWithFormat:@"TiVo: %@ (%ld)",ts.tiVo.name,ts.shows.count];
        if (!ts.isReachable) {
            NSFont *thisFont = [NSFont systemFontOfSize:13];
            NSString *thisTitle = [NSString stringWithFormat:@"TiVo: %@ offline",ts.tiVo.name];
            NSAttributedString *aTitle = [[[NSAttributedString alloc] initWithString:thisTitle attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor redColor], NSForegroundColorAttributeName, thisFont, NSFontAttributeName, nil]] autorelease];
            [tiVoListPopUpLabel setAttributedStringValue:aTitle];
			
        }
    } else if (tiVoManager.tiVoList.count > 1){
        [searchingTiVosIndicator stopAnimation:nil];
       [tiVoListPopUp addItemWithTitle:[NSString stringWithFormat:@"%@ (%d shows)",kMTAllTiVos,tiVoManager.totalShows]];
        if ([kMTAllTiVos compare:_selectedTiVo] == NSOrderedSame) {
            [tiVoListPopUp selectItem:[tiVoListPopUp lastItem]];
        }
        [tiVoListPopUp setHidden:NO];
        [tiVoListPopUpLabel setHidden:NO];
        tiVoListPopUpLabel.stringValue = @"Filter TiVo:";
    }
}

#pragma mark - UI Actions

-(IBAction)selectFormat:(id)sender
{
    if (sender == formatListPopUp) {
        MTFormatPopUpButton *thisButton = (MTFormatPopUpButton *)sender;
        [tiVoManager setValue:[[thisButton selectedItem] representedObject] forKey:@"selectedFormat"];
        [[NSUserDefaults standardUserDefaults] setObject:tiVoManager.selectedFormat.name forKey:kMTSelectedFormat];
    } else {
        MTFormatPopUpButton *thisButton = (MTFormatPopUpButton *)sender;
        if ([thisButton.owner class] == [MTSubscription class]) {
            MTSubscription * subscription = (MTSubscription *) thisButton.owner;
            
            subscription.encodeFormat = [tiVoManager findFormat:[thisButton selectedItem].title];
            [tiVoManager.subscribedShows saveSubscriptions];
       } else if ([thisButton.owner class] == [MTTiVoShow class]) {
            MTTiVoShow * show = (MTTiVoShow *) thisButton.owner;
           if(show.isNew) {
                show.encodeFormat = [tiVoManager findFormat:[thisButton selectedItem].title];
            }
          [[NSNotificationCenter defaultCenter] postNotificationName: kMTNotificationDownloadStatusChanged object:nil];
       }
     }
}

#pragma mark - Menu Delegate

-(void)menuWillOpen:(NSMenu *)menu
{
	menuCursorPosition = [self.window mouseLocationOutsideOfEventStream];
	NSTableView *workingTable = nil;
	NSString *selector = nil;
	if ([menu.title compare:@"ProgramTableMenu"] == NSOrderedSame) {
		workingTable = tiVoShowTable;
		selector = @"programMenuHandler:";
		//Update titles as appropriate
		for (NSMenuItem *mi in [menu itemArray]) {
			if ([mi.title rangeOfString:@"refresh" options:NSCaseInsensitiveSearch].location != NSNotFound) {
				if (tiVoManager.tiVoList.count > 1) {
					mi.title = @"Refresh this TiVo";
				} else {
					mi.title = @"Refresh TiVo";
				}
			}
		}
	}
	if ([menu.title compare:@"DownloadTableMenu"] == NSOrderedSame) {
		workingTable = downloadQueueTable;
		selector = @"downloadMenuHandler:";
	}
	if ([menu.title compare:@"SubscriptionTableMenu"] == NSOrderedSame) {
		workingTable = subscriptionTable;
		selector = @"subscriptionMenuHandler:";
	}
	if (workingTable) {
		NSPoint p = [workingTable convertPoint:menuCursorPosition fromView:nil];
		menuTableRow = [workingTable rowAtPoint:p];
		for (NSMenuItem *mi in [menu itemArray]) {
			[mi setAction:NSSelectorFromString(selector)];
		}
		if (menuTableRow < 0) { //disable row functions  Row based functions have tag=1;
			for (NSMenuItem *mi in [menu itemArray]) {
				if (mi.tag == 1) {
					[mi setAction:NULL];
				}
			}
		} else {
			[workingTable selectRowIndexes:[NSIndexSet indexSetWithIndex:menuTableRow] byExtendingSelection:YES];
		}
		if ([workingTable selectedRowIndexes].count == 0) { //No selection so disable group fuctions
			for (NSMenuItem *mi in [menu itemArray]) {
				if (mi.tag == 0) {
					[mi setAction:NULL];
				}
			}

		}

	}
}

-(IBAction)programMenuHandler:(NSMenuItem *)menu
{
	MTTiVoShow *thisShow = tiVoShowTable.sortedShows[menuTableRow];
	if ([menu.title caseInsensitiveCompare:@"Download"] == NSOrderedSame) {
		[tiVoShowTable selectRowIndexes:[NSIndexSet indexSetWithIndex:menuTableRow] byExtendingSelection:YES];
		[self downloadSelectedShows:menu];
	} else if ([menu.title rangeOfString:@"Refresh" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		[thisShow.tiVo updateShows:nil];
	} else if ([menu.title caseInsensitiveCompare:@"Subscribe to series"] == NSOrderedSame) {
		[tiVoShowTable selectRowIndexes:[NSIndexSet indexSetWithIndex:menuTableRow] byExtendingSelection:YES];
		[self subscribe:menu];
	} else if ([menu.title caseInsensitiveCompare:@"Show Details"] == NSOrderedSame) {
		self.showForDetail = thisShow;
		[tiVoShowTable deselectAll:nil];
		[tiVoShowTable selectRowIndexes:[NSIndexSet indexSetWithIndex:menuTableRow] byExtendingSelection:NO];
		[showDetailDrawer open];
	} else if ([menu.title caseInsensitiveCompare:@"Play Video"] == NSOrderedSame) {
		[thisShow playVideo];
	} else if ([menu.title caseInsensitiveCompare:@"Show in Finder"] == NSOrderedSame) {
		[thisShow revealInFinder];
		
	}
}


-(IBAction)doubleClickForDetails:(id)input {
	NSLog(@"DoubleClick input %@",input);
	[showDetailDrawer open];
	if (input == tiVoShowTable || input==downloadQueueTable) {
		NSInteger rowNumber = [input clickedRow];
		NSLog(@"clickedRow %ld",rowNumber);
		if (rowNumber != -1) {
			MTTiVoShow * show = [[input sortedShows] objectAtIndex:rowNumber];
			[show revealInFinder];
			[show playVideo];
		}
	}
}


-(IBAction)downloadMenuHandler:(NSMenuItem *)menu
{
	if ([menu.title caseInsensitiveCompare:@"Delete"] == NSOrderedSame) {
		[self removeFromDownloadQueue:menu];
	} else if ([menu.title caseInsensitiveCompare:@"Reschedule"] == NSOrderedSame) {
		NSIndexSet *selectedRows = [downloadQueueTable selectedRowIndexes];
		NSArray *itemsToRemove = [downloadQueueTable.sortedShows objectsAtIndexes:selectedRows];
		if ([tiVoManager.processingPaused boolValue]) {
			for (MTTiVoShow *show in itemsToRemove) {
					[show rescheduleShow:@(NO)];
			}
		} else {
			[tiVoManager deleteProgramsFromDownloadQueue:itemsToRemove];
			[tiVoManager addProgramsToDownloadQueue:itemsToRemove beforeShow:nil];
		}
	} else if ([menu.title caseInsensitiveCompare:@"Subscribe to series"] == NSOrderedSame) {
		NSArray * selectedShows = [downloadQueueTable.sortedShows objectsAtIndexes:downloadQueueTable.selectedRowIndexes];
		[tiVoManager.subscribedShows addSubscriptions:selectedShows];
	} else if ([menu.title caseInsensitiveCompare:@"Show Details"] == NSOrderedSame) {
		self.showForDetail = downloadQueueTable.sortedShows[menuTableRow];
		[downloadQueueTable deselectAll:nil];
		[downloadQueueTable selectRowIndexes:[NSIndexSet indexSetWithIndex:menuTableRow] byExtendingSelection:NO];
		[showDetailDrawer open];
	} else if ([menu.title caseInsensitiveCompare:@"Play Video"] == NSOrderedSame) {
		[downloadQueueTable.sortedShows[menuTableRow] playVideo];
	} else if ([menu.title caseInsensitiveCompare:@"Show in Finder"] == NSOrderedSame) {
		[downloadQueueTable.sortedShows[menuTableRow] revealInFinder];
		
	}
	
}

#pragma mark - Subscription Buttons

-(IBAction)subscriptionMenuHandler:(NSMenuItem *)menu
{
	if ([menu.title caseInsensitiveCompare:@"Unsubscribe"] == NSOrderedSame) {
		[subscriptionTable unsubscribeSelectedItems:menu];
	}
	
}

-(IBAction)subscribe:(id) sender {
	NSArray * selectedShows = [tiVoShowTable.sortedShows objectsAtIndexes:tiVoShowTable.selectedRowIndexes];
	[tiVoManager.subscribedShows addSubscriptions:selectedShows];
}

#pragma mark - Download Buttons

-(IBAction)downloadSelectedShows:(id)sender
{
	NSIndexSet *selectedRows = [tiVoShowTable selectedRowIndexes];
	NSArray *selectedShows = [tiVoShowTable.sortedShows objectsAtIndexes:selectedRows];
	[tiVoManager downloadShowsWithCurrentOptions:selectedShows beforeShow:nil];
    
	[tiVoShowTable deselectAll:nil];
	[downloadQueueTable deselectAll:nil];
}

-(BOOL) confirmCancel:(NSString *) title {
    NSAlert *myAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Do you want to cancel active download of '%@'?",title] defaultButton:@"No" alternateButton:@"Yes" otherButton:nil informativeTextWithFormat:@""];
    myAlert.alertStyle = NSCriticalAlertStyle;
    NSInteger result = [myAlert runModal];
    return (result == NSAlertAlternateReturn);
    
}

-(IBAction)removeFromDownloadQueue:(id)sender
{
	NSArray *itemsToRemove;
	if ([sender isKindOfClass:[NSArray class]]) {
		itemsToRemove = sender;
	}else {
		NSIndexSet *selectedRows = [downloadQueueTable selectedRowIndexes];
		itemsToRemove = [downloadQueueTable.sortedShows objectsAtIndexes:selectedRows];
	}
 	for (MTTiVoShow * show in itemsToRemove) {
        if (show.isInProgress) {
            if( ![self confirmCancel:show.showTitle]) {
                //if any cancelled, cancel the whole group
                return;
            }
        }
    }
	[tiVoManager deleteProgramsFromDownloadQueue:itemsToRemove];

 	[downloadQueueTable deselectAll:nil];
}

-(IBAction)getDownloadDirectory:(id)sender
{
	NSOpenPanel *myOpenPanel = [NSOpenPanel openPanel];
	[myOpenPanel setCanChooseDirectories:YES];
	[myOpenPanel setCanChooseFiles:NO];
	[myOpenPanel setAllowsMultipleSelection:NO];
    [myOpenPanel setCanCreateDirectories:YES];
    [myOpenPanel setTitle:@"Choose Directory for Download of Videos"];
    [myOpenPanel setPrompt:@"Choose"];
	NSInteger ret = [myOpenPanel runModal];
	if (ret == NSFileHandlingPanelOKButton) {
		tiVoManager.downloadDirectory = myOpenPanel.URL.path;
	}
}

#pragma mark - Download Options
-(IBAction)changeSkip:(id)sender
{
    MTCheckBox *checkbox = sender;
	if ([checkbox.owner isKindOfClass:[MTTiVoShow class]]){
		MTTiVoShow *show = (MTTiVoShow *)(checkbox.owner);
        show.skipCommercials = ! show.skipCommercials;
		if (show.skipCommercials) {  //Need to make sure that simul encode is not checked
				show.simultaneousEncode = NO;
		}
        [[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationFormatListUpdated object:nil];
    } else if ([checkbox.owner isKindOfClass:[MTSubscription class]]){
		
        MTSubscription *sub = (MTSubscription *)(checkbox.owner);
		sub.skipCommercials = [NSNumber numberWithBool: ! [sub.skipCommercials boolValue]];
		if ([sub.skipCommercials boolValue]) { //Need to make sure simultaneous encode is off
			sub.simultaneousEncode = @(NO);
		}
        [tiVoManager.subscribedShows saveSubscriptions];
        
    }
}

-(IBAction)changeSimultaneous:(id)sender
{
    MTCheckBox *checkbox = sender;
	if ([checkbox.owner isKindOfClass:[MTTiVoShow class]]){
		MTTiVoShow *show = (MTTiVoShow *)(checkbox.owner);
        show.simultaneousEncode = ! show.simultaneousEncode;
		if (show.simultaneousEncode) {  //Need to make sure that simul encode is not checked
				show.skipCommercials = NO;
		}
        [[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationFormatListUpdated object:nil];
    } else if ([checkbox.owner isKindOfClass:[MTSubscription class]]){
		
        MTSubscription *sub = (MTSubscription *)(checkbox.owner);
		sub.simultaneousEncode = [NSNumber numberWithBool: ! [sub.simultaneousEncode boolValue]];
		if ([sub.simultaneousEncode boolValue]) { //Need to make sure simultaneous encode is off
			sub.skipCommercials = @(NO);
		}
        [tiVoManager.subscribedShows saveSubscriptions];
        
    }
}

-(IBAction)changeiTunes:(id)sender
{     
    MTCheckBox *checkbox = sender;
	if ([checkbox.owner isKindOfClass:[MTTiVoShow class]]){
        //updating an individual show in download queue
            ((MTTiVoShow *)checkbox.owner).addToiTunesWhenEncoded = !((MTTiVoShow *)checkbox.owner).addToiTunesWhenEncoded;

    } else if ([checkbox.owner isKindOfClass:[MTSubscription class]]){
		MTSubscription *sub = (MTSubscription *)(checkbox.owner);
		sub.addToiTunes = [NSNumber numberWithBool:!sub.shouldAddToiTunes];
        [tiVoManager.subscribedShows saveSubscriptions];
        
    }
}

#pragma mark - Customize Columns

-(void) buildColumnMenuForTables{
	[self buildColumnMenuForTable: downloadQueueTable];
	[self buildColumnMenuForTable: tiVoShowTable];
	[self buildColumnMenuForTable: subscriptionTable ];
}

-(void) columnOrderChanged: (NSNotification *) notification {
	[self buildColumnMenuForTables];
}

-(void) buildColumnMenuForTable:(NSTableView *) table {
	NSMenu *tableHeaderContextMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	[[table headerView] setMenu:tableHeaderContextMenu];
	
	for (NSTableColumn *column in [table tableColumns]) {
        if ([column.identifier compare:@"TiVo"] != NSOrderedSame || tiVoManager.tiVoList.count > 1) {
            NSString *title = [[column headerCell] title];
            NSMenuItem *item = [tableHeaderContextMenu addItemWithTitle:title action:@selector(contextMenuSelected:) keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:@{@"Column" : column, @"Table" : table}];
            [item setState:column.isHidden?NSOffState: NSOnState];
        }
	}
}


- (void)contextMenuSelected:(id)sender {
    NSTableColumn *column = [sender representedObject][@"Column"];
    NSTableView *table = [sender representedObject][@"Table"];
    NSString *key = nil;
    if (table == tiVoShowTable) {
        key = kMTHideTiVoColumnPrograms;
    }
    if (table == downloadQueueTable) {
        key = kMTHideTiVoColumnDownloads;
    }
    NSString *columnIdentifier = column.identifier;
	BOOL wasOn = ([sender state] == NSOnState);
	[column setHidden:wasOn];
    if ([columnIdentifier compare:@"TiVo"] == NSOrderedSame && key) {
        [[NSUserDefaults standardUserDefaults] setBool:wasOn forKey:key];
    }
	if(wasOn) {
		[sender setState: NSOffState ];
	} else {
		[sender setState: NSOnState];
	}
}

#pragma mark - Table View Notification Handling

-(void)tableSelectionChanged:(NSNotification *)notification
{
    [addToQueueButton setEnabled:NO];
    [removeFromQueueButton setEnabled:NO];
	[subscribeButton setEnabled:NO];
    if ([downloadQueueTable numberOfSelectedRows]) {
        [removeFromQueueButton setEnabled:YES];
    }
    if ([tiVoShowTable numberOfSelectedRows]) {
        [addToQueueButton setEnabled:YES];
        [subscribeButton setEnabled:YES];
    }
}

#pragma mark - Memory Management

-(void)dealloc
{
	[loadingTiVos release];
    self.selectedTiVo = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


#pragma mark - Text Editing Delegate

-(BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if (control == downloadDirectory) {
        tiVoManager.downloadDirectory = control.stringValue;
    }
	return YES;
}



@end

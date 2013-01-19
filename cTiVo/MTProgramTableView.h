//
//  MTProgramList.h
//  myTivo
//
//  Created by Scott Buchanan on 12/7/12.
//  Copyright (c) 2012 Scott Buchanan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MTTiVoManager, MTMainWindowController;


@interface MTProgramTableView : NSTableView <NSTableViewDataSource, NSTableViewDelegate>{
    IBOutlet MTMainWindowController *myController;
	MTTiVoManager *tiVoManager;
    NSTableColumn *tiVoColumnHolder;
}

@property (nonatomic, retain) NSArray *sortedShows;
@property (nonatomic, retain) NSString *selectedTiVo;
@property (nonatomic, retain) NSNumber *showProtected;

-(NSArray *)sortedShows;
-(IBAction)selectTivo:(id)sender;
-(IBAction)selectProtectedShows:(id)sender;

@end

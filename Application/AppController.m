#import "AppController.h"
#import "PlaybackController.h"
#import "PlaylistController.h"
#import "PlaylistView.h"
#import "NDHotKey/NDHotKeyEvent.h"
#import "AppleRemote.h"
#import "PlaylistLoader.h"
#import "OpenURLPanel.h"
#import "SpotlightWindowController.h"
#import "StringToURLTransformer.h"
#import "FontSizetoLineHeightTransformer.h"
#import "PathNode.h"

#import "Logging.h"
#import "MiniModeMenuTitleTransformer.h"
#import "PlaylistEntry.h"

@implementation AppController

+ (void)initialize
{
    // Register transformers
	NSValueTransformer *stringToURLTransformer = [[[StringToURLTransformer alloc] init]autorelease];
    [NSValueTransformer setValueTransformer:stringToURLTransformer
                                    forName:@"StringToURLTransformer"];
                                
    NSValueTransformer *fontSizetoLineHeightTransformer = 
        [[[FontSizetoLineHeightTransformer alloc] init]autorelease];
    [NSValueTransformer setValueTransformer:fontSizetoLineHeightTransformer
                                    forName:@"FontSizetoLineHeightTransformer"];

    NSValueTransformer *miniModeMenuTitleTransformer = [[[MiniModeMenuTitleTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:miniModeMenuTitleTransformer
                                    forName:@"MiniModeMenuTitleTransformer"];
}


- (id)init
{
	self = [super init];
	if (self)
	{
		[self initDefaults];
				
		remote = [[AppleRemote alloc] init];
		[remote setDelegate: self];
		
        queue = [[NSOperationQueue alloc]init];
	}
    
	return self; 
}

- (void)dealloc
{
    [queue release];
    [expandedNodes release];
    [super dealloc];
}

// Listen to the remote in exclusive mode, only when Cog is the active application
- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"]) {
		[remote startListening: self];
	}
}
- (void)applicationDidResignActive:(NSNotification *)mortification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"]) {
		[remote stopListening: self];
	}
}

/* Helper method for the remote control interface in order to trigger forward/backward and volume
increase/decrease as long as the user holds the left/right, plus/minus button */
- (void) executeHoldActionForRemoteButton: (NSNumber*) buttonIdentifierNumber 
{
	static int incrementalSearch = 1;
	
    if (remoteButtonHeld) 
    {
        switch([buttonIdentifierNumber intValue]) 
        {
            case kRemoteButtonRight_Hold:       
				[playbackController seekForward:incrementalSearch];
				break;
            case kRemoteButtonLeft_Hold:
				[playbackController seekBackward:incrementalSearch];
				break;
            case kRemoteButtonVolume_Plus_Hold:
                //Volume Up
				[playbackController volumeUp:self];
				break;
            case kRemoteButtonVolume_Minus_Hold:
                //Volume Down
				[playbackController volumeDown:self];
				break;              
        }
        if (remoteButtonHeld) 
        {
			/* there should perhaps be a max amount that incrementalSearch can
			   be, so as to not start skipping ahead unreasonable amounts, even
			   in very long files. */
			if ((incrementalSearch % 3) == 0)
				incrementalSearch += incrementalSearch/3;
			else
				incrementalSearch++;

            /* trigger event */
            [self performSelector:@selector(executeHoldActionForRemoteButton:) 
					   withObject:buttonIdentifierNumber
					   afterDelay:0.25];         
        }
    }
	else
		// if we're not holding the search button, reset the incremental search
		// variable, making it ready for another search
		incrementalSearch = 1;
}

/* Apple Remote callback */
- (void) appleRemoteButton: (AppleRemoteEventIdentifier)buttonIdentifier 
               pressedDown: (BOOL) pressedDown 
                clickCount: (unsigned int) count 
{
    switch( buttonIdentifier )
    {
        case kRemoteButtonPlay:
			[self clickPlay];

            break;
        case kRemoteButtonVolume_Plus:
			[playbackController volumeUp:self];
            break;
        case kRemoteButtonVolume_Minus:
			[playbackController volumeDown:self];
            break;
        case kRemoteButtonRight:
            [self clickNext];
            break;
        case kRemoteButtonLeft:
            [self clickPrev];
            break;
        case kRemoteButtonRight_Hold:
        case kRemoteButtonLeft_Hold:
        case kRemoteButtonVolume_Plus_Hold:
        case kRemoteButtonVolume_Minus_Hold:
            /* simulate an event as long as the user holds the button */
            remoteButtonHeld = pressedDown;
            if( pressedDown )
            {                
                NSNumber* buttonIdentifierNumber = [NSNumber numberWithInt: buttonIdentifier];  
                [self performSelector:@selector(executeHoldActionForRemoteButton:) 
                           withObject:buttonIdentifierNumber];
            }
				break;
        case kRemoteButtonMenu:
            break;
        default:
            /* Add here whatever you want other buttons to do */
            break;
    }
}



- (IBAction)openFiles:(id)sender
{
	NSOpenPanel *p;
	
	p = [NSOpenPanel openPanel];
	
	[p setCanChooseDirectories:YES];
	[p setAllowsMultipleSelection:YES];
	
	[p beginSheetForDirectory:nil file:nil types:[playlistLoader acceptableFileTypes] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[playlistLoader willInsertURLs:[panel URLs] origin:URLOriginInternal];
		[playlistLoader didInsertURLs:[playlistLoader addURLs:[panel URLs] sort:YES] origin:URLOriginInternal];
	}
}

- (IBAction)savePlaylist:(id)sender
{
	NSSavePanel *p;
	
	p = [NSSavePanel savePanel];
	
	[p setAllowedFileTypes:[playlistLoader acceptablePlaylistTypes]];
	[p beginSheetForDirectory:nil file:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[playlistLoader save:[panel filename]];
	}
}

- (IBAction)openURL:(id)sender
{
	OpenURLPanel *p;
	
	p = [OpenURLPanel openURLPanel];

	[p beginSheetWithWindow:mainWindow delegate:self didEndSelector:@selector(openURLPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openURLPanelDidEnd:(OpenURLPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[playlistLoader willInsertURLs:[NSArray arrayWithObject:[panel url]] origin:URLOriginExternal];
		[playlistLoader didInsertURLs:[playlistLoader addURLs:[NSArray arrayWithObject:[panel url]] sort:NO] origin:URLOriginExternal];
	}
}

- (IBAction)delEntries:(id)sender
{
	[playlistController remove:self];
}

- (PlaylistEntry *)currentEntry
{
	return [playlistController currentEntry];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
	return [key isEqualToString:@"currentEntry"] ||  [key isEqualToString:@"play"];
}

- (void)awakeFromNib
{
	[[totalTimeField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	
	[[playbackButtons cell] setToolTip:NSLocalizedString(@"PlayButtonTooltip", @"") forSegment: 1];
	[[playbackButtons cell] setToolTip:NSLocalizedString(@"PrevButtonTooltip", @"") forSegment: 0];
	[[playbackButtons cell] setToolTip:NSLocalizedString(@"NextButtonTooltip", @"") forSegment: 2];
	[infoButton setToolTip:NSLocalizedString(@"InfoButtonTooltip", @"")];
	[shuffleButton setToolTip:NSLocalizedString(@"ShuffleButtonTooltip", @"")];
	[repeatButton setToolTip:NSLocalizedString(@"RepeatButtonTooltip", @"")];
	[fileButton setToolTip:NSLocalizedString(@"FileButtonTooltip", @"")];
	
	[self registerHotKeys];
	
    [spotlightWindowController init];
	
	//Init Remote
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"]) {
		[remote startListening:self];
	}
	
	[[playlistController undoManager] disableUndoRegistration];
	NSString *filename = @"~/Library/Application Support/Cog/Default.m3u";
	[playlistLoader addURL:[NSURL fileURLWithPath:[filename stringByExpandingTildeInPath]]];
	[[playlistController undoManager] enableUndoRegistration];

    // Restore playlist position
    int peIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastPlayedPlaylistEntry"];
    NSUInteger playlistSize = [[playlistController arrangedObjects] count];
    if ( 0 < peIdx && peIdx < playlistSize) {
        PlaylistEntry *pe = [playlistController entryAtIndex:peIdx];
        DLog(@"Restoring playlist entry: %@", [pe description]);
        [playlistController setCurrentEntry:pe];
        [playlistView selectRow:peIdx byExtendingSelection:NO];
    } else {
        DLog(@"Invalid playlist position to restore (pos=%d, playlist size=%d)", peIdx, playlistSize);
    }

    // Restore mini mode
    [self setMiniMode:[[NSUserDefaults standardUserDefaults] boolForKey:@"miniMode"]];

    // Restore file tree state
    
    // We need file tree view to restore its state here
    // so attempt to access file tree view controller's root view
    // to force it to read nib and create file tree view for us
    //
    // TODO: there probably is a more elegant way to do all this
    //       but i'm too stupid/tired to figure it out now
    [fileTreeViewController view];
    
    FileTreeOutlineView* outlineView = [fileTreeViewController outlineView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nodeExpanded:) name:NSOutlineViewItemDidExpandNotification object:outlineView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nodeCollapsed:) name:NSOutlineViewItemDidCollapseNotification object:outlineView];
    
    NSArray *expandedNodesArray = [[NSUserDefaults standardUserDefaults] valueForKey:@"fileTreeViewExpandedNodes"];
    
    if (expandedNodesArray)
    {
        expandedNodes = [[NSMutableSet alloc] initWithArray:expandedNodesArray];
    }
    else
    {
        expandedNodes = [[NSMutableSet alloc] init];
    }
    
    DLog(@"Nodes to expand: %@", [expandedNodes description]);
    
    DLog(@"Num of rows: %ld", [outlineView numberOfRows]);
    
    if (!outlineView) 
    {
        DLog(@"outlineView is NULL!");
    }
    
    [outlineView reloadData];
    
    for (NSInteger i=0; i<[outlineView numberOfRows]; i++)
    {
        PathNode *pn = [outlineView itemAtRow:i];
        NSString *str = [[pn URL] absoluteString];
        
        if ([expandedNodes containsObject:str])
        {
            [outlineView expandItem:pn];
        }
    }
}

- (void)nodeExpanded:(NSNotification*)notification
{
    PathNode* node = [[notification userInfo] objectForKey:@"NSObject"];
    NSString* url = [[node URL] absoluteString];

    [expandedNodes addObject:url];
}

- (void)nodeCollapsed:(NSNotification*)notification
{
    PathNode* node = [[notification userInfo] objectForKey:@"NSObject"];
    NSString* url = [[node URL] absoluteString];

    [expandedNodes removeObject:url];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Save playlist position
    PlaylistEntry *pe = [playlistController currentEntry];
    int peIdx = [pe index];
    DLog(@"Saving playlist position: idx = %d, %@", peIdx, [pe description]);
    [[NSUserDefaults standardUserDefaults] setInteger:peIdx forKey:@"lastPlayedPlaylistEntry"];
    
	[playbackController stop:self];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *folder = @"~/Library/Application Support/Cog/";
	
	folder = [folder stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}
	
	NSString *fileName = @"Default.m3u";
	
	[playlistLoader saveM3u:[folder stringByAppendingPathComponent: fileName]];
    
    //
    DLog(@"Saving expanded nodes: %@", [expandedNodes description]);
    
    [[NSUserDefaults standardUserDefaults] setValue:[expandedNodes allObjects] forKey:@"fileTreeViewExpandedNodes"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    BOOL miniaturized = [mainWindow isMiniaturized];
	if (flag == NO || miniaturized == YES)
		[mainWindow makeKeyAndOrderFront:self];
	
	return NO;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSArray* urls = [NSArray arrayWithObject:[NSURL fileURLWithPath:filename]];
	[playlistLoader willInsertURLs:urls origin:URLOriginExternal];
	[playlistLoader didInsertURLs:[playlistLoader addURLs:urls sort:NO] origin:URLOriginExternal];
	return YES;
}

- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames
{
	//Need to convert to urls
	NSMutableArray *urls = [NSMutableArray array];
	
	for (NSString *filename in filenames)
	{
		[urls addObject:[NSURL fileURLWithPath:filename]];
	}
	[playlistLoader willInsertURLs:urls origin:URLOriginExternal];
	[playlistLoader didInsertURLs:[playlistLoader addURLs:urls sort:YES] origin:URLOriginExternal];
	[theApplication replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (IBAction)toggleInfoDrawer:(id)sender
{
	[mainWindow makeKeyAndOrderFront:self];
	
	[infoDrawer toggle:self];
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	if ([notification object] == infoDrawer) {
		[infoButton setState:NSOnState];
	}
}

- (void)drawerDidClose:(NSNotification *)notification
{
	if ([notification object] == infoDrawer) {
		[infoButton setState:NSOffState];
	}
}

- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/project/project_donations.php?group_id=140003"]];
}

- (void)initDefaults
{
	NSMutableDictionary *userDefaultsValuesDict = [NSMutableDictionary dictionary];
	
    // Font defaults
    float fFontSize = [NSFont systemFontSizeForControlSize:NSSmallControlSize];
    NSNumber *fontSize = [NSNumber numberWithFloat:fFontSize];
    [userDefaultsValuesDict setObject:fontSize forKey:@"fontSize"];
	
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:35] forKey:@"hotKeyPlayKeyCode"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeyPlayModifiers"];
	
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:45] forKey:@"hotKeyNextKeyCode"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeyNextModifiers"];
	
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:15] forKey:@"hotKeyPreviousKeyCode"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeyPreviousModifiers"];

	[userDefaultsValuesDict setObject:[NSNumber numberWithBool:YES] forKey:@"remoteEnabled"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithBool:YES] forKey:@"remoteOnlyOnActive"];

	[userDefaultsValuesDict setObject:@"http://mamburu.net/cog/stable.xml" forKey:@"SUFeedURL"];


	[userDefaultsValuesDict setObject:@"clearAndPlay" forKey:@"openingFilesBehavior"];
	[userDefaultsValuesDict setObject:@"enqueue" forKey:@"openingFilesAlteredBehavior"];
	
	//Register and sync defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsValuesDict];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	//Add observers
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hotKeyPlayKeyCode"		options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hotKeyPreviousKeyCode"	options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hotKeyNextKeyCode"		options:0 context:nil];

	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.remoteEnabled"			options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.remoteOnlyOnActive"		options:0 context:nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
					   ofObject:(id)object
						 change:(NSDictionary *)change
                        context:(void *)context
{
	if ([keyPath isEqualToString:@"values.hotKeyPlayKeyCode"]) {
		[self registerHotKeys];
	}
	else if ([keyPath isEqualToString:@"values.hotKeyPreviousKeyCode"]) {
		[self registerHotKeys];
	}
	else if ([keyPath isEqualToString:@"values.hotKeyNextKeyCode"]) {
		[self registerHotKeys];
	}
	else if ([keyPath isEqualToString:@"values.remoteEnabled"] || [keyPath isEqualToString:@"values.remoteOnlyOnActive"]) {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"]) {
			BOOL onlyOnActive = [[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"];
			if (!onlyOnActive || [NSApp isActive]) {
				[remote startListening: self];
			}
			if (onlyOnActive && ![NSApp isActive]) { //Setting a preference without being active? *shrugs*
				[remote stopListening: self]; 
			}
		}
		else {
			[remote stopListening: self]; 
		}
	}
}

- (void)registerHotKeys
{
	[playHotKey release];
	playHotKey = [[NDHotKeyEvent alloc]
		initWithKeyCode: [[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyPlayKeyCode"] intValue]
		  modifierFlags: [[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyPlayModifiers"] intValue]
		];
	
	[prevHotKey release];
	prevHotKey = [[NDHotKeyEvent alloc]
		  initWithKeyCode: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPreviousKeyCode"]
			modifierFlags: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPreviousModifiers"]
		];
	
	[nextHotKey release];
	nextHotKey = [[NDHotKeyEvent alloc]
		initWithKeyCode: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyNextKeyCode"]
			modifierFlags: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyNextModifiers"]
		];
	
	[playHotKey setTarget:self selector:@selector(clickPlay)];
	[prevHotKey setTarget:self selector:@selector(clickPrev)];
	[nextHotKey setTarget:self selector:@selector(clickNext)];
	
	[playHotKey setEnabled:YES];	
	[prevHotKey setEnabled:YES];
	[nextHotKey setEnabled:YES];
}
     
- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
    DLog(@"Entering fullscreen");
    if (nil == nowPlaying)
    {
        nowPlaying = [[NowPlayingBarController alloc] init];
        [nowPlaying retain];
        
        NSView *contentView = [mainWindow contentView];
        NSRect contentRect = [contentView frame];
        const NSSize windowSize = [contentView convertSize:[mainWindow frame].size fromView: nil];
        
        NSRect nowPlayingFrame = [[nowPlaying view] frame];
        nowPlayingFrame.size.width = windowSize.width;
        [[nowPlaying view] setFrame: nowPlayingFrame];
        
        [contentView addSubview: [nowPlaying view]];
        [[nowPlaying view] setFrameOrigin: NSMakePoint(0.0, NSMaxY(contentRect) - nowPlayingFrame.size.height)];
        
        NSRect mainViewFrame = [mainView frame];
        mainViewFrame.size.height -= nowPlayingFrame.size.height;
        [mainView setFrame:mainViewFrame];

        [[nowPlaying text] bind:@"value" toObject:currentEntryController withKeyPath:@"content.display" options:nil];
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    DLog(@"Exiting fullscreen");
    if (nowPlaying) 
    {
        NSRect nowPlayingFrame = [[nowPlaying view] frame];
        NSRect mainViewFrame = [mainView frame];
        mainViewFrame.size.height += nowPlayingFrame.size.height;
        [mainView setFrame:mainViewFrame];
//        [mainView setFrameOrigin:NSMakePoint(0.0, 0.0)];
        
        [[nowPlaying view] removeFromSuperview];
        [nowPlaying release];
        nowPlaying = nil;
    }
}
     
- (void)clickPlay
{
	[playbackController playPauseResume:self];
}

- (void)clickPrev
{
	[playbackController prev:nil];
}

- (void)clickNext
{
	[playbackController next:nil];
}

- (void)changeFontSize:(float)size
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float fCurrentSize = [defaults floatForKey:@"fontSize"];
    NSNumber *newSize = [NSNumber numberWithFloat:(fCurrentSize + size)];
    [defaults setObject:newSize forKey:@"fontSize"];
}

- (IBAction)increaseFontSize:(id)sender
{
	[self changeFontSize:1];
}

- (IBAction)decreaseFontSize:(id)sender
{
	[self changeFontSize:-1];
}

- (IBAction)toggleMiniMode:(id)sender
{
    [self setMiniMode:(!miniMode)];
}

- (BOOL)miniMode
{
    return miniMode;
}

- (void)setMiniMode:(BOOL)newMiniMode
{
    miniMode = newMiniMode;
    [[NSUserDefaults standardUserDefaults] setBool:miniMode forKey:@"miniMode"];

    NSWindow *windowToShow = miniMode ? miniWindow : mainWindow;
    NSWindow *windowToHide = miniMode ? mainWindow : miniWindow;

    [windowToHide close];
    [windowToShow makeKeyAndOrderFront:self];
}
@end

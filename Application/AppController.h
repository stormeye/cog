/* AppController */

#import <Cocoa/Cocoa.h>

#import "NDHotKey/NDHotKeyEvent.h"

@class PlaybackController;
@class PlaylistController;
@class PlaylistView;
@class AppleRemote;
@class PlaylistLoader;

@interface AppController : NSObject
{
	IBOutlet PlaybackController *playbackController;

    IBOutlet PlaylistController *playlistController;
	IBOutlet PlaylistLoader *playlistLoader;
	
	IBOutlet NSWindow *mainWindow;
	
	IBOutlet NSSegmentedControl *playbackButtons;
	IBOutlet NSButton *infoButton;
	IBOutlet NSButton *fileButton;
	IBOutlet NSButton *shuffleButton;
	IBOutlet NSButton *repeatButton;

	IBOutlet NSTextField *totalTimeField;
	
	IBOutlet NSDrawer *infoDrawer;

	IBOutlet PlaylistView *playlistView;
	
	IBOutlet NSMenuItem *showIndexColumn;
	IBOutlet NSMenuItem *showTitleColumn;
	IBOutlet NSMenuItem *showArtistColumn;
	IBOutlet NSMenuItem *showAlbumColumn;
	IBOutlet NSMenuItem *showGenreColumn;
	IBOutlet NSMenuItem *showLengthColumn;
	IBOutlet NSMenuItem *showTrackColumn;
	IBOutlet NSMenuItem *showYearColumn;
	
    IBOutlet NSWindowController *spotlightWindowController;
	
	NDHotKeyEvent *playHotKey;
	NDHotKeyEvent *prevHotKey;
	NDHotKeyEvent *nextHotKey;
	
	AppleRemote *remote;
	BOOL remoteButtonHeld; /* true as long as the user holds the left,right,plus or minus on the remote control */
	
    NSOperationQueue *queue; // Since we are the app delegate, we take care of the op queue
}

- (IBAction)openURL:(id)sender;

- (IBAction)openFiles:(id)sender;
- (IBAction)delEntries:(id)sender;
- (IBAction)savePlaylist:(id)sender;

- (IBAction)donate:(id)sender;

- (IBAction)toggleInfoDrawer:(id)sender;
- (void)drawerDidOpen:(NSNotification *)notification;
- (void)drawerDidClose:(NSNotification *)notification;

- (void)initDefaults;

	//Fun stuff
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag;
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames;

- (void)registerHotKeys;
OSStatus handleHotKey(EventHandlerCallRef nextHandler,EventRef theEvent,void *userData);


- (void)clickPlay;
- (void)clickPrev;
- (void)clickNext;

- (IBAction)increaseFontSize:(id)sender;
- (IBAction)decreaseFontSize:(id)sender;
- (void)changeFontSize:(float)size;

@end

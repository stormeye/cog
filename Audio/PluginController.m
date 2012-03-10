#import "PluginController.h"
#import "Plugin.h"

#import "Logging.h"

@implementation PluginController

@synthesize sources;
@synthesize containers;
@synthesize metadataReaders;

@synthesize propertiesReadersByExtension;
@synthesize propertiesReadersByMimeType;

@synthesize decodersByExtension;
@synthesize decodersByMimeType;

@synthesize configured;

static PluginController *sharedPluginController = nil;

+ (id<CogPluginController>)sharedPluginController
{
	@synchronized(self) {
		if (sharedPluginController == nil) {
			sharedPluginController = [[self alloc] init];
		}
	}
	
	return sharedPluginController;
}


- (id)init {
	self = [super init];
	if (self) {
        self.sources = [[[NSMutableDictionary alloc] init] autorelease];
        self.containers = [[[NSMutableDictionary alloc] init] autorelease];
 
        self.metadataReaders = [[[NSMutableDictionary alloc] init] autorelease];
 
        self.propertiesReadersByExtension = [[[NSMutableDictionary alloc] init] autorelease];
        self.propertiesReadersByMimeType = [[[NSMutableDictionary alloc] init] autorelease];
 
        self.decodersByExtension = [[[NSMutableDictionary alloc] init] autorelease];
        self.decodersByMimeType = [[[NSMutableDictionary alloc] init] autorelease];

        [self setup];
	}
	
	return self;
}

- (void)setup
{
	if (self.configured == NO) {
		self.configured = YES;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bundleDidLoad:) name:NSBundleDidLoadNotification object:nil];

		[self loadPlugins];
		[self printPluginInfo];
	}	
}

- (void)bundleDidLoad:(NSNotification *)notification
{
	NSArray *classNames = [[notification userInfo] objectForKey:@"NSLoadedClasses"];
	for (NSString *className in classNames)
	{
		DLog(@"Class loaded: %@", className);
		Class bundleClass = NSClassFromString(className);
		if ([bundleClass conformsToProtocol:@protocol(CogContainer)]) {
			[self setupContainer:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogDecoder)]) {
			[self setupDecoder:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogMetadataReader)]) {
			[self setupMetadataReader:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogPropertiesReader)]) {
			[self setupPropertiesReader:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogSource)]) {
			[self setupSource:className];
		}
	}
}

- (void)loadPluginsAtPath:(NSString *)path
{

	NSArray *dirContents = [[NSFileManager defaultManager] directoryContentsAtPath:path];

	for (NSString *pname in dirContents)
	{
		NSString *ppath;
		ppath = [NSString pathWithComponents:[NSArray arrayWithObjects:path,pname,nil]];
		
		if ([[pname pathExtension] isEqualToString:@"bundle"])
		{
			NSBundle *b = [NSBundle bundleWithPath:ppath];
			[b load];
		}
	}
}

- (void)loadPlugins
{
	[self loadPluginsAtPath:[[NSBundle mainBundle] builtInPlugInsPath]];
	[self loadPluginsAtPath:[@"~/Library/Application Support/Cog/Plugins" stringByExpandingTildeInPath]];
}

- (void)setupContainer:(NSString *)className
{
	Class container = NSClassFromString(className);
	if (container && [container respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [container fileTypes])
		{
			[containers setObject:className forKey:[fileType lowercaseString]];
		}
	}
}

- (void)setupDecoder:(NSString *)className
{
	Class decoder = NSClassFromString(className);
	if (decoder && [decoder respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [decoder fileTypes])
		{
			[decodersByExtension setObject:className forKey:[fileType lowercaseString]];
		}
	}
	
	if (decoder && [decoder respondsToSelector:@selector(mimeTypes)]) {
		for (id mimeType in [decoder mimeTypes]) 
		{
			[decodersByMimeType setObject:className forKey:[mimeType lowercaseString]];
		}
	}
}

- (void)setupMetadataReader:(NSString *)className
{
	Class metadataReader = NSClassFromString(className);
	if (metadataReader && [metadataReader respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [metadataReader fileTypes])
		{
			[metadataReaders setObject:className forKey:[fileType lowercaseString]];
		}
	}
}

- (void)setupPropertiesReader:(NSString *)className
{
	Class propertiesReader = NSClassFromString(className);
	if (propertiesReader && [propertiesReader respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [propertiesReader fileTypes])
		{
			[propertiesReadersByExtension setObject:className forKey:[fileType lowercaseString]];
		}
	}

	if (propertiesReader && [propertiesReader respondsToSelector:@selector(mimeTypes)]) {
		for (id mimeType in [propertiesReader mimeTypes])
		{
			[propertiesReadersByMimeType setObject:className forKey:[mimeType lowercaseString]];
		}
	}
}

- (void)setupSource:(NSString *)className
{
	Class source = NSClassFromString(className);
	if (source && [source respondsToSelector:@selector(schemes)]) {
		for (id scheme in [source schemes])
		{
			[sources setObject:className forKey:scheme];
		}
	}
}

- (void)printPluginInfo
{
	ALog(@"Sources: %@", self.sources);
	ALog(@"Containers: %@", self.containers);
	ALog(@"Metadata Readers: %@", self.metadataReaders);

	ALog(@"Properties Readers By Extension: %@", self.propertiesReadersByExtension);
	ALog(@"Properties Readers By Mime Type: %@", self.propertiesReadersByMimeType);

	ALog(@"Decoders by Extension: %@", self.decodersByExtension);
	ALog(@"Decoders by Mime Type: %@", self.decodersByMimeType);
}

- (id<CogSource>) audioSourceForURL:(NSURL *)url
{
	NSString *scheme = [url scheme];
	
	Class source = NSClassFromString([sources objectForKey:scheme]);
	
	return [[[source alloc] init] autorelease];
}

- (NSArray *) urlsForContainerURL:(NSURL *)url
{
	NSString *ext = [[url path] pathExtension];
	
	Class container = NSClassFromString([containers objectForKey:[ext lowercaseString]]);
	
	return [container urlsForContainerURL:url];
}

//Note: Source is assumed to already be opened.
- (id<CogDecoder>) audioDecoderForSource:(id <CogSource>)source
{
	NSString *ext = [[[source url] path] pathExtension];
	NSString *classString = [decodersByExtension objectForKey:[ext lowercaseString]];
	if (!classString) {
		classString = [decodersByMimeType objectForKey:[[source mimeType] lowercaseString]];
	}

	Class decoder = NSClassFromString(classString);
	
	return [[[decoder alloc] init] autorelease];
}

- (NSDictionary *)metadataForURL:(NSURL *)url
{
	NSString *ext = [[url path] pathExtension];
	
	Class metadataReader = NSClassFromString([metadataReaders objectForKey:[ext lowercaseString]]);
	
	return [metadataReader metadataForURL:url];
	
}


//If no properties reader is defined, use the decoder's properties.
- (NSDictionary *)propertiesForURL:(NSURL *)url
{
	NSString *ext = [[url path] pathExtension];
	
	id<CogSource> source = [self audioSourceForURL:url];
	if (![source open:url])
		return nil;

	NSString *classString = [propertiesReadersByExtension objectForKey:[ext lowercaseString]];
	if (!classString) {
		classString = [propertiesReadersByMimeType objectForKey:[[source mimeType] lowercaseString]];
	}

	if (classString)
	{
		Class propertiesReader = NSClassFromString(classString);

		 return [propertiesReader propertiesForSource:source];
	}
	else
	{
	
		id<CogDecoder> decoder = [self audioDecoderForSource:source];
		if (![decoder open:source])
		{
			return nil;
		}
		
		NSDictionary *properties = [decoder properties];
		
		[decoder close];
		
		return properties;
	}
}

@end


/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 */
#import "iMBMusicFolder.h"
#import "iMedia.h"
#import <QTKit/QTKit.h>

@implementation iMBMusicFolder

- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Music"]])
	{
		
	}
	return self;
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSArray *movieTypes = [QTMovie movieFileTypes:QTIncludeAllTypes];
	NSMutableArray *tracks = [NSMutableArray array];
	NSBundle *bndl = [NSBundle bundleForClass:[self class]];
	NSString *iconPath = [bndl pathForResource:@"MBiTunes4Song" ofType:@"png"];
	NSImage *songIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	iconPath = [bndl pathForResource:@"iTunesDRM" ofType:@"png"];
	NSImage *drmIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	int poolRelease = 0;
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		if ([[filePath lastPathComponent] isEqualToString:@"iTunes"]) continue;
		if ([[filePath lastPathComponent] isEqualToString:@"GarageBand"]) continue;
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir && ![fm isPathHidden:cur])
		{
			iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
			[root addItem:folder];
			[folder release];
			[folder setIconName:@"folder"];
			[folder setName:[fm displayNameAtPath:[fm displayNameAtPath:[cur lastPathComponent]]]];
			[self recursivelyParse:filePath withNode:folder];
		}
		else
		{
			if ([movieTypes indexOfObject:[[filePath lowercaseString] pathExtension]] != NSNotFound)
			{
				NSMutableDictionary *song = [NSMutableDictionary dictionary]; 
				
				//we want to cache the first frame of the movie here as we will be in a background thread
				QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:[[NSURL fileURLWithPath:filePath] path]];
				NSError *error = nil;
				QTMovie *movie = [[QTMovie alloc] initWithAttributes:
					[NSDictionary dictionaryWithObjectsAndKeys: 
						ref, QTMovieDataReferenceAttribute,
						[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
						nil] error:&error];
				
				// Get the meta data from the QTMovie
				NSString *val = [movie attributeWithFourCharCode:kUserDataTextFullName];
				if (!val)
				{
					val = [cur stringByDeletingPathExtension];
				}
				[song setObject:val forKey:@"Name"];
				val = [movie attributeWithFourCharCode:FOUR_CHAR_CODE('©ART')];
				if (!val)
				{
					val = LocalizedStringInThisBundle(@"Unknown", @"Unkown music key");
				}
				[song setObject:val forKey:@"Artist"];
				QTTime duration = [movie duration];
				NSNumber *time = [NSNumber numberWithDouble:GetMovieDuration( [movie quickTimeMovie] )];
				[song setObject:time forKey:@"Total Time"];
				[song setObject:filePath forKey:@"Location"];
				[song setObject:filePath forKey:@"Preview"];
				if (![movie isDRMProtected])
				{
					[song setObject:songIcon forKey:@"Icon"];
				}
				else
				{
					[song setObject:drmIcon forKey:@"Icon"];
				}
				
				[movie release];
				[tracks addObject:song];
			}
		}
		poolRelease++;
		if (poolRelease == 5)
		{
			poolRelease = 0;
			[innerPool release];
			innerPool = [[NSAutoreleasePool alloc] init];
		}
	}
	[innerPool release];
	[root setAttribute:tracks forKey:@"Tracks"];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"Music Folder", @"Name of your 'Music' folder in your home directory")];
	[root setIconName:@"folder"];
	NSString *folder = [self databasePath];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:folder])
	{
		[root release];
		return nil;
	}
	
	[self recursivelyParse:folder withNode:root];
	
	return [root autorelease];
}

@end
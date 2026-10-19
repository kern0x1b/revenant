#import <Foundation/Foundation.h>

// MPMediaPlaylistPropertyCloudGlobalID, and it is in ITS OWN object because release-split on the object
// that carried it alongside the twelve 9.0 constants reported:
//
//     MediaPlayerConstants90.o  MIXED-RELEASES  8.2,9.0
//
// so it first appears at 8.2 and the other twelve at 9.0, and one file carrying both mixes two
// releases' symbols. The corpus filed it under 9.0 with the rest; the tool is the authority for a ladder
// and its row is corrected to 8.2.
//
// The value is Apple's, measured from the host's own MediaPlayer by dlsym: "cloudGlobalID", 13 bytes,
// 636c6f7564476c6f62616c4944. It is NOT this symbol's own name by convention - the convention happens
// to agree here and disagrees for twelve of the other thirteen, which is why the value is read.
//
// iOS 6.1.3 exports none of the 31 MediaPlayer constants, so the port carries this one. A constant is
// READ and never CALLED: nothing here touches MPMediaLibrary, MPMediaQuery or a library.

extern NSString *const MPMediaPlaylistPropertyCloudGlobalID;

NSString *const MPMediaPlaylistPropertyCloudGlobalID = @"cloudGlobalID";

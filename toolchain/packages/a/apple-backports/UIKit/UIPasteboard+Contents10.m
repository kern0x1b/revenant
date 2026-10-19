#import <UIKit/UIKit.h>

@implementation UIPasteboard (CharonContents10)

- (BOOL)hasStrings
{
    return [self containsPasteboardTypes:UIPasteboardTypeListString];
}

- (BOOL)hasURLs
{
    return [self containsPasteboardTypes:UIPasteboardTypeListURL];
}

- (BOOL)hasImages
{
    return [self containsPasteboardTypes:UIPasteboardTypeListImage];
}

- (BOOL)hasColors
{
    return [self containsPasteboardTypes:UIPasteboardTypeListColor];
}

@end

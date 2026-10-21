#import <Foundation/Foundation.h>

@implementation NSFileManager (RevenantTemporaryDirectory)

- (NSURL *)temporaryDirectory
{
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

@end

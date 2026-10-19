#import <Foundation/Foundation.h>

@implementation NSFileManager (CharonTemporaryDirectory)

- (NSURL *)temporaryDirectory
{
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

@end

#import <Foundation/Foundation.h>
#import <objc/message.h>

@implementation NSURLCache (CharonDirectoryURL)

- (instancetype)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity directoryURL:(NSURL *)directoryURL
{
    NSString *path = directoryURL.isFileURL ? directoryURL.path.stringByStandardizingPath : nil;
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject.stringByStandardizingPath;
    if (path && caches && [path hasPrefix:[caches stringByAppendingString:@"/"]])
        path = [path substringFromIndex:caches.length + 1];
    return ((id (*)(id, SEL, NSUInteger, NSUInteger, id))objc_msgSend)(self, NSSelectorFromString(@"initWithMemoryCapacity:diskCapacity:diskPath:"), memoryCapacity, diskCapacity, path);
}

@end

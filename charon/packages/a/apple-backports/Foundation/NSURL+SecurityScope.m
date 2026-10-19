#import <Foundation/Foundation.h>

@implementation NSURL (CharonSecurityScope)

- (BOOL)startAccessingSecurityScopedResource
{
    return YES;
}

- (void)stopAccessingSecurityScopedResource
{
}

@end

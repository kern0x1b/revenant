#import <Foundation/Foundation.h>

@implementation NSURL (RevenantSecurityScope)

- (BOOL)startAccessingSecurityScopedResource
{
    return YES;
}

- (void)stopAccessingSecurityScopedResource
{
}

@end

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char charon_container_key;

@implementation NSURLSessionConfiguration (CharonSharedContainer)

- (NSString *)sharedContainerIdentifier
{
    return objc_getAssociatedObject(self, &charon_container_key);
}

- (void)setSharedContainerIdentifier:(NSString *)sharedContainerIdentifier
{
    objc_setAssociatedObject(self, &charon_container_key, [sharedContainerIdentifier copy], OBJC_ASSOCIATION_COPY);
}

@end

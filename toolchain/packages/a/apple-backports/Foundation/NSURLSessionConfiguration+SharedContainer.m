#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char revenant_container_key;

@implementation NSURLSessionConfiguration (RevenantSharedContainer)

- (NSString *)sharedContainerIdentifier
{
    return objc_getAssociatedObject(self, &revenant_container_key);
}

- (void)setSharedContainerIdentifier:(NSString *)sharedContainerIdentifier
{
    objc_setAssociatedObject(self, &revenant_container_key, [sharedContainerIdentifier copy], OBJC_ASSOCIATION_COPY);
}

@end

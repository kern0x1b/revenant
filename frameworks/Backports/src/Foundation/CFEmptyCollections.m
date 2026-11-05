#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

__attribute__((visibility("default"))) void *BACKPORT_IMPL(__NSArray0__);
__attribute__((visibility("default"))) void *BACKPORT_IMPL(__NSDictionary0__);

__attribute__((constructor)) static void revenant_empty_collections(void)
{
    BACKPORT_IMPL(__NSArray0__) = (void *)CFRetain((__bridge CFTypeRef)[NSArray array]);
    BACKPORT_IMPL(__NSDictionary0__) = (void *)CFRetain((__bridge CFTypeRef)[NSDictionary dictionary]);
}

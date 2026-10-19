#import <Foundation/Foundation.h>

__attribute__((visibility("default"))) void *__NSArray0__;
__attribute__((visibility("default"))) void *__NSDictionary0__;

__attribute__((constructor)) static void charon_empty_collections(void)
{
    __NSArray0__ = (void *)CFRetain((__bridge CFTypeRef)[NSArray array]);
    __NSDictionary0__ = (void *)CFRetain((__bridge CFTypeRef)[NSDictionary dictionary]);
}

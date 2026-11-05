#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

NSErrorUserInfoKey const BACKPORT_IMPL(NSMultipleUnderlyingErrorsKey) = @"NSMultipleUnderlyingErrorsKey";

@implementation NSError (RevenantUnderlyingErrors14)

- (NSArray<NSError *> *)underlyingErrors
{
    NSDictionary *info = self.userInfo;
    NSMutableArray *errors = [NSMutableArray array];
    id single = info[NSUnderlyingErrorKey];
    if ([single isKindOfClass:[NSError class]])
        [errors addObject:single];
    id multiple = info[BACKPORT_IMPL(NSMultipleUnderlyingErrorsKey)];
    if ([multiple isKindOfClass:[NSArray class]]) {
        for (id error in multiple) {
            if ([error isKindOfClass:[NSError class]])
                [errors addObject:error];
        }
    }
    return errors;
}

@end

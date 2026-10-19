#import <Foundation/Foundation.h>

static inline void charon_abstract(id object, SEL selector)
{
    [NSException raise:NSInvalidArgumentException format:@"*** -%@ cannot be sent to an abstract object of class %@: Create a concrete instance!", NSStringFromSelector(selector), NSStringFromClass([object class])];
}

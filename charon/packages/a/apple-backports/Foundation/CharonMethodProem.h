#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static inline NSString *charon_method_proem(id receiver, SEL selector)
{
    Class receiverClass = receiver ? (class_isMetaClass(object_getClass(receiver)) ? (Class)receiver : [receiver class]) : Nil;
    return [NSString stringWithFormat:@"*** %c[%s %s]", receiverClass == (Class)receiver ? '+' : '-',
                                      receiverClass ? class_getName(receiverClass) : "nil", sel_getName(selector)];
}

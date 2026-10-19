#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *BoundsKey = &BoundsKey;

static Ivar ivar(id object, const char *name)
{
    return class_getInstanceVariable([object class], name);
}

static void hold(id object, Ivar held, id value)
{
    id previous = object_getIvar(object, held);
    object_setIvar(object, held, value ? (__bridge id)CFRetain((__bridge CFTypeRef)value) : nil);
    if (previous)
        CFRelease((__bridge CFTypeRef)previous);
}

@implementation NSTextAttachment (CharonText7)

- (CGRect)bounds
{
    NSValue *held = objc_getAssociatedObject(self, BoundsKey);
    return held ? held.CGRectValue : CGRectZero;
}

- (void)setBounds:(CGRect)bounds
{
    objc_setAssociatedObject(self, BoundsKey, [NSValue valueWithCGRect:bounds], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSData *)contents
{
    Ivar held = ivar(self, "_data");
    return held ? object_getIvar(self, held) : nil;
}

- (void)setContents:(NSData *)contents
{
    Ivar held = ivar(self, "_data");
    if (held)
        hold(self, held, [contents copy]);
}

- (NSString *)fileType
{
    Ivar held = ivar(self, "_uti");
    return held ? object_getIvar(self, held) : nil;
}

- (void)setFileType:(NSString *)type
{
    Ivar held = ivar(self, "_uti");
    if (held)
        hold(self, held, [type copy]);
}

- (void)setFileWrapper:(NSFileWrapper *)wrapper
{
    self.contents = wrapper.regularFileContents;
}

@end

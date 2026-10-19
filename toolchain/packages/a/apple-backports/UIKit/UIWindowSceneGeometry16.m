#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

@implementation UIWindowSceneGeometry {
    UIInterfaceOrientation _orientation;
}

- (instancetype)initRevenantWithOrientation:(UIInterfaceOrientation)orientation
{
    struct objc_super parent = {self, class_getSuperclass([UIWindowSceneGeometry class])};
    if ((self = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&parent, @selector(init))))
        _orientation = orientation;
    return self;
}

- (UIInterfaceOrientation)interfaceOrientation
{
    return _orientation;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initRevenantWithOrientation:_orientation];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; interfaceOrientation = %ld>", [self class], self, (long)_orientation];
}

@end

@implementation UIWindowScene (RevenantSceneGeometry16)

- (UIWindowSceneGeometry *)effectiveGeometry
{
    return [[UIWindowSceneGeometry alloc] initRevenantWithOrientation:self.interfaceOrientation];
}

@end

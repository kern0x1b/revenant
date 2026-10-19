#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

// The scene's resolved geometry, iOS 16.0.
//
// UIWindowSceneGeometry.h on iOS carries exactly one value: interfaceOrientation. Its systemFrame is
// macCatalyst-only and unavailable on iOS, and the coordinate space and the size restrictions the
// scene answers are 13.0 members of UIWindowScene itself, not of this object. So this is a readonly
// value object over one resolved orientation, and -[UIWindowScene effectiveGeometry] builds it from
// the orientation the scene already answers.
//
// -init is NS_UNAVAILABLE in the header, so the value is made through the Charon initializer, the way
// UIWindowSceneGeometryPreferences makes its own.

@implementation UIWindowSceneGeometry {
    UIInterfaceOrientation _orientation;
}

- (instancetype)initCharonWithOrientation:(UIInterfaceOrientation)orientation
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
    // Readonly and immutable: a copy is the same resolved value, made the same way.
    return [[[self class] allocWithZone:zone] initCharonWithOrientation:_orientation];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; interfaceOrientation = %ld>", [self class], self, (long)_orientation];
}

@end

@implementation UIWindowScene (CharonSceneGeometry16)

// A snapshot of what the scene resolves to now, as the header says: the current resolved values.
- (UIWindowSceneGeometry *)effectiveGeometry
{
    return [[UIWindowSceneGeometry alloc] initCharonWithOrientation:self.interfaceOrientation];
}

@end
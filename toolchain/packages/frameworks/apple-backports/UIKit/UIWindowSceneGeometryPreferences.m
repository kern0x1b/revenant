#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

@implementation UIWindowSceneGeometryPreferences
@end

@implementation UIWindowSceneGeometryPreferencesIOS

- (instancetype)init
{
    return [self initWithInterfaceOrientations:0];
}

- (instancetype)initWithInterfaceOrientations:(UIInterfaceOrientationMask)interfaceOrientations
{
    struct objc_super parent = {self, class_getSuperclass([UIWindowSceneGeometryPreferencesIOS class])};
    if ((self = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&parent, @selector(init))))
        _interfaceOrientations = interfaceOrientations;
    return self;
}

@end

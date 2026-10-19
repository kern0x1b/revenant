#import <UIKit/UIKit.h>
#import <objc/message.h>

static id charon_appearance(Class owner, NSArray *containers)
{
    id (*send)(id, SEL, id, ...) = (id (*)(id, SEL, id, ...))objc_msgSend;
    SEL selector = @selector(appearanceWhenContainedIn:);
    Class classes[9] = {0};
    NSUInteger count = MIN(containers.count, (NSUInteger)8);
    for (NSUInteger index = 0; index < count; index++)
        classes[index] = containers[index];
    switch (count) {
    case 0:
        return [owner appearance];
    case 1:
        return send(owner, selector, classes[0], nil);
    case 2:
        return send(owner, selector, classes[0], classes[1], nil);
    case 3:
        return send(owner, selector, classes[0], classes[1], classes[2], nil);
    case 4:
        return send(owner, selector, classes[0], classes[1], classes[2], classes[3], nil);
    case 5:
        return send(owner, selector, classes[0], classes[1], classes[2], classes[3], classes[4], nil);
    case 6:
        return send(owner, selector, classes[0], classes[1], classes[2], classes[3], classes[4], classes[5], nil);
    case 7:
        return send(owner, selector, classes[0], classes[1], classes[2], classes[3], classes[4], classes[5], classes[6], nil);
    default:
        return send(owner, selector, classes[0], classes[1], classes[2], classes[3], classes[4], classes[5], classes[6], classes[7], nil);
    }
}

@implementation UIView (CharonAppearanceInstances)

+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes
{
    return charon_appearance(self, containerTypes);
}

@end

@implementation UIBarItem (CharonAppearanceInstances)

+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes
{
    return charon_appearance(self, containerTypes);
}

@end

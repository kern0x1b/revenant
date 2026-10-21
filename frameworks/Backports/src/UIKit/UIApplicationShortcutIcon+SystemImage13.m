#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantShortcutSystemImageKey;

@implementation UIApplicationShortcutIcon (RevenantSystemImage13)

+ (instancetype)iconWithSystemImageName:(NSString *)systemImageName
{
    UIApplicationShortcutIcon *icon = [[self alloc] init];
    objc_setAssociatedObject(icon, &RevenantShortcutSystemImageKey, [systemImageName copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return icon;
}

@end

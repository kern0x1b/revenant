#import "CharonMenus.h"

@interface UIMenuSystem ()
- (instancetype)initCharonWithContext:(BOOL)context;
@end

@implementation UIMenuSystem {
@private
    BOOL _context;
}

+ (UIMenuSystem *)mainSystem
{
    static UIMenuSystem *system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = [[UIMenuSystem alloc] initCharonWithContext:NO];
    });
    return system;
}

+ (UIMenuSystem *)contextSystem
{
    static UIMenuSystem *system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = [[UIMenuSystem alloc] initCharonWithContext:YES];
    });
    return system;
}

- (instancetype)initCharonWithContext:(BOOL)context
{
    if ((self = [super init]))
        _context = context;
    return self;
}

- (void)setNeedsRebuild
{
    charon_menus_say_once(@"rebuild", [NSString stringWithFormat:@"UIMenuSystem: iOS %@ has no menu bar and no key command menus, so there is no menu to rebuild and -setNeedsRebuild does nothing",
                                                                 [UIDevice currentDevice].systemVersion]);
}

- (void)setNeedsRevalidate
{
    charon_menus_say_once(@"revalidate", [NSString stringWithFormat:@"UIMenuSystem: iOS %@ has no menu bar and no key command menus, so there is no menu to revalidate and -setNeedsRevalidate does nothing",
                                                                    [UIDevice currentDevice].systemVersion]);
}

@end

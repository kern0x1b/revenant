#import <UIKit/UIKit.h>
#import "check.h"

@interface RevenantHostUITableViewRowAction : NSObject <NSCopying>
+ (instancetype)rowActionWithStyle:(NSInteger)style title:(NSString *)title handler:(void (^)(id action, NSIndexPath *path))handler;
@property (nonatomic, readonly) NSInteger style;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) UIColor *backgroundColor;
@property (nonatomic, copy) UIVisualEffect *backgroundEffect;
@end

static NSString *rgb(UIColor *color)
{
    if (!color)
        return @"nil";
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"%.2f %.2f %.2f %.2f", (double)red, (double)green, (double)blue, (double)alpha];
}

int main(void)
{
    @autoreleasepool {
        void (^handler)(id, NSIndexPath *) = ^(id action, NSIndexPath *path) {};
        for (NSInteger style = 0; style < 2; style++) {
            RevenantHostUITableViewRowAction *ours = [RevenantHostUITableViewRowAction rowActionWithStyle:style title:@"Title" handler:handler];
            UITableViewRowAction *system = [UITableViewRowAction rowActionWithStyle:(UITableViewRowActionStyle)style title:@"Title" handler:(void (^)(UITableViewRowAction *, NSIndexPath *))handler];
            revenant_check(ours.style == system.style && [ours.title isEqualToString:system.title], "style and title of a new action", @"they differ");
            revenant_check((ours.backgroundColor != nil) == (system.backgroundColor != nil), "a new action has a colour", @"the colour differs");
            if (style == 1)
                revenant_check([rgb(ours.backgroundColor) isEqualToString:rgb(system.backgroundColor)], "the colour of a normal action", [NSString stringWithFormat:@"%@ != %@", rgb(ours.backgroundColor), rgb(system.backgroundColor)]);
            revenant_check(ours.backgroundEffect == nil && system.backgroundEffect == nil, "no effect at first", @"an effect is there");
            RevenantHostUITableViewRowAction *ourCopy = [ours copy];
            UITableViewRowAction *systemCopy = [system copy];
            revenant_check((ourCopy != ours) == (systemCopy != system) && ourCopy.style == systemCopy.style && [ourCopy.title isEqualToString:systemCopy.title] && [rgb(ourCopy.backgroundColor) isEqualToString:rgb(ours.backgroundColor)], "a copy is another object with the same fields", @"the copy differs");
            revenant_check([ourCopy isEqual:ours] == [systemCopy isEqual:system], "a copy is equal to its original as it is for the system", @"the equality differs");
        }
        RevenantHostUITableViewRowAction *ours = [RevenantHostUITableViewRowAction rowActionWithStyle:1 title:@"t" handler:nil];
        UITableViewRowAction *system = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"t" handler:nil];
        ours.title = nil;
        system.title = nil;
        ours.backgroundColor = nil;
        system.backgroundColor = nil;
        revenant_check(ours.title == nil && system.title == nil && ours.backgroundColor == nil && system.backgroundColor == nil, "the title and the colour clear", @"one stays");
        UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        ours.backgroundEffect = effect;
        system.backgroundEffect = effect;
        revenant_check((ours.backgroundEffect == effect) == (system.backgroundEffect == effect), "an effect is kept as it is", @"the effect differs");
        revenant_check([[ours copy] backgroundEffect] == nil && [[system copy] backgroundEffect] == nil, "a copy leaves the effect behind", @"the copy holds the effect");
        revenant_check([[RevenantHostUITableViewRowAction alloc] init].style == 0 && [[RevenantHostUITableViewRowAction alloc] init].title == nil && [[RevenantHostUITableViewRowAction alloc] init].backgroundColor == nil, "a plain init has no title and no colour", @"the fields differ");
        revenant_check(![[RevenantHostUITableViewRowAction class] conformsToProtocol:@protocol(NSSecureCoding)] && ![UITableViewRowAction conformsToProtocol:@protocol(NSSecureCoding)], "the class is not archived", @"it adopts secure coding");
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}

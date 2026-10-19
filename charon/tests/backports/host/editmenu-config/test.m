#import <UIKit/UIKit.h>
#include <stdio.h>

// One body of checks, run on two classes in one process: the host's own UIEditMenuConfiguration (looked up by its name,
// which the -D rename in run.sh does not touch) and the port's, which run.sh compiles as the same identifier. Every check
// is sent by its selector name, so the two sides cannot differ by how they were called. A line is "side<TAB>check<TAB>value".

typedef id (*FactoryFn)(id, SEL, id, CGPoint);
typedef id (*AllocFn)(id, SEL);
typedef CGPoint (*PointFn)(id, SEL);
typedef NSInteger (*IntFn)(id, SEL);
typedef void (*SetIntFn)(id, SEL, NSInteger);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, [value UTF8String]);
}

static void run_side(const char *side, Class cls)
{
    SEL factory = NSSelectorFromString(@"configurationWithIdentifier:sourcePoint:");
    FactoryFn make = (FactoryFn)[cls methodForSelector:factory];

    NSNumber *number = @42;
    id withNumber = make(cls, factory, number, CGPointMake(3, 4));
    report(side, "identifier-kept-object", [withNumber identifier] == number ? @"yes" : @"no");

    NSMutableString *mutable = [NSMutableString stringWithString:@"abc"];
    id withMutable = make(cls, factory, mutable, CGPointZero);
    [mutable appendString:@"def"];
    report(side, "mutable-identifier-copied", ([withMutable identifier] != mutable) ? @"yes" : @"no");
    report(side, "mutable-identifier-value-after-mutation", [[withMutable identifier] description]);
    report(side, "mutable-identifier-class", NSStringFromClass([[withMutable identifier] class]));

    id nilOne = make(cls, factory, nil, CGPointZero);
    id nilTwo = make(cls, factory, nil, CGPointZero);
    report(side, "nil-identifier-class", NSStringFromClass([[nilOne identifier] class]));
    report(side, "nil-identifier-is-NSUUID", [[nilOne identifier] isKindOfClass:[NSUUID class]] ? @"yes" : @"no");
    report(side, "nil-identifier-distinct", [[nilOne identifier] isEqual:[nilTwo identifier]] ? @"no" : @"yes");
    report(side, "nil-identifier-description-length", [NSString stringWithFormat:@"%lu", (unsigned long)[[[nilOne identifier] description] length]]);

    report(side, "sourcePoint", NSStringFromCGPoint(((PointFn)[withNumber methodForSelector:@selector(sourcePoint)])(withNumber, @selector(sourcePoint))));

    SEL arrowGet = @selector(preferredArrowDirection);
    SEL arrowSet = NSSelectorFromString(@"setPreferredArrowDirection:");
    report(side, "arrow-default", [NSString stringWithFormat:@"%ld", (long)((IntFn)[withNumber methodForSelector:arrowGet])(withNumber, arrowGet)]);
    ((SetIntFn)[withNumber methodForSelector:arrowSet])(withNumber, arrowSet, UIEditMenuArrowDirectionUp);
    report(side, "arrow-after-set-up", [NSString stringWithFormat:@"%ld", (long)((IntFn)[withNumber methodForSelector:arrowGet])(withNumber, arrowGet)]);

    SEL initSel = NSSelectorFromString(@"init");
    id allocated = [cls alloc];
    id bare = ((AllocFn)[allocated methodForSelector:initSel])(allocated, initSel);
    report(side, "init-identifier-nil", [bare identifier] ? @"no" : @"yes");
    report(side, "init-arrow-default", [NSString stringWithFormat:@"%ld", (long)((IntFn)[bare methodForSelector:arrowGet])(bare, arrowGet)]);
    report(side, "init-sourcePoint-zero", CGPointEqualToPoint(((PointFn)[bare methodForSelector:@selector(sourcePoint)])(bare, @selector(sourcePoint)), CGPointZero) ? @"yes" : @"no");

    report(side, "superclass", NSStringFromClass([cls superclass]));
    report(side, "conforms-NSCopying", [cls conformsToProtocol:@protocol(NSCopying)] ? @"yes" : @"no");
    report(side, "instances-respond-setIdentifier", [cls instancesRespondToSelector:NSSelectorFromString(@"setIdentifier:")] ? @"yes" : @"no");
    report(side, "instances-respond-setSourcePoint", [cls instancesRespondToSelector:NSSelectorFromString(@"setSourcePoint:")] ? @"yes" : @"no");
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run_side("host", NSClassFromString(@"UIEditMenuConfiguration"));
        run_side("port", [UIEditMenuConfiguration class]);
    }
    return 0;
}

#import "RevenantBrailleMap.h"
#import <objc/runtime.h>

static void say(NSString *label, id value)
{
    printf("%s\t%s\n", label.UTF8String, [value description].UTF8String);
}

static void num(NSString *label, double value)
{
    printf("%s\t%g\n", label.UTF8String, value);
}

static int failures = 0;

static void expect(NSString *rule, id got, id want)
{
    BOOL same = (got == want) || [got isEqual:want];
    NSString *value = same ? [want description]
                           : [NSString stringWithFormat:@"got %@ wanted %@", got, want];
    printf("check\t%s\t%s\t%s\n", rule.UTF8String, same ? "ok" : "FAILED", value.UTF8String);
    if (!same) failures++;
}

int main(void)
{
    @autoreleasepool {
        Class mapClass = NSClassFromString(@"RevenantPortAXBrailleMap");
        say(@"class.present", NSStringFromClass(mapClass));
        printf("class.respondsToFactory\t%d\n",
               [mapClass respondsToSelector:@selector(revenant_mapWithDimensions:)]);

        AXBrailleMap *sized = [AXBrailleMap revenant_mapWithDimensions:CGSizeMake(3, 2)];
        say(@"sized.dimensions", NSStringFromSize([sized dimensions]));
        num(@"sized.height(0,0).before", [sized heightAtPoint:CGPointMake(0, 0)]);
        for (int column = 0; column < 3; column++) {
            for (int row = 0; row < 2; row++) {
                float raised = (float)(column * 2 + row) / 10.0f;
                [sized setHeight:raised atPoint:CGPointMake(column, row)];
            }
        }
        float sum = 0.0f;
        for (int column = 0; column < 3; column++) {
            for (int row = 0; row < 2; row++) {
                sum += [sized heightAtPoint:CGPointMake(column, row)];
            }
        }
        say(@"sized.sumOfEveryPin", @(sum));
        expect(@"the map is the size it was handed", NSStringFromSize([sized dimensions]), @"{3, 2}");
        expect(@"every pin of the grid is raised to what was written", @(sum), @(1.5));
        expect(@"a pin outside the grid reads lowered", @([sized heightAtPoint:CGPointMake(3, 0)]), @(0.0f));
        AXBrailleMap *sizedCopy = [sized copy];
        expect(@"a copy is the size of what it copies", NSStringFromSize([sizedCopy dimensions]), @"{3, 2}");
        expect(@"a copy carries the pins", @([sizedCopy heightAtPoint:CGPointMake(1, 1)]), @(0.3f));
        expect(@"a copy is its own map", @([sizedCopy heightAtPoint:CGPointMake(0, 0)]),
               @([sized heightAtPoint:CGPointMake(0, 0)]));
        num(@"sized.height(2,1)", [sized heightAtPoint:CGPointMake(2, 1)]);
        num(@"sized.height(3,0).outside", [sized heightAtPoint:CGPointMake(3, 0)]);

        AXBrailleMap *other = [AXBrailleMap revenant_mapWithDimensions:CGSizeMake(1, 1)];
        say(@"other.dimensions", NSStringFromSize([other dimensions]));
        num(@"other.height(0,0)", [other heightAtPoint:CGPointMake(0, 0)]);
        [other setHeight:0.75f atPoint:CGPointMake(0, 0)];
        num(@"other.height(0,0).afterWrite", [other heightAtPoint:CGPointMake(0, 0)]);
        num(@"sized.height(0,0).afterOtherWrite", [sized heightAtPoint:CGPointMake(0, 0)]);

        AXBrailleMap *zero = [AXBrailleMap revenant_mapWithDimensions:CGSizeZero];
        say(@"zero.dimensions", NSStringFromSize([zero dimensions]));
        [zero setHeight:1.0f atPoint:CGPointMake(0, 0)];
        num(@"zero.height(0,0)", [zero heightAtPoint:CGPointMake(0, 0)]);
        expect(@"a zero-sized map still keeps a pin", @([zero heightAtPoint:CGPointMake(0, 0)]), @(1.0f));

        NSError *archiveError = nil;
        NSData *sizedArchive = [NSKeyedArchiver archivedDataWithRootObject:sized requiringSecureCoding:YES
                                                                   error:&archiveError];
        expect(@"a sized map archives without an error", archiveError == nil ? @"ok" : @"error", @"ok");
        AXBrailleMap *sizedBack = [NSKeyedUnarchiver unarchivedObjectOfClass:[AXBrailleMap class]
                                                                   fromData:sizedArchive error:&archiveError];
        expect(@"the size comes back through an archive", NSStringFromSize([sizedBack dimensions]), @"{3, 2}");
        float archivedSum = 0.0f;
        for (int column = 0; column < 3; column++) {
            for (int row = 0; row < 2; row++) {
                archivedSum += [sizedBack heightAtPoint:CGPointMake(column, row)];
            }
        }
        expect(@"every pin of the sized grid comes back through an archive", @(archivedSum), @(1.5));
        expect(@"and the pin at one point of it is the one that was written",
               @([sizedBack heightAtPoint:CGPointMake(1, 1)]), @(0.3f));
        [sizedBack setHeight:0.05f atPoint:CGPointMake(0, 0)];
        expect(@"a map out of an archive takes a write, as the host's does",
               @([sizedBack heightAtPoint:CGPointMake(0, 0)]), @(0.05f));

        printf("checks run: 15, failed: %d\n", failures);
    }
    return failures == 0 ? 0 : 1;
}

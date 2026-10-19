// accessibilitymap/factory-probe - the one question about AXBrailleMap the system cannot be asked.
//
// The header marks -init and +new unavailable and gives no other way to make a map, so nothing but a
// braille display service ever holds one and there is no braille service on any release the port
// carries. The port therefore adds `+charon_mapWithDimensions:`, Charon's own spelling, and this checks
// it: the map comes back with the size it was handed, its pins are its own, and two sized maps do not
// share a grid.
//
// It builds the port's class alone, with no Accessibility framework linked, because the system has no
// counterpart to compare against - and a check that compared it against something that does not exist
// would be a check of nothing.


// The port's own header, and nothing else: it brings the SDK's Accessibility umbrella with it, and a
// program that imported that umbrella as well would have two declarations of the three braille classes
// CharonAccessibility.h transcribes, which clang rejects by name. The factory is called through the
// class name rather than through a Class variable, because a category method is not visible through one.
#import "CharonBrailleMap.h"
#import <objc/runtime.h>

static void say(NSString *label, id value)
{
    printf("%s\t%s\n", label.UTF8String, [value description].UTF8String);
}

static void num(NSString *label, double value)
{
    printf("%s\t%g\n", label.UTF8String, value);
}

// An assertion, and not a line of output. The first version of this probe printed what the factory
// answered and asserted nothing, so a factory that answered the wrong size passed it - a mutant of the
// factory's size survives a probe that only prints, and printing is not checking. Each check below
// names the rule it holds and fails with the value it got, so a failure says which rule broke.
static int failures = 0;

static void expect(NSString *rule, id got, id want)
{
    BOOL same = (got == want) || [got isEqual:want];
    NSString *value = same ? [want description]
                           : [NSString stringWithFormat:@"got %@ wanted %@", got, want];
    printf("check\t%s\t%s\t%s\n", rule.UTF8String, same ? "ok" : "FAILED", value.UTF8String);
    if (!same) failures++;
}

// The renderer protocol is NOT checked here, and the two halves could not be compared anyway: the
// port's copy of the protocol is not in its own image's protocol list. What is measured is this:
// `nm` on the built library finds __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_ and the two property lists
// for CharonPortAXBrailleMapRenderer, so the metadata is emitted; `objc_getProtocol` and
// NSProtocolFromString both answer nil for the name, while the same call on the host answers the
// framework's own protocol. The registry row for the protocol is therefore `absent` with that
// measurement as its reason, and the two members it names are `absent` for the same one. Establishing
// why an emitted protocol is not in the protolist is the next piece of work on this group, and it is
// the one thing in the group this series does not resolve.
int main(void)
{
    @autoreleasepool {
        Class mapClass = NSClassFromString(@"CharonPortAXBrailleMap");
        say(@"class.present", NSStringFromClass(mapClass));
        printf("class.respondsToFactory\t%d\n",
               [mapClass respondsToSelector:@selector(charon_mapWithDimensions:)]);

        AXBrailleMap *sized = [AXBrailleMap charon_mapWithDimensions:CGSizeMake(3, 2)];
        say(@"sized.dimensions", NSStringFromSize([sized dimensions]));
        num(@"sized.height(0,0).before", [sized heightAtPoint:CGPointMake(0, 0)]);
        for (int column = 0; column < 3; column++) {
            for (int row = 0; row < 2; row++) {
                float raised = (float)(column * 2 + row) / 10.0f;
                [sized setHeight:raised atPoint:CGPointMake(column, row)];
            }
        }
        // Every pin of a 3x2 grid, read back one by one: the whole point of a braille map.
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
        // A copy of a *sized* map, which the two-sided case cannot ask about at all: the system has no
        // way to make a sized map, so this is the only place the copy's size is held by anything.
        AXBrailleMap *sizedCopy = [sized copy];
        expect(@"a copy is the size of what it copies", NSStringFromSize([sizedCopy dimensions]), @"{3, 2}");
        expect(@"a copy carries the pins", @([sizedCopy heightAtPoint:CGPointMake(1, 1)]), @(0.3f));
        expect(@"a copy is its own map", @([sizedCopy heightAtPoint:CGPointMake(0, 0)]),
               @([sized heightAtPoint:CGPointMake(0, 0)]));
        num(@"sized.height(2,1)", [sized heightAtPoint:CGPointMake(2, 1)]);
        num(@"sized.height(3,0).outside", [sized heightAtPoint:CGPointMake(3, 0)]);

        AXBrailleMap *other = [AXBrailleMap charon_mapWithDimensions:CGSizeMake(1, 1)];
        say(@"other.dimensions", NSStringFromSize([other dimensions]));
        num(@"other.height(0,0)", [other heightAtPoint:CGPointMake(0, 0)]);
        [other setHeight:0.75f atPoint:CGPointMake(0, 0)];
        num(@"other.height(0,0).afterWrite", [other heightAtPoint:CGPointMake(0, 0)]);
        num(@"sized.height(0,0).afterOtherWrite", [sized heightAtPoint:CGPointMake(0, 0)]);

        AXBrailleMap *zero = [AXBrailleMap charon_mapWithDimensions:CGSizeZero];
        say(@"zero.dimensions", NSStringFromSize([zero dimensions]));
        [zero setHeight:1.0f atPoint:CGPointMake(0, 0)];
        num(@"zero.height(0,0)", [zero heightAtPoint:CGPointMake(0, 0)]);
        expect(@"a zero-sized map still keeps a pin", @([zero heightAtPoint:CGPointMake(0, 0)]), @(1.0f));

        // A SIZED map through an archive. Nothing checks this and the system's half cannot: it has no
        // way to make a map with a size, so every case about a sized map is port-only, and the archive
        // of one was one of the two things that fell through - the unarchive of a zero-sized map is in
        // cases.m, and this is the sized one. Both halves of it: the size has to come back and so has
        // every pin, because a store that kept the pins and lost the size would answer 0 for the first
        // grid column and nothing else would notice.
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
        // And a write to what came out of the archive, because the host's unarchived store is writable -
        // measured, and the first version of this class's comment said otherwise.
        [sizedBack setHeight:0.05f atPoint:CGPointMake(0, 0)];
        expect(@"a map out of an archive takes a write, as the host's does",
               @([sizedBack heightAtPoint:CGPointMake(0, 0)]), @(0.05f));

        printf("checks run: 15, failed: %d\n", failures);
    }
    return failures == 0 ? 0 : 1;
}

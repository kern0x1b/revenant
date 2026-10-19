// accessibilitymap - AXBrailleMap against the host's own.
//
// One source, two programs. The host half links the system's Accessibility.framework; the port half is
// built with the class name remapped to a name the system does not use and links no Accessibility
// framework, so its class is the port's own. Each prints "label<TAB>value" per case in the same order
// and run.sh compares the two outputs line by line.
//
// The map comes from NSClassFromString and alloc on both sides, and that is not a dodge: the header
// marks -init and +new unavailable, so a program that compiled `[[AXBrailleMap alloc] init]` would not
// build, and the system has no public way to make one at all. The host half's map is the one its own
// braille service would have made, which is exactly the object the port's zero-sized fresh map has to
// answer like - measured, and the two answers are the same for every case here.
//
// What is NOT in this file: anything about the size a map is made with. The system has no way to make
// a sized map, so the only question about a size - that the port's own factory gives the map the size it
// is handed - is asked in factory-probe.m, which builds the port half alone. And nothing about what
// presentImage: shows, because a program cannot read a display.

#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

static void say(NSString *label, id value)
{
    NSString *text = [value description] ?: @"(nil)";
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    printf("%s\t%s\n", label.UTF8String, text.UTF8String);
}

static void num(NSString *label, double value)
{
    printf("%s\t%g\n", label.UTF8String, value);
}

// The port's class is named CharonPortAXBrailleMap under -D, so the looked-up name is a macro and the
// printed name has the marker taken off the front: the two halves are the same class under two names.
#ifndef AXBRAILLEMAP_CLASS
#define AXBRAILLEMAP_CLASS @"AXBrailleMap"
#endif
#ifndef AXBRAILLEMAP_RENDERER_PROTOCOL
#define AXBRAILLEMAP_RENDERER_PROTOCOL @"AXBrailleMapRenderer"
#endif

static NSString *name(NSString *spelling)
{
    if (spelling.length > [@"CharonPort" length] &&
        [[spelling substringToIndex:[@"CharonPort" length]] isEqualToString:@"CharonPort"]) {
        return [spelling substringFromIndex:[@"CharonPort" length]];
    }
    return spelling;
}

static void sayClass(NSString *label, Class value)
{
    say(label, name(NSStringFromClass(value)));
}

int main(void)
{
    @autoreleasepool {
        Class mapClass = NSClassFromString(AXBRAILLEMAP_CLASS);
        say(@"class.present", name(NSStringFromClass(mapClass)));
        say(@"class.superclass", [NSStringFromClass([mapClass superclass]) copy]);
        printf("class.instancesRespondsToSetHeightAtPoint\t%d\n",
               [mapClass instancesRespondToSelector:@selector(setHeight:atPoint:)]);
        printf("class.instancesRespondsToHeightAtPoint\t%d\n",
               [mapClass instancesRespondToSelector:@selector(heightAtPoint:)]);
        printf("class.instancesRespondsToDimensions\t%d\n",
               [mapClass instancesRespondToSelector:@selector(dimensions)]);
        printf("class.instancesRespondsToPresentImage\t%d\n",
               [mapClass instancesRespondToSelector:@selector(presentImage:)]);

        id map = [mapClass alloc];
        say(@"fresh.dimensions", NSStringFromSize([map dimensions]));
        num(@"fresh.height(0,0)", [map heightAtPoint:CGPointMake(0, 0)]);

        // A pin written to a map nothing has sized still reads back: the store is real before a size is.
        [map setHeight:1.0f atPoint:CGPointMake(0, 0)];
        num(@"set.height(0,0)", [map heightAtPoint:CGPointMake(0, 0)]);
        [map setHeight:0.5f atPoint:CGPointMake(3, 4)];
        num(@"set.height(3,4)", [map heightAtPoint:CGPointMake(3, 4)]);
        num(@"set.height(1,1).untouched", [map heightAtPoint:CGPointMake(1, 1)]);

        // No range check and no bounds check, measured on the host and held here: 2.0 stays 2.0, -1.0
        // stays -1.0, a fraction stays a fraction, and a negative point takes one.
        [map setHeight:2.0f atPoint:CGPointMake(5, 5)];
        num(@"outOfRange.height(5,5)", [map heightAtPoint:CGPointMake(5, 5)]);
        [map setHeight:-1.0f atPoint:CGPointMake(6, 6)];
        num(@"belowZero.height(6,6)", [map heightAtPoint:CGPointMake(6, 6)]);
        [map setHeight:0.25f atPoint:CGPointMake(7, 7)];
        num(@"fraction.height(7,7)", [map heightAtPoint:CGPointMake(7, 7)]);
        [map setHeight:1.0f atPoint:CGPointMake(7, 7)];
        num(@"raised.height(7,7)", [map heightAtPoint:CGPointMake(7, 7)]);
        [map setHeight:0.0f atPoint:CGPointMake(7, 7)];
        num(@"lowered.height(7,7)", [map heightAtPoint:CGPointMake(7, 7)]);
        [map setHeight:0.75f atPoint:CGPointMake(-2, -3)];
        num(@"negativePoint.height(-2,-3)", [map heightAtPoint:CGPointMake(-2, -3)]);
        num(@"farPoint.height(1e9,1e9)", [map heightAtPoint:CGPointMake(1e9, 1e9)]);

        // Two maps are two maps, measured: a pin written to one is not in the other.
        id other = [mapClass alloc];
        num(@"other.height(3,4)", [other heightAtPoint:CGPointMake(3, 4)]);
        say(@"other.dimensions", NSStringFromSize([other dimensions]));
        [other setHeight:0.125f atPoint:CGPointMake(3, 4)];
        num(@"other.height(3,4).afterWrite", [other heightAtPoint:CGPointMake(3, 4)]);
        num(@"first.height(3,4).afterOtherWrite", [map heightAtPoint:CGPointMake(3, 4)]);

        // The copy and the archive, the two members the header's protocol list names and the two the
        // pin rules depend on. A write to a copy is asked inside a @try on purpose: the host raises
        // there, and a case that let the program die would not have an answer to compare.
        [map setHeight:0.5f atPoint:CGPointMake(1, 2)];
        [map setHeight:1.0f atPoint:CGPointMake(3, 4)];
        say(@"before.dimensions", NSStringFromSize([map dimensions]));
        printf("class.supportsSecureCoding\t%d\n", [mapClass supportsSecureCoding] ? 1 : 0);
        printf("class.respondsToCopyWithZone\t%d\n", [mapClass instancesRespondToSelector:@selector(copyWithZone:)] ? 1 : 0);
        id copied = [map copy];
        sayClass(@"copy.class", [copied class]);
        say(@"copy.dimensions", NSStringFromSize([copied dimensions]));
        num(@"copy.height(1,2)", [copied heightAtPoint:CGPointMake(1, 2)]);
        num(@"copy.height(3,4)", [copied heightAtPoint:CGPointMake(3, 4)]);
        num(@"copy.height(0,0)", [copied heightAtPoint:CGPointMake(0, 0)]);
        // The two maps are their own: a write to the original leaves the copy answering what it answered.
        [map setHeight:0.125f atPoint:CGPointMake(5, 6)];
        num(@"copy.height(5,6).afterOriginalWrite", [copied heightAtPoint:CGPointMake(5, 6)]);
        num(@"map.height(5,6)", [map heightAtPoint:CGPointMake(5, 6)]);
        // And the one place the two differ: a write to a copy. The host raises, and the case records
        // which, so the difference is a value in the output and not a program that died.
        NSString *copyWrite = @"accepted";
        @try {
            [copied setHeight:0.25f atPoint:CGPointMake(1, 2)];
        } @catch (NSException *raised) {
            copyWrite = [NSString stringWithFormat:@"raised %@", [raised name]];
        }
        say(@"copy.write", copyWrite);
        // Printed after the @try on both sides, so the line exists whichever way the write went: a
        // label that only one side prints is a difference in the output, not in the behaviour.
        num(@"copy.height(1,2).afterWriteAttempt", [copied heightAtPoint:CGPointMake(1, 2)]);
        num(@"map.height(1,2).afterCopyWrite", [map heightAtPoint:CGPointMake(1, 2)]);

        // The archive, over a map with pins and over an empty one: the size and every pin come back.
        NSError *archiveError = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:map requiringSecureCoding:YES
                                                                error:&archiveError];
        say(@"archive.error", archiveError ? [archiveError description] : @"(none)");
        say(@"archive.hasData", archive ? @"yes" : @"no");
        if (archive) {
            id back = [NSKeyedUnarchiver unarchivedObjectOfClass:mapClass fromData:archive error:&archiveError];
            say(@"unarchive.error", archiveError ? [archiveError description] : @"(none)");
            sayClass(@"unarchive.class", [back class]);
            say(@"unarchive.dimensions", NSStringFromSize([back dimensions]));
            num(@"unarchive.height(1,2)", [back heightAtPoint:CGPointMake(1, 2)]);
            num(@"unarchive.height(3,4)", [back heightAtPoint:CGPointMake(3, 4)]);
            num(@"unarchive.height(0,0)", [back heightAtPoint:CGPointMake(0, 0)]);
            id empty = [mapClass alloc];
            NSData *emptyArchive = [NSKeyedArchiver archivedDataWithRootObject:empty requiringSecureCoding:YES
                                                                          error:&archiveError];
            id emptyBack = [NSKeyedUnarchiver unarchivedObjectOfClass:mapClass fromData:emptyArchive
                                                                  error:&archiveError];
            say(@"unarchive.empty.dimensions", NSStringFromSize([emptyBack dimensions]));
            num(@"unarchive.empty.height(0,0)", [emptyBack heightAtPoint:CGPointMake(0, 0)]);
        }

        // The map does not adopt the renderer protocol, and a class that claimed it would be claiming
        // something the system's own class does not: the renderer protocol is something an *element*
        // adopts. The two-sided comparison of the protocol's NAME is not here and is not coming here
        // while the alias renames the protocol with the class; protocol-check.sh asks it on the port
        // alone, against the registry's own rows, and the reason and the three ways it could be done
        // are in this directory's README.md under Owed.
        printf("map.conformsToRenderer\t%d\n",
               [mapClass conformsToProtocol:@protocol(AXBrailleMapRenderer)]);

        // The archive, and then a write to what came back. The second half is the assertion that matters:
        // the first version of this case only read the unarchived map, and the port's unarchived store
        // was frozen while the host's is not - measured, and a difference the case could not have seen
        // because it never wrote to either. The host's answers, on this build:
        //   before  the host's unarchived store: (1,2)=0.5
        //   write   the host's unarchived store took a write: (1,2)=0.9
        id roundTrip = [NSKeyedUnarchiver unarchivedObjectOfClass:mapClass fromData:archive error:&archiveError];
        say(@"unarchive.write.error", archiveError ? [archiveError description] : @"(none)");
        num(@"unarchive.height(1,2).beforeWrite", [roundTrip heightAtPoint:CGPointMake(1, 2)]);
        NSString *unarchivedWrite = @"accepted";
        @try {
            [roundTrip setHeight:0.9f atPoint:CGPointMake(1, 2)];
        } @catch (NSException *raised) {
            unarchivedWrite = [NSString stringWithFormat:@"raised %@", [raised name]];
        }
        say(@"unarchive.write", unarchivedWrite);
        num(@"unarchive.height(1,2).afterWrite", [roundTrip heightAtPoint:CGPointMake(1, 2)]);

        // The image: a real one, so the call is a call and not a null. What comes back from it is not
        // read, because there is nothing on either side a program can read back.
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL, 2, 2, 8, 0, space,
                                                     (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGImageRef image = CGBitmapContextCreateImage(context);
        [map presentImage:image];
        say(@"presentImage.survived", @"yes");
        printf("presentImage.isVoid\t%d\n", class_getInstanceMethod(mapClass, @selector(presentImage:)) ? 1 : 0);
        CGImageRelease(image);
        CGContextRelease(context);
        CGColorSpaceRelease(space);
    }
    return 0;
}

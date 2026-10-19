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

#ifndef AXBRAILLEMAP_CLASS
#define AXBRAILLEMAP_CLASS @"AXBrailleMap"
#endif
#ifndef AXBRAILLEMAP_RENDERER_PROTOCOL
#define AXBRAILLEMAP_RENDERER_PROTOCOL @"AXBrailleMapRenderer"
#endif

static NSString *name(NSString *spelling)
{
    if (spelling.length > [@"RevenantPort" length] &&
        [[spelling substringToIndex:[@"RevenantPort" length]] isEqualToString:@"RevenantPort"]) {
        return [spelling substringFromIndex:[@"RevenantPort" length]];
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

        [map setHeight:1.0f atPoint:CGPointMake(0, 0)];
        num(@"set.height(0,0)", [map heightAtPoint:CGPointMake(0, 0)]);
        [map setHeight:0.5f atPoint:CGPointMake(3, 4)];
        num(@"set.height(3,4)", [map heightAtPoint:CGPointMake(3, 4)]);
        num(@"set.height(1,1).untouched", [map heightAtPoint:CGPointMake(1, 1)]);

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

        id other = [mapClass alloc];
        num(@"other.height(3,4)", [other heightAtPoint:CGPointMake(3, 4)]);
        say(@"other.dimensions", NSStringFromSize([other dimensions]));
        [other setHeight:0.125f atPoint:CGPointMake(3, 4)];
        num(@"other.height(3,4).afterWrite", [other heightAtPoint:CGPointMake(3, 4)]);
        num(@"first.height(3,4).afterOtherWrite", [map heightAtPoint:CGPointMake(3, 4)]);

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
        [map setHeight:0.125f atPoint:CGPointMake(5, 6)];
        num(@"copy.height(5,6).afterOriginalWrite", [copied heightAtPoint:CGPointMake(5, 6)]);
        num(@"map.height(5,6)", [map heightAtPoint:CGPointMake(5, 6)]);
        NSString *copyWrite = @"accepted";
        @try {
            [copied setHeight:0.25f atPoint:CGPointMake(1, 2)];
        } @catch (NSException *raised) {
            copyWrite = [NSString stringWithFormat:@"raised %@", [raised name]];
        }
        say(@"copy.write", copyWrite);
        num(@"copy.height(1,2).afterWriteAttempt", [copied heightAtPoint:CGPointMake(1, 2)]);
        num(@"map.height(1,2).afterCopyWrite", [map heightAtPoint:CGPointMake(1, 2)]);

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

        printf("map.conformsToRenderer\t%d\n",
               [mapClass conformsToProtocol:@protocol(AXBrailleMapRenderer)]);

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

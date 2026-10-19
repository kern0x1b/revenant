// The port's CIFilter convenience constructors beside the host's own, in one process.
//
// Every zero-argument class method the port's objects added to CIFilter is called under both names:
// the host's, and the port's prefixed one.  What the two answer is compared field by field - the
// class, the name, the input keys, the output keys and the whole attribute dictionary - and where the
// filter's only declared input is an image, the two are rendered over a fixed window and the bytes
// compared too.  The list of methods is read from the runtime, so nothing here names one by hand.
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const PREFIX = @"charonHost_";
#define WINDOW_W 32
#define WINDOW_H 32

typedef id (*CharonMsgSend0)(id, SEL);

// prefix_selectors.py keeps the spelling of a keyword whose first half is one of the five families
// an Objective-C method is copied under, gluing the prefix to the second half instead
// (copyMachineTransitionFilter -> copyCharonHostMachineTransitionFilter), so a prefixed selector is
// put back to the port's own name by both spellings.
static NSString *unprefixed(const char *keyword)
{
    if (strncmp(keyword, "charonHost_", 11) == 0) return [NSString stringWithUTF8String:keyword + 11];
    for (NSString *family in @[@"mutableCopy", @"copy", @"init", @"new", @"alloc"]) {
        if (!strncmp(keyword, family.UTF8String, family.length)) {
            const char *rest = keyword + family.length;
            if (strncmp(rest, "CharonHost", 10) == 0 && rest[10] >= 'A' && rest[10] <= 'Z')
                return [NSString stringWithFormat:@"%@%s", family, rest + 10];
        }
    }
    return nil;
}

// The other direction: the name the port's method is under, by the tool's own rule.
static NSString *prefixed(NSString *keyword)
{
    for (NSString *family in @[@"mutableCopy", @"copy", @"init", @"new", @"alloc"]) {
        if ([keyword hasPrefix:family]) {
            NSString *rest = [keyword substringFromIndex:family.length];
            if (!rest.length || (rest.length && [rest characterAtIndex:0] >= 'A' && [rest characterAtIndex:0] <= 'Z'))
                return [NSString stringWithFormat:@"%@CharonHost%@", family, rest];
        }
    }
    return [PREFIX stringByAppendingString:keyword];
}

static CIContext *context;
static long compared, rendered, different, missing;

static NSData *bytes_of(CIImage *image)
{
    if (!image) return nil;
    size_t width = WINDOW_W, height = WINDOW_H;
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    [context render:image toBitmap:data.mutableBytes rowBytes:width * 4 bounds:CGRectMake(0, 0, width, height)
             format:kCIFormatRGBA8 colorSpace:space];
    CGColorSpaceRelease(space);
    return data;
}

static void tell(NSString *what)
{
    if (different++ < 40) printf("different: %s\n", what.UTF8String);
}

static CIVector *rect_vector(void);
static CIQRCodeDescriptor *any_qr_descriptor(void);

// The values an input whose own default is nil can be given, most preferred first.  What the input is comes
// from the filter's own declaration of it - CIAttributeType, and where that is absent the CIAttributeClass,
// CIAttributeMax and CIAttributeMin the attribute dictionary carries - and not from this file's guess.  The
// values are named here rather than hidden, and the same one is given to both sides of every comparison, so
// which value it is cannot decide the result: the claim under test is that the port's constructor is the
// host's filter.
static NSArray *supplied_values(NSDictionary *attribute, NSString *key, CIImage *input, CIImage *cube)
{
    if (![attribute isKindOfClass:[NSDictionary class]]) return nil;
    NSString *type = attribute[@"CIAttributeType"];
    NSString *klass = attribute[@"CIAttributeClass"];
    if ([type isEqualToString:@"CIAttributeTypeImage"] || [klass isEqualToString:@"CIImage"]) {
        // A colour map is a cube, and the host's own CIColorCube filter makes one at its own default
        // dimension; a flat image is not a cube and CIColorMap answers a nil image for one.
        if ([key rangeOfString:@"Cube" options:NSCaseInsensitiveSearch].location != NSNotFound) return @[cube];
        return @[input];
    }
    if ([klass isEqualToString:@"NSAttributedString"]) return @[[[NSAttributedString alloc] initWithString:@"charon"]];
    if ([klass isEqualToString:@"NSString"]) return @[@"charon"];
    if ([klass isEqualToString:@"NSData"]) return @[[@"charon" dataUsingEncoding:NSUTF8StringEncoding]];
    if ([klass isEqualToString:@"NSNumber"] || [type isEqualToString:@"CIAttributeTypeScalar"] ||
        [type isEqualToString:@"CIAttributeTypeFloat"] || [type isEqualToString:@"CIAttributeTypeInteger"]) {
        // A number's candidates are the range Apple's own attribute dictionary declares, largest first, and
        // then 1 where it declares no range: which end a filter accepts is its own answer, not this file's.
        NSMutableArray *numbers = [NSMutableArray array];
        NSNumber *low = attribute[@"CIAttributeMin"] ?: attribute[@"CIAttributeSliderMin"];
        NSNumber *high = attribute[@"CIAttributeMax"] ?: attribute[@"CIAttributeSliderMax"];
        if (high) [numbers addObject:high];
        if (low) [numbers addObject:low];
        if (low && high) [numbers addObject:@(([low doubleValue] + [high doubleValue]) / 2.0)];
        [numbers addObject:@1];
        return numbers;
    }
    // A rectangle is declared as a CIVector, and its default is "[0 0 0 0]" - an empty region, over which
    // an area histogram answers a nil image.  The region is the synthetic image's own extent.
    if ([type isEqualToString:@"CIAttributeTypeRectangle"]) return @[rect_vector()];
    // A barcode descriptor is a class of the framework's own and has no default; the host is asked which
    // QR code descriptor it accepts, over the values the header's own ranges allow, and the first one it
    // answers is the value used.  Nothing here decides what the symbol is.
    if ([klass isEqualToString:@"CIBarcodeDescriptor"]) {
        CIQRCodeDescriptor *descriptor = any_qr_descriptor();
        return descriptor ? @[descriptor] : nil;
    }
    return nil;
}

// A CIVector holding a CGRect, the shape CIFilter declares a rectangle input in.
static CIVector *rect_vector(void)
{
    CGRect extent = CGRectMake(0, 0, WINDOW_W, WINDOW_H);
    return [CIVector vectorWithX:extent.origin.x Y:extent.origin.y Z:extent.size.width W:extent.size.height];
}

// The first QR code descriptor the host accepts, over the header's own ranges: symbolVersion 1 to 40,
// maskPattern 0 to 7, errorCorrectionLevel low, medium, quartile and high.
static CIQRCodeDescriptor *any_qr_descriptor(void)
{
    static CIQRCodeDescriptor *descriptor;
    if (descriptor) return descriptor;
    NSData *payload = [@"charon" dataUsingEncoding:NSUTF8StringEncoding];
    for (NSInteger version = 1; version <= 40 && !descriptor; version++)
        for (NSUInteger mask = 0; mask <= 7 && !descriptor; mask++)
            for (NSUInteger level = 0; level <= 3 && !descriptor; level++)
                descriptor = [CIQRCodeDescriptor descriptorWithPayload:payload symbolVersion:version
                                                           maskPattern:mask errorCorrectionLevel:level];
    return descriptor;
}

static void same_dictionary(NSDictionary *a, NSDictionary *b, NSString *what)
{
    compared++;
    if (a.count != b.count) {
        tell([NSString stringWithFormat:@"%@ count %lu vs %lu", what, (unsigned long)a.count, (unsigned long)b.count]);
        return;
    }
    for (id key in a) {
        id x = a[key], y = b[key];
        BOOL equal;
        if ([x isKindOfClass:[NSArray class]] && [y isKindOfClass:[NSArray class]]) {
            equal = [(NSArray *)x isEqualToArray:y];
        } else if ([x isKindOfClass:[NSData class]] && [y isKindOfClass:[NSData class]]) {
            equal = [(NSData *)x isEqualToData:y];
        } else {
            equal = [x isEqual:y];
        }
        if (!equal) {
            tell([NSString stringWithFormat:@"%@[%@] %@ vs %@", what, [key description],
                  [x description], [y description]]);
            return;
        }
    }
}

int main(void)
{
    context = [CIContext contextWithOptions:nil];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CIColor *colour = [[CIColor alloc] initWithRed:0.25 green:0.5 blue:0.75 alpha:1];
    CIImage *input = [[CIImage imageWithColor:colour] imageByCroppingToRect:CGRectMake(0, 0, 16, 12)];
    CGColorSpaceRelease(space);

    // The host's own colour cube, built by the host's own CIColorCube filter at its own default dimension.
    CIImage *cube = [CIFilter filterWithName:@"CIColorCube"].outputImage;

    Class metaclass = object_getClass([CIFilter class]);
    unsigned count = 0;
    Method *methods = class_copyMethodList(metaclass, &count);
    NSMutableArray *ported = [NSMutableArray array];
    for (unsigned i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);
        const char *keyword = sel_getName(sel);
        if (!types || types[0] != '@') continue;
        if (strchr(keyword, ':')) continue;
        NSString *own = unprefixed(keyword);
        if (!own) continue;
        [ported addObject:own];
    }
    free(methods);

    for (NSString *selector in ported) {
        SEL host = NSSelectorFromString(selector);
        SEL own = NSSelectorFromString(prefixed(selector));
        if (![CIFilter respondsToSelector:host]) {
            tell([NSString stringWithFormat:@"the host has no +%@, so there is nothing to compare against", selector]);
            continue;
        }
        CIFilter *theirs = ((CharonMsgSend0)objc_msgSend)((id)[CIFilter class], host);
        CIFilter *ours = ((CharonMsgSend0)objc_msgSend)((id)[CIFilter class], own);
        compared++;
        if (ours != theirs && ![ours.name isEqualToString:theirs.name]) {
            tell([NSString stringWithFormat:@"+%@ answers %@ where the host answers %@", selector,
                  ours ? ours.name : @"nil", theirs ? theirs.name : @"nil"]);
            continue;
        }
        if (object_getClass(ours) != object_getClass(theirs)) {
            tell([NSString stringWithFormat:@"+%@ class %s vs %s", selector,
                  class_getName(object_getClass(ours)), class_getName(object_getClass(theirs))]);
        }
        if (![ours.name isEqualToString:theirs.name]) {
            tell([NSString stringWithFormat:@"+%@ name %@ vs %@", selector, ours.name, theirs.name]);
        }
        if (![ours.inputKeys isEqualToArray:theirs.inputKeys]) tell([NSString stringWithFormat:@"+%@ inputKeys", selector]);
        if (![ours.outputKeys isEqualToArray:theirs.outputKeys]) tell([NSString stringWithFormat:@"+%@ outputKeys", selector]);
        same_dictionary(ours.attributes, theirs.attributes, [NSString stringWithFormat:@"+%@ attributes", selector]);

        // Every declared input is given the value a FRESH filter of that name already answers for it, which
        // is Apple's own default and not a value this file chose.  The defaults are read before anything is
        // set, because setting one changes it.
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        NSMutableDictionary *ranges = [NSMutableDictionary dictionary];
        for (NSString *key in theirs.inputKeys) {
            NSDictionary *attribute = theirs.attributes[key];
            @try {
                id value = [theirs valueForKey:key];
                // A rectangle's default is "[0 0 0 0]", which is not a region any filter will work over.
                if (value && ![[attribute[@"CIAttributeType"] description] isEqualToString:@"CIAttributeTypeRectangle"])
                    values[key] = value;
            } @catch (NSException *e) {
            }
            if (values[key]) continue;
            // An input whose own default is nil is given a value of the input's DECLARED type, taken from
            // what the filter's own attribute dictionary says: its maximum, its minimum, and 1 where it names
            // no range at all.  A number has more than one such value and the filter may accept one and
            // refuse another - PDF417 at its own minimum refuses with "Unable to fit message into space
            // available!" and Aztec at its own maximum draws nothing - so the passes below take them in the
            // order Apple's own dictionary lists and stop at the first the filter itself renders with.
            NSArray *candidates = supplied_values(attribute, key, input, cube);
            if (candidates.count) {
                values[key] = candidates.firstObject;
                ranges[key] = candidates;
            }
        }
        // Both sides are given the same values on every pass, and each pass builds the filters again, so
        // what is compared on a pass is two filters of the same name with the same inputs.
        NSData *bytes[2] = {nil, nil};
        NSUInteger pass = 0;
        for (pass = 0; pass < 5; pass++) {
            CIFilter *pair[2] = {((CharonMsgSend0)objc_msgSend)((id)[CIFilter class], own),
                                 ((CharonMsgSend0)objc_msgSend)((id)[CIFilter class], host)};
            for (int i = 0; i < 2; i++) {
                for (NSString *key in pair[i].inputKeys) {
                    NSArray *candidates = ranges[key];
                    // A ranged input advances one candidate per pass and keeps its last one; a single-valued
                    // input keeps that value on every pass.
                    id value = candidates ? candidates[MIN(pass, candidates.count - 1)] : values[key];
                    if (!value) continue;
                    @try {
                        [pair[i] setValue:value forKey:key];
                    } @catch (NSException *e) {
                    }
                }
                @try {
                    bytes[i] = bytes_of(pair[i].outputImage);
                } @catch (NSException *e) {
                    bytes[i] = nil;
                }
            }
            if (bytes[0] && bytes[1]) break;
        }
        if (bytes[0] && bytes[1]) {
            rendered++;
            if (![bytes[0] isEqualToData:bytes[1]]) tell([NSString stringWithFormat:@"+%@ output bytes", selector]);
        } else if (getenv("CHARON_WHY")) {
            // Which, and why: the host itself refusing is the answer, so it is printed from the host's own
            // filter with the last pass's values, and not guessed at.  CHARON_WHY=1 asks for this line; the
            // verdict line below is the run's result either way.
            CIFilter *probe = ((CharonMsgSend0)objc_msgSend)((id)[CIFilter class], host);
            for (NSString *key in ranges) {
                NSArray *candidates = ranges[key];
                [probe setValue:candidates[MIN(pass, candidates.count - 1)] forKey:key];
            }
            for (NSString *key in values) {
                if (!ranges[key]) [probe setValue:values[key] forKey:key];
            }
            NSString *why = @"nil";
            @try {
                CIImage *out = probe.outputImage;
                why = out ? [NSString stringWithFormat:@"an image %@", NSStringFromRect(out.extent)] : @"a nil output image";
            } @catch (NSException *e) {
                why = [NSString stringWithFormat:@"%@: %@", e.name, e.reason];
            }
            NSMutableArray *set = [NSMutableArray array];
            for (NSString *key in probe.inputKeys) {
                @try { [set addObject:[NSString stringWithFormat:@"%@=%@", key, [probe valueForKey:key]]]; }
                @catch (NSException *e) { [set addObject:[NSString stringWithFormat:@"%@=!", key]]; }
            }
            printf("why +%s -> %s [%s]\n", selector.UTF8String, why.UTF8String,
                   [set componentsJoinedByString:@" "].UTF8String);
        }
    }
    if (ported.count != 239) {
        tell([NSString stringWithFormat:@"the port's objects carry %lu prefixed constructors, not 239", (unsigned long)ported.count]);
    }
    printf("compared %ld of %lu port constructors against the host's own, %ld rendered and compared, %ld different\n",
           compared, (unsigned long)ported.count, rendered, different);
    return different ? 1 : 0;
}
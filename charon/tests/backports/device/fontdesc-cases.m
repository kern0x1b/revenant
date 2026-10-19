#import "fontdesc-cases.h"

static NSString *attrs(UIFontDescriptor *d)
{
    if (!d)
        return @"nil";
    NSMutableArray *parts = [NSMutableArray array];
    NSDictionary *a = d.fontAttributes;
    for (NSString *key in [a.allKeys sortedArrayUsingSelector:@selector(compare:)])
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, a[key]]];
    return [parts componentsJoinedByString:@";"];
}

static NSString *info(UIFontDescriptor *d)
{
    if (!d)
        return @"nil";
    return [NSString stringWithFormat:@"ps=%@ size=%g traits=%x", d.postscriptName, d.pointSize, (unsigned)(d.symbolicTraits & 0x63)];
}

static NSString *font(UIFont *f)
{
    return f ? [NSString stringWithFormat:@"%@ %g", f.fontName, f.pointSize] : @"nil";
}

void fontdesc_run(UIWindow *window, FontDescRecorder record)
{
    UIFontDescriptor *helvetica = [UIFontDescriptor fontDescriptorWithName:@"Helvetica" size:14];
    record(@"name and size attributes", attrs(helvetica));
    record(@"name and size", info(helvetica));
    record(@"family", [[helvetica objectForKey:UIFontDescriptorFamilyAttribute] description]);
    record(@"name", [[helvetica objectForKey:UIFontDescriptorNameAttribute] description]);
    record(@"size", [[helvetica objectForKey:UIFontDescriptorSizeAttribute] description]);
    record(@"absent key", [[helvetica objectForKey:@"NoSuchAttribute"] description] ?: @"nil");
    for (NSNumber *traits in @[@0, @1, @2, @3, @0x40, @0x20, @0x400, @0x1000]) {
        NSString *name = [NSString stringWithFormat:@"helvetica with traits %lx", (unsigned long)traits.unsignedIntegerValue];
        UIFontDescriptor *d = [helvetica fontDescriptorWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)traits.unsignedIntValue];
        record(name, [NSString stringWithFormat:@"%@ | %@", attrs(d), info(d)]);
    }
    UIFontDescriptor *boldOblique = [helvetica fontDescriptorWithSymbolicTraits:3];
    record(@"bold oblique to bold", info([boldOblique fontDescriptorWithSymbolicTraits:2]));
    record(@"bold oblique to none", info([boldOblique fontDescriptorWithSymbolicTraits:0]));
    record(@"bold oblique to italic", info([boldOblique fontDescriptorWithSymbolicTraits:1]));
    UIFontDescriptor *courier = [UIFontDescriptor fontDescriptorWithName:@"Courier" size:12];
    record(@"courier bold", info([courier fontDescriptorWithSymbolicTraits:2]));
    record(@"courier bold oblique", info([courier fontDescriptorWithSymbolicTraits:3]));
    UIFontDescriptor *times = [UIFontDescriptor fontDescriptorWithName:@"TimesNewRomanPSMT" size:16];
    record(@"times", info(times));
    record(@"times bold", info([times fontDescriptorWithSymbolicTraits:2]));
    record(@"times italic", info([times fontDescriptorWithSymbolicTraits:1]));

    UIFontDescriptor *family = [UIFontDescriptor fontDescriptorWithFontAttributes:@{UIFontDescriptorFamilyAttribute: @"Courier"}];
    record(@"family attributes", attrs(family));
    record(@"family only", [NSString stringWithFormat:@"ps=%@ size=%g", family.postscriptName, family.pointSize]);
    record(@"family bold", info([family fontDescriptorWithSymbolicTraits:2]));
    UIFontDescriptor *matches = nil;
    NSArray *found = [family matchingFontDescriptorsWithMandatoryKeys:[NSSet setWithObject:UIFontDescriptorFamilyAttribute]];
    NSMutableArray *names = [NSMutableArray array];
    for (UIFontDescriptor *d in found)
        [names addObject:d.postscriptName ?: @"nil"];
    (void)matches;
    record(@"matching family", [[names sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]);
    record(@"matching none", [NSString stringWithFormat:@"%lu", (unsigned long)[[UIFontDescriptor fontDescriptorWithName:@"NoSuchFontZ" size:10] matchingFontDescriptorsWithMandatoryKeys:nil].count]);

    record(@"with size", attrs([helvetica fontDescriptorWithSize:20]));
    record(@"with size pointSize", [NSString stringWithFormat:@"%g", [helvetica fontDescriptorWithSize:20].pointSize]);
    record(@"with family", attrs([helvetica fontDescriptorWithFamily:@"Courier"]));
    record(@"with family ps", [helvetica fontDescriptorWithFamily:@"Courier"].postscriptName);
    record(@"with face", attrs([helvetica fontDescriptorWithFace:@"Bold"]));
    UIFontDescriptor *added = [helvetica fontDescriptorByAddingAttributes:@{UIFontDescriptorSizeAttribute: @30, UIFontDescriptorFaceAttribute: @"Oblique"}];
    record(@"adding", attrs(added));
    record(@"adding empty", attrs([helvetica fontDescriptorByAddingAttributes:@{}]));
    record(@"original untouched", attrs(helvetica));
    record(@"empty descriptor", attrs([[UIFontDescriptor alloc] initWithFontAttributes:@{}]));
    record(@"empty ps", [[UIFontDescriptor alloc] initWithFontAttributes:@{}].postscriptName ?: @"nil");
    record(@"empty size", [NSString stringWithFormat:@"%g", [[UIFontDescriptor alloc] initWithFontAttributes:@{}].pointSize]);

    UIFont *bold = [UIFont fontWithName:@"Helvetica-Bold" size:17];
    record(@"font descriptor", [NSString stringWithFormat:@"%@ | %@", attrs(bold.fontDescriptor), info(bold.fontDescriptor)]);
    record(@"font with descriptor size zero", font([UIFont fontWithDescriptor:bold.fontDescriptor size:0]));
    record(@"font with descriptor size", font([UIFont fontWithDescriptor:bold.fontDescriptor size:30]));
    record(@"font with plain descriptor", font([UIFont fontWithDescriptor:[bold.fontDescriptor fontDescriptorWithSymbolicTraits:0] size:0]));
    record(@"font with family descriptor", font([UIFont fontWithDescriptor:[family fontDescriptorWithSize:15] size:0]));
    record(@"font with courier bold", font([UIFont fontWithDescriptor:[courier fontDescriptorWithSymbolicTraits:2] size:0]));
    record(@"font with missing name", font([UIFont fontWithDescriptor:[UIFontDescriptor fontDescriptorWithName:@"NoSuchFontZ" size:11] size:0]));
    record(@"font round trip", font([UIFont fontWithDescriptor:[UIFont fontWithName:@"Courier-Bold" size:13].fontDescriptor size:0]));

    UIFontDescriptor *twin = [UIFontDescriptor fontDescriptorWithName:@"Helvetica" size:14];
    record(@"equal", [NSString stringWithFormat:@"%d %d %d", [helvetica isEqual:twin], helvetica.hash == twin.hash, [helvetica isEqual:[helvetica fontDescriptorWithSize:15]]]);
    record(@"copy is itself", [NSString stringWithFormat:@"%d", [helvetica copy] == helvetica]);
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:helvetica];
    UIFontDescriptor *back = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    record(@"archive round trip", [NSString stringWithFormat:@"%d %@", [back isEqual:helvetica], attrs(back)]);
    record(@"secure coding", [NSString stringWithFormat:@"%d", [UIFontDescriptor supportsSecureCoding]]);
    UIFontDescriptor *named = [UIFontDescriptor fontDescriptorWithFontAttributes:@{UIFontDescriptorNameAttribute: @"Helvetica-Bold"}];
    record(@"bold by name", info(named));
}

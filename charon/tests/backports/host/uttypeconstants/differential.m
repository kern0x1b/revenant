#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dlfcn.h>
#import <objc/runtime.h>

// The identifier behind each of the 129 UTType constants the port carries, against the host's own
// UniformTypeIdentifiers. The expectation is the `UTI:` line of the constant's own doc comment in
// SDK 26.2's UTCoreTypes.h (expected-identifiers.tsv, beside this file), never the port's answer:
// the host is asked what each of its constants' identifier is, and the two are compared.
//
// The two tag classes are in the same shape, and the third block asks the host the two questions
// the port's -supertypes, -version and -referenceURL answer differently: what the host says for a
// system type, and what it says for a type nobody declared.

static int different = 0;
static long checks = 0;

static UTType *host_constant(NSString *name)
{
    // The host's UTType constants are data symbols behind NS_REFINED_FOR_SWIFT, so nothing in the
    // SDK's own declarations names them: each is read out of the process by its symbol name.
    void *symbol = dlsym(RTLD_DEFAULT, name.UTF8String);
    if (!symbol)
        return nil;
    void *value = *(void **)symbol;
    return (__bridge UTType *)value;
}

static void check_identifiers(NSString *path)
{
    NSString *table = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NSMutableArray<NSString *> *expected = [NSMutableArray array];
    for (NSString *line in [table componentsSeparatedByString:@"\n"]) {
        if (!line.length)
            continue;
        NSArray<NSString *> *pair = [line componentsSeparatedByString:@"\t"];
        [names addObject:pair[0]];
        [expected addObject:pair[1]];
    }
    for (NSUInteger i = 0; i < names.count; i++) {
        NSString *name = names[i];
        NSString *want = expected[i];
        UTType *type = host_constant(name);
        checks++;
        if (!type) {
            different++;
            printf("%s: the host exports no such symbol\n", name.UTF8String);
            continue;
        }
        NSString *got = type.identifier;
        if (![got isEqualToString:want]) {
            different++;
            printf("%s: expected %s, host %s\n", name.UTF8String, want.UTF8String, got.UTF8String);
        }
    }
    printf("uttypeconstants: %lu identifiers compared against the host's own constants\n",
           (unsigned long)names.count);
}

static void check_tag_classes(void)
{
    NSString *extension = UTTagClassFilenameExtension;
    NSString *mime = UTTagClassMIMEType;
    checks += 2;
    if (![extension isKindOfClass:[NSString class]]) {
        different++;
        printf("UTTagClassFilenameExtension: the host's is a %s, not a string\n", class_getName([extension class]));
    } else {
        printf("UTTagClassFilenameExtension = %s\n", extension.UTF8String);
    }
    if (![mime isKindOfClass:[NSString class]]) {
        different++;
        printf("UTTagClassMIMEType: the host's is a %s, not a string\n", class_getName([mime class]));
    } else {
        printf("UTTagClassMIMEType = %s\n", mime.UTF8String);
    }
    // The release's own spelling of the same two tag classes, MobileCoreServices' kUTTagClass*, is
    // what the port's -typeWithTag:tagClass: passes through, so the two have to be one string.
    NSString *release_extension = (__bridge NSString *)kUTTagClassFilenameExtension;
    NSString *release_mime = (__bridge NSString *)kUTTagClassMIMEType;
    checks += 2;
    if (![extension isEqualToString:release_extension]) {
        different++;
        printf("UTTagClassFilenameExtension %s is not kUTTagClassFilenameExtension %s\n",
               extension.UTF8String, release_extension.UTF8String);
    }
    if (![mime isEqualToString:release_mime]) {
        different++;
        printf("UTTagClassMIMEType %s is not kUTTagClassMIMEType %s\n", mime.UTF8String, release_mime.UTF8String);
    }
}

static void check_system_answers(void)
{
    // What the host says about a type the system declares, for the three members the port answers
    // from the process's own UTI declarations instead (a release whose UTI database declares no
    // version and no reference URL for any type). Printed, not asserted: the point is that the
    // expectation written into the facts file is the host's, read here.
    NSArray<NSString *> *identifiers = @[@"public.png", @"public.plain-text", @"com.adobe.pdf", @"public.data"];
    for (NSString *identifier in identifiers) {
        UTType *type = [UTType typeWithIdentifier:identifier];
        checks++;
        if (!type) {
            different++;
            printf("the host has no type %s\n", identifier.UTF8String);
            continue;
        }
        NSNumber *version = type.version;
        NSURL *reference = type.referenceURL;
        printf("%s: declared %d dynamic %d public %d version %s referenceURL %s supertypes %lu\n",
               identifier.UTF8String, type.isDeclared, type.isDynamic, type.isPublicType,
               version ? version.stringValue.UTF8String : "(nil)",
               reference ? reference.absoluteString.UTF8String : "(nil)",
               (unsigned long)type.supertypes.count);
    }
    UTType *made = [UTType typeWithFilenameExtension:@"zzqq"];
    printf("UTType for the undeclared extension zzqq: %s, declared %d, dynamic %d\n",
           made.identifier.UTF8String, made.isDeclared, made.isDynamic);

    // What the host answers for an identifier its own process declares no export or import for.
    // UTType.h documents both results as undefined when the identifier is unknown to the system,
    // so what is asserted is only that the host returns a type carrying that identifier -- which is
    // the rule the port implements for exported, and the starting point of the rule it implements
    // for imported (the general case is a type that carries the same identifier).
    NSString *unknown = @"com.example.nothing-declared-here";
    UTType *exported = [UTType exportedTypeWithIdentifier:unknown];
    checks++;
    if (!exported || ![exported.identifier isEqualToString:unknown]) {
        different++;
        printf("exportedTypeWithIdentifier: host answered %s for %s\n",
               exported ? exported.identifier.UTF8String : "(nil)", unknown.UTF8String);
    }
    UTType *imported = [UTType importedTypeWithIdentifier:unknown];
    checks++;
    if (!imported || ![imported.identifier isEqualToString:unknown]) {
        different++;
        printf("importedTypeWithIdentifier: host answered %s for %s\n",
               imported ? imported.identifier.UTF8String : "(nil)", unknown.UTF8String);
    }
    printf("exported/importedTypeWithIdentifier: for %s: exported %s, imported %s\n", unknown.UTF8String,
           exported.identifier.UTF8String, imported.identifier.UTF8String);

    // The imported rule the header spells out: a type with a preferred filename extension yields to
    // the type that is the preferred type for that extension. public.jpeg's preferred extension is
    // jpeg, and public.jpeg is the preferred type for it, so the two are one type here; the check
    // that holds is that substituting one that is not preferred returns the preferred one.
    // The one identifier the header does not get right. Every SDK drop's UTCoreTypes.h documents
    // UTTypeInternetShortcut as `com.apple.internet-location`, the identifier of the constant above
    // it in the same file (macOS 26.5, macOS 27 and the port's own 16.4 all repeat it), while the
    // system's own UniformTypeIdentifiers answers com.microsoft.internet-shortcut for it. The port
    // takes the measured value; expected-identifiers.tsv carries it and this line proves it is the
    // system's and not the header's.
    NSString *shortcut = host_constant(@"UTTypeInternetShortcut").identifier;
    NSString *location = host_constant(@"UTTypeInternetLocation").identifier;
    printf("UTTypeInternetShortcut = %s, UTTypeInternetLocation = %s (the header says com.apple.internet-location for both)\n",
           shortcut.UTF8String, location.UTF8String);
    checks++;
    if ([shortcut isEqualToString:@"com.apple.internet-location"] || [shortcut isEqualToString:location]) {
        different++;
        printf("UTTypeInternetShortcut %s is the header's value, not the system's\n", shortcut.UTF8String);
    }

    UTType *jpeg = [UTType typeWithIdentifier:@"public.jpeg"];
    UTType *substituted = [UTType typeWithFilenameExtension:@"jpeg"];
    checks++;
    printf("public.jpeg preferred extension %s, preferred type for it %s, conforming %d\n",
           jpeg.preferredFilenameExtension.UTF8String, substituted.identifier.UTF8String,
           [jpeg conformsToType:substituted]);
}

int main(void)
{
    @autoreleasepool {
        NSString *here = [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"expected-identifiers.tsv"];
        check_identifiers(here);
        check_tag_classes();
        check_system_answers();
        printf("uttypeconstants: %ld checks, %d different\n", checks, different);
        return different ? 1 : 0;
    }
}
#include <MobileCoreServices/MobileCoreServices.h>

// A dynamic identifier is "dyn." in any case, then one or more components joined by single dots,
// each of ASCII letters, digits and hyphens, neither starting nor ending with a hyphen: what the
// host answers, measured by tests/backports/host/uttype.
Boolean UTTypeIsDynamic(CFStringRef inUTI)
{
    if (!inUTI || CFGetTypeID(inUTI) != CFStringGetTypeID())
        return false;
    CFIndex length = CFStringGetLength(inUTI);
    if (length < 5)
        return false;
    UniChar prefix[4];
    CFStringGetCharacters(inUTI, CFRangeMake(0, 4), prefix);
    if ((prefix[0] | 0x20) != 'd' || (prefix[1] | 0x20) != 'y' || (prefix[2] | 0x20) != 'n' || prefix[3] != '.')
        return false;
    UniChar previous = '.';
    for (CFIndex index = 4; index < length; index++) {
        UniChar character = CFStringGetCharacterAtIndex(inUTI, index);
        Boolean alphanumeric = (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') || (character >= '0' && character <= '9');
        if (character == '.') {
            if (previous == '.' || previous == '-')
                return false;
        } else if (character == '-') {
            if (previous == '.')
                return false;
        } else if (!alphanumeric) {
            return false;
        }
        previous = character;
    }
    return previous != '.' && previous != '-';
}

// Declared means the release's LaunchServices has a declaration for the identifier, which a
// dynamic identifier never has.
Boolean UTTypeIsDeclared(CFStringRef inUTI)
{
    if (!inUTI || CFGetTypeID(inUTI) != CFStringGetTypeID())
        return false;
    CFDictionaryRef declaration = UTTypeCopyDeclaration(inUTI);
    if (!declaration)
        return false;
    CFRelease(declaration);
    return true;
}

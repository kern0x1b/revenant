#include <MobileCoreServices/MobileCoreServices.h>
#include <stdlib.h>

// UTTypeCopyAllTagsWithClass, iOS 8.0. The SDK deprecates it from 8.0 to 15.0 in favour of the UTType class.
//
// A declared identifier answers its declaration's UTTypeTagSpecification for the class: a string as a one-element
// array, an array as it is, NULL when the declaration names no such class. Tags are not inherited from a parent: the
// host answers NULL for public.zip-archive's ostype, which public.data declares as sbFl. Measured by
// tests/backports/host/uttypetags.
//
// A dynamic identifier carries its tags in its name: "dyn.a", then a base-32 tail whose digits are five bits each,
// in the alphabet below, and whose bits are read in eight-bit bytes. The bytes are records: a key up to the next '=',
// then a value up to the next ':', and the value is a list split by ','. A key is a class name, or a code for one of
// the classes (see KeyClass). A backslash escapes the byte after it. A key with no '=' after it ends the records. A
// value that is empty is skipped; a value that is not UTF-8 is dropped, and a class with a non-empty value answers an
// array even when every value was dropped. Measured case by case on the host (tests/backports/host/uttypetags).

static const char kDynamicAlphabet[] = "abcdefghkmnpqrstuvwxyz0123456789";

static int DynamicDigitValue(UniChar character)
{
    if (character >= 'A' && character <= 'Z')
        character += 'a' - 'A';
    for (int value = 0; value < 32; value++) {
        if (kDynamicAlphabet[value] == character)
            return value;
    }
    return -1;
}

// The identifier's tail as bytes; NULL when a character is outside the alphabet.
static unsigned char *DynamicTailBytes(CFStringRef inUTI, CFIndex start, CFIndex *outLength)
{
    CFIndex length = CFStringGetLength(inUTI);
    unsigned char *bytes = malloc(length - start + 1);
    unsigned int accumulator = 0;
    unsigned int bits = 0;
    CFIndex count = 0;
    for (CFIndex index = start; index < length; index++) {
        int value = DynamicDigitValue(CFStringGetCharacterAtIndex(inUTI, index));
        if (value < 0) {
            free(bytes);
            return NULL;
        }
        accumulator = (accumulator << 5) | (unsigned int)value;
        bits += 5;
        if (bits >= 8) {
            bits -= 8;
            bytes[count++] = (unsigned char)((accumulator >> bits) & 0xFF);
            accumulator &= (1u << bits) - 1;
        }
    }
    *outLength = count;
    return bytes;
}

// The first byte at or after `from` and before `limit` that is `target` and not escaped, or `limit`.
static CFIndex FindUnescaped(const unsigned char *bytes, CFIndex limit, CFIndex from, unsigned char target)
{
    for (CFIndex index = from; index < limit;) {
        if (bytes[index] == '\\' && index + 1 < limit)
            index += 2;
        else if (bytes[index] == target)
            return index;
        else
            index++;
    }
    return limit;
}

// The bytes between start and end with each escape resolved; a backslash that escapes nothing stays.
static unsigned char *Unescaped(const unsigned char *bytes, CFIndex start, CFIndex end, CFIndex *outLength)
{
    unsigned char *out = malloc(end - start + 1);
    CFIndex count = 0;
    for (CFIndex index = start; index < end;) {
        if (bytes[index] == '\\' && index + 1 < end) {
            out[count++] = bytes[index + 1];
            index += 2;
        } else {
            out[count++] = bytes[index++];
        }
    }
    *outLength = count;
    return out;
}

static int IsHexDigit(unsigned char byte)
{
    return (byte >= '0' && byte <= '9') || (byte >= 'a' && byte <= 'f') || (byte >= 'A' && byte <= 'F');
}

// The class a key's code names, or NULL. A code is one or two leading hex digits that make up the whole key, or one hex
// digit followed by one byte that is not a hex digit: "1", "03", "1x" and "1-" name 1 and 3, while "10" (16), "1A"
// (26), "03x" and "1xA" name no class.
static CFStringRef KeyClass(const unsigned char *key, CFIndex length)
{
    CFIndex digits = 0;
    unsigned int number = 0;
    while (digits < 2 && digits < length && IsHexDigit(key[digits])) {
        number = number * 16 + (key[digits] <= '9' ? key[digits] - '0' : (key[digits] | 0x20) - 'a' + 10);
        digits++;
    }
    if (digits == 0 || (digits != length && !(digits == 1 && length == 2)))
        return NULL;
    switch (number) {
    case 1: return CFSTR("public.filename-extension");
    case 2: return CFSTR("com.apple.ostype");
    case 3: return CFSTR("public.mime-type");
    case 4: return CFSTR("com.apple.nspboard-type");
    }
    return NULL;
}

static CFArrayRef DynamicRecordValues(const unsigned char *bytes, CFIndex count, CFStringRef inTagClass)
{
    CFMutableArrayRef values = NULL;
    CFIndex position = 0;
    while (position < count) {
        CFIndex separator = FindUnescaped(bytes, count, position, '=');
        if (separator == count)
            break;
        CFStringRef named = separator > position ? KeyClass(bytes + position, separator - position) : NULL;
        CFStringRef literal = NULL;
        if (!named && separator > position) {
            CFIndex keyLength = 0;
            unsigned char *keyBytes = Unescaped(bytes, position, separator, &keyLength);
            literal = CFStringCreateWithBytes(NULL, keyBytes, keyLength, kCFStringEncodingUTF8, false);
            free(keyBytes);
        }
        CFIndex valueStart = separator + 1;
        CFIndex recordEnd = FindUnescaped(bytes, count, valueStart, ':');
        if ((named && CFStringCompare(named, inTagClass, 0) == kCFCompareEqualTo)
            || (literal && CFStringCompare(literal, inTagClass, 0) == kCFCompareEqualTo)) {
            while (valueStart <= recordEnd) {
                CFIndex valueEnd = FindUnescaped(bytes, recordEnd, valueStart, ',');
                if (valueEnd > valueStart) {
                    if (!values)
                        values = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
                    CFIndex valueLength = 0;
                    unsigned char *valueBytes = Unescaped(bytes, valueStart, valueEnd, &valueLength);
                    CFStringRef value = CFStringCreateWithBytes(NULL, valueBytes, valueLength, kCFStringEncodingUTF8, false);
                    free(valueBytes);
                    if (value) {
                        CFArrayAppendValue(values, value);
                        CFRelease(value);
                    }
                }
                valueStart = valueEnd + 1;
            }
        }
        if (literal)
            CFRelease(literal);
        position = recordEnd + 1;
    }
    return values;
}

static CFArrayRef DynamicTags(CFStringRef inUTI, CFStringRef inTagClass)
{
    if (CFStringGetLength(inUTI) < 5 || CFStringGetCharacterAtIndex(inUTI, 4) != 'a')
        return NULL;
    CFIndex count = 0;
    unsigned char *bytes = DynamicTailBytes(inUTI, 5, &count);
    if (!bytes)
        return NULL;
    CFArrayRef values = DynamicRecordValues(bytes, count, inTagClass);
    free(bytes);
    return values;
}

static CFArrayRef DeclaredTags(CFStringRef inUTI, CFStringRef inTagClass)
{
    CFDictionaryRef declaration = UTTypeCopyDeclaration(inUTI);
    if (!declaration)
        return NULL;
    CFTypeRef specification = CFDictionaryGetValue(declaration, CFSTR("UTTypeTagSpecification"));
    CFTypeRef tags = NULL;
    if (specification && CFGetTypeID(specification) == CFDictionaryGetTypeID())
        tags = CFDictionaryGetValue((CFDictionaryRef)specification, inTagClass);
    CFArrayRef result = NULL;
    if (tags && CFGetTypeID(tags) == CFStringGetTypeID()) {
        const void *item = tags;
        result = CFArrayCreate(NULL, &item, 1, &kCFTypeArrayCallBacks);
    } else if (tags && CFGetTypeID(tags) == CFArrayGetTypeID()) {
        result = CFArrayCreateCopy(NULL, (CFArrayRef)tags);
    }
    CFRelease(declaration);
    return result;
}

CFArrayRef UTTypeCopyAllTagsWithClass(CFStringRef inUTI, CFStringRef inTagClass)
{
    if (!inUTI || !inTagClass || CFGetTypeID(inUTI) != CFStringGetTypeID() || CFGetTypeID(inTagClass) != CFStringGetTypeID())
        return NULL;
    if (UTTypeIsDynamic(inUTI))
        return DynamicTags(inUTI, inTagClass);
    return DeclaredTags(inUTI, inTagClass);
}

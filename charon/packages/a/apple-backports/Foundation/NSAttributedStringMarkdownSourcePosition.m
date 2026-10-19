#import <Foundation/Foundation.h>

/* NSAttributedStringMarkdownSourcePosition arrived in iOS 16, and the release has neither the
   class nor any part of it. It is four numbers, so the whole class is here, and the twelve keys
   its archive carries are the host's own, so an archive either side writes is one the other
   reads. The measurements are in facts/Foundation/NSAttributedStringMarkdownSourcePosition.md,
   and tests/backports/host/markdownsourceposition holds them to the host - including the range,
   which is measured over the positions the host's own Markdown parser marks. */

NSString *const NSMarkdownSourcePositionAttributeName = @"NSMarkdownSourcePosition";

/* The eight places the host's own archive carries beside the four numbers: the UTF-8 and UTF-16
   offsets it works out for itself and caches, the code point each end starts at, and the length
   of the code point at each end in UTF-16. An archive written from a position nobody has asked
   for a range of carries all eight as NSIntegerMax, the state that means "not worked out"; the
   host's own parser asks for the ranges first, so an archive of one of its positions carries real
   offsets. A 0 among them is therefore a real offset, and one that belongs to one particular
   Markdown string - a string no archive carries and no key in one names, which is why the decode
   below reads these eight and uses none of them, and why -rangeInString: works the range out from
   the four numbers instead. They are written and read as the host writes and reads them, so an
   archive of this class is the same shape whichever of the two wrote it. */
static NSString *const charon_cached_offset_keys[] = {
    @"NSStartUTF8Offset", @"NSEndUTF8Offset", @"NSStartUTF16Offset", @"NSEndUTF16Offset",
    @"NSStartUTF8NextCodePoint", @"NSEndUTF8NextCodePoint",
    @"NSStartUTF16CurrentCodePointLength", @"NSEndUTF16CurrentCodePointLength",
};

/* The byte a line and a column name, or NSNotFound where the document has no such place. A line
   is one-based and its first byte is the one after the newline before it; a column is one-based
   and a byte offset within the line, which for a multi-byte character is the character's first
   byte. Measured on the host's own archive of the positions its Markdown parser marks, where the
   eight cached keys are the byte offsets and the UTF-16 ones side by side: for "a two-byte run"
   the parser's end column 24 is byte 23 and the host's NSEndUTF8Offset is 23 (SDK 16.4
   Foundation/NSAttributedString.h, the class's own declaration, carries no text on either). */
static NSUInteger charon_marked_byte(NSData *source, NSInteger line, NSInteger column)
{
    if (line < 1 || column < 1)
        return NSNotFound;
    const char *bytes = (const char *)source.bytes;
    NSUInteger total = source.length;
    NSInteger current = 1;
    NSUInteger offset = 0;
    while (current < line && offset < total) {
        if (bytes[offset] == '\n')
            current++;
        offset++;
    }
    if (current != line)
        return NSNotFound;
    NSUInteger into = (NSUInteger)(column - 1);
    if (into >= total || offset >= total - into)
        return NSNotFound;
    return offset + into;
}

/* The place a byte offset of the document names in an NSString, and how many UTF-16 units the
   character at it is: the UTF-16 offset of the character that starts at or contains the byte, and
   2 for a character above the BMP and 1 for every other. A byte inside a character is attributed
   to that character, which is what the host's own NSStartUTF16Offset says of a byte inside one
   (measured on the four-byte case, where the emoji's first UTF-16 unit and its second are the
   same offset in the archive's own keys). */
static void charon_utf16_place(const char *bytes, NSUInteger length, NSUInteger byte, NSUInteger *offset, NSUInteger *units)
{
    NSUInteger at = 0, utf16 = 0;
    while (at < byte) {
        unsigned char lead = (unsigned char)bytes[at];
        NSUInteger wide = lead < 0x80 ? 1 : (lead < 0xE0 ? 2 : (lead < 0xF0 ? 3 : 4));
        NSUInteger before = utf16;
        utf16 += wide == 4 ? 2 : 1;
        if (at + wide > byte) {
            /* The byte is inside the character that starts here, so it is that character's place
               and that character's width - which is what the host's own NSEndUTF16Offset and
               NSEndUTF16CurrentCodePointLength say of it (measured on a document whose run ends
               with a character above the BMP: the host answers {0,24} for the end column that
               names the face's last byte, and 22 plus its two units is 24). */
            *offset = before;
            *units = wide == 4 ? 2 : 1;
            return;
        }
        at += wide;
    }
    *offset = utf16;
    *units = at < length ? (((unsigned char)bytes[at] >= 0xF0) ? 2 : 1) : 0;
}

@implementation NSAttributedStringMarkdownSourcePosition {
    NSInteger _startLine;
    NSInteger _startColumn;
    NSInteger _endLine;
    NSInteger _endColumn;
}

/* -init is not this class's own: the SDK's header declares only -initWithStartLine:..., and the
   host's class answers -init with NSObject's (four zeroes, measured), so the port does not carry
   a method Apple's class does not define. */

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithStartLine:(NSInteger)startLine startColumn:(NSInteger)startColumn endLine:(NSInteger)endLine endColumn:(NSInteger)endColumn
{
    self = [super init];
    if (self) {
        _startLine = startLine;
        _startColumn = startColumn;
        _endLine = endLine;
        _endColumn = endColumn;
    }
    return self;
}

- (NSInteger)startLine
{
    return _startLine;
}

- (NSInteger)startColumn
{
    return _startColumn;
}

- (NSInteger)endLine
{
    return _endLine;
}

- (NSInteger)endColumn
{
    return _endColumn;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithStartLine:_startLine startColumn:_startColumn
                                                       endLine:_endLine endColumn:_endColumn];
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[NSAttributedStringMarkdownSourcePosition class]])
        return NO;
    NSAttributedStringMarkdownSourcePosition *other = object;
    return _startLine == other->_startLine && _startColumn == other->_startColumn
        && _endLine == other->_endLine && _endColumn == other->_endColumn;
}

- (NSUInteger)hash
{
    return (NSUInteger)(_startLine * 31 + _startColumn) * 31 + (NSUInteger)(_endLine * 31 + _endColumn);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"Encoder does not allow key encoding"];
        return;
    }
    [coder encodeInteger:_startLine forKey:@"NSStartLine"];
    [coder encodeInteger:_startColumn forKey:@"NSStartColumn"];
    [coder encodeInteger:_endLine forKey:@"NSEndLine"];
    [coder encodeInteger:_endColumn forKey:@"NSEndColumn"];
    for (unsigned index = 0; index < sizeof(charon_cached_offset_keys) / sizeof(*charon_cached_offset_keys); index++)
        [coder encodeInteger:NSIntegerMax forKey:charon_cached_offset_keys[index]];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"Encoder does not allow key encoding"];
        return nil;
    }
    if (!(self = [super init]))
        return nil;
    _startLine = [coder decodeIntegerForKey:@"NSStartLine"];
    _startColumn = [coder decodeIntegerForKey:@"NSStartColumn"];
    _endLine = [coder decodeIntegerForKey:@"NSEndLine"];
    _endColumn = [coder decodeIntegerForKey:@"NSEndColumn"];
    /* The eight cached offsets are read and not used: they are offsets into one particular
       Markdown string, which an archive does not carry, so there is nothing to check them
       against, and the range below is worked out from the four numbers. The host reads them all
       the same way, so an archive is read the same whichever of the two wrote it. */
    for (unsigned index = 0; index < sizeof(charon_cached_offset_keys) / sizeof(*charon_cached_offset_keys); index++)
        (void)[coder decodeInt64ForKey:charon_cached_offset_keys[index]];
    return self;
}

- (NSRange)rangeInString:(NSString *)string
{
    /* A line and a column, and a column is a 1-based UTF-8 byte offset within its line, so the two
       ends are found over the source's bytes and not over its characters: for a multi-byte
       character the column is its first byte. The range itself is in UTF-16 units, because an
       NSRange into an NSString is, and the end is the last character and not the place after it,
       so the range is one unit longer than the two ends are apart. Both halves are measured on the
       host's own archive of the positions its Markdown parser marks, where the byte offsets and
       the UTF-16 ones are keys side by side: for "a two-byte run" the parser's end column 24 is
       byte 23 and the host answers {0,22}, which is the UTF-16 offset 0 and the UTF-16 offset 21
       plus that character's one unit. See the facts file. */
    NSData *source = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger startByte = charon_marked_byte(source, _startLine, _startColumn);
    NSUInteger endByte = charon_marked_byte(source, _endLine, _endColumn);
    if (startByte == NSNotFound || endByte == NSNotFound || endByte < startByte)
        return NSMakeRange(NSNotFound, 0);
    const char *bytes = (const char *)source.bytes;
    NSUInteger length = source.length, start = 0, end = 0, startUnits = 0, endUnits = 0;
    charon_utf16_place(bytes, length, startByte, &start, &startUnits);
    charon_utf16_place(bytes, length, endByte, &end, &endUnits);
    /* The byte check above has already refused an end before the start, and the conversion is
       monotonic, so the end in UTF-16 units is never before the start here. */
    return NSMakeRange(start, end + endUnits - start);
}

- (NSString *)description
{
    /* The four numbers go out unsigned, as the host writes them: a position built with -2 reads
       back -2 from every property and describes itself as 18446744073709551614. */
    return [NSString stringWithFormat:@"<%@: %p>{startLine=%lu, startColumn=%lu, endLine=%lu, endColumn=%lu}",
                                      NSStringFromClass([self class]), self, (unsigned long)_startLine,
                                      (unsigned long)_startColumn, (unsigned long)_endLine, (unsigned long)_endColumn];
}

@end

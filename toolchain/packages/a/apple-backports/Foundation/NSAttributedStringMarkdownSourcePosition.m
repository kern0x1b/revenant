#import <Foundation/Foundation.h>

NSString *const NSMarkdownSourcePositionAttributeName = @"NSMarkdownSourcePosition";

static NSString *const charon_cached_offset_keys[] = {
    @"NSStartUTF8Offset", @"NSEndUTF8Offset", @"NSStartUTF16Offset", @"NSEndUTF16Offset",
    @"NSStartUTF8NextCodePoint", @"NSEndUTF8NextCodePoint",
    @"NSStartUTF16CurrentCodePointLength", @"NSEndUTF16CurrentCodePointLength",
};

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

static void charon_utf16_place(const char *bytes, NSUInteger length, NSUInteger byte, NSUInteger *offset, NSUInteger *units)
{
    NSUInteger at = 0, utf16 = 0;
    while (at < byte) {
        unsigned char lead = (unsigned char)bytes[at];
        NSUInteger wide = lead < 0x80 ? 1 : (lead < 0xE0 ? 2 : (lead < 0xF0 ? 3 : 4));
        NSUInteger before = utf16;
        utf16 += wide == 4 ? 2 : 1;
        if (at + wide > byte) {
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
    for (unsigned index = 0; index < sizeof(charon_cached_offset_keys) / sizeof(*charon_cached_offset_keys); index++)
        (void)[coder decodeInt64ForKey:charon_cached_offset_keys[index]];
    return self;
}

- (NSRange)rangeInString:(NSString *)string
{
    NSData *source = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger startByte = charon_marked_byte(source, _startLine, _startColumn);
    NSUInteger endByte = charon_marked_byte(source, _endLine, _endColumn);
    if (startByte == NSNotFound || endByte == NSNotFound || endByte < startByte)
        return NSMakeRange(NSNotFound, 0);
    const char *bytes = (const char *)source.bytes;
    NSUInteger length = source.length, start = 0, end = 0, startUnits = 0, endUnits = 0;
    charon_utf16_place(bytes, length, startByte, &start, &startUnits);
    charon_utf16_place(bytes, length, endByte, &end, &endUnits);
    return NSMakeRange(start, end + endUnits - start);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>{startLine=%lu, startColumn=%lu, endLine=%lu, endColumn=%lu}",
                                      NSStringFromClass([self class]), self, (unsigned long)_startLine,
                                      (unsigned long)_startColumn, (unsigned long)_endLine, (unsigned long)_endColumn];
}

@end

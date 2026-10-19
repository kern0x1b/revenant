//
//  CharonAXMathExpression.m
//  Accessibility
//
//  The fifteen AXMathExpression classes of iOS 18.2, on the object graph the header declares and
//  nothing else. CharonAXMathExpression.h carries the declarations and the two places the header
//  disagrees with itself; the rules this file follows are:
//
//  * **An initialiser stores what it was given and a property answers it unchanged, identity
//    preserved.** There is no validation and no exception: the header's `NS_ASSUME_NONNULL` is a
//    promise the caller makes, not a check the class performs, and the host keeps the promise the
//    same way - a nil content, a nil expression array and a nil string all come back as nil rather
//    than raising (measured on the host's own Accessibility.framework, four cases, none raised).
//  * **Nothing here is parsed and nothing is evaluated.** The application builds the tree; the
//    assistive technology reads it and turns it into speech or Braille. That half is the system's and
//    this release has none, which is why the class is the whole of the work: the value the caller
//    built is the value the system would have been handed.
//  * `isEqual:` is NSObject's own, by identity, because no class in this header declares NSCopying.
//    The host answers the same: two contents built from the same string are not equal (measured).
//

#import "CharonAXMathExpression.h"

#pragma mark - AXMathExpression

// The base class has no state and no member of its own, and this @implementation is what makes it
// exist: a class with no @implementation emits no `_OBJC_CLASS_$_` symbol, so nothing could subclass
// it at link time and the registry's own row for it would read as a name nothing is built. It is
// NSObject's subclass with nothing added, which is what the header declares and what the host answers
// (`[AXMathExpression superclass]` is NSObject, measured).
@implementation AXMathExpression
@end

#pragma mark - the four contents

// Number, Identifier, Operator and Text are the same class with a different name, which is why the
// header writes them out four times: they are the leaves of the graph, and a leaf is a string. Each
// one keeps that string and answers it, so the four are written out rather than shared through a
// class of the port's own - a superclass the SDK does not declare would be a name the release's own
// runtime has never heard of, and the corpus asks for these four classes by name.
#define CHARON_AX_MATH_CONTENT(CLASS)                                                    \
    @implementation CLASS {                                                              \
        NSString *_content;                                                              \
    }                                                                                    \
    - (instancetype)initWithContent:(NSString *)content                                   \
    {                                                                                    \
        self = [super init];                                                             \
        if (self) {                                                                      \
            _content = [content copy];                                                   \
        }                                                                                \
        return self;                                                                     \
    }                                                                                    \
    - (NSString *)content                                                                \
    {                                                                                    \
        return _content;                                                                 \
    }                                                                                    \
    @end

CHARON_AX_MATH_CONTENT(AXMathExpressionNumber)
CHARON_AX_MATH_CONTENT(AXMathExpressionIdentifier)
CHARON_AX_MATH_CONTENT(AXMathExpressionOperator)
CHARON_AX_MATH_CONTENT(AXMathExpressionText)

#pragma mark - AXMathExpressionFenced

@implementation AXMathExpressionFenced {
    NSArray<AXMathExpression *> *_expressions;
    NSString *_openString;
    NSString *_closeString;
}

- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions
                         openString:(NSString *)openString
                        closeString:(NSString *)closeString
{
    self = [super init];
    if (self) {
        // Not copied and not retained into a new array: the host answers the very array it was given
        // (measured, `expressions == the array` on the host), and a caller that mutates the array it
        // built sees the mutation here as it would on the host. The property is readonly, so this is
        // not a way to change a built expression - it is the same sharing the host does.
        _expressions = expressions;
        _openString = [openString copy];
        _closeString = [closeString copy];
    }
    return self;
}

- (NSArray<AXMathExpression *> *)expressions
{
    return _expressions;
}

- (NSString *)openString
{
    return _openString;
}

- (NSString *)closeString
{
    return _closeString;
}

@end

#pragma mark - the four containers of one array

// These four keep the array they were given and answer the very same one, which is what the host
// does for Fenced, TableRow and TableCell (measured: identity equal in each of the three). They are
// written as one macro because they are one class with four names, which is what the header says:
// `AXMathExpressionRow`, `AXMathExpressionTable`, `AXMathExpressionTableRow` and
// `AXMathExpressionTableCell` each declare `initWithExpressions:` and `expressions` and nothing else.
#define CHARON_AX_MATH_EXPRESSIONS_ONLY(CLASS)                                           \
    @implementation CLASS {                                                              \
        NSArray<AXMathExpression *> *_expressions;                                        \
    }                                                                                    \
    - (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions        \
    {                                                                                    \
        self = [super init];                                                             \
        if (self) {                                                                      \
            _expressions = expressions;                                                  \
        }                                                                                \
        return self;                                                                     \
    }                                                                                    \
    - (NSArray<AXMathExpression *> *)expressions                                         \
    {                                                                                    \
        return _expressions;                                                             \
    }                                                                                    \
    @end

// Row and Table are built by that macro too, and answer the same array the host does not: it answers
// nil for exactly these two and the array for the other three. They are named apart so that a reader
// comparing the two sides sees which pair is which without counting, and
// CharonAXMathExpression.h's header comment, the differential's expected-differences.tsv and
// facts/Accessibility/Accessibility.md all say what the difference is and why.
CHARON_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionTableRow)
CHARON_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionTableCell)
CHARON_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionRow)
CHARON_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionTable)

#pragma mark - AXMathExpressionUnderOver

@implementation AXMathExpressionUnderOver {
    AXMathExpression *_baseExpression;
    AXMathExpression *_underExpression;
    AXMathExpression *_overExpression;
}

- (instancetype)initWithBaseExpression:(AXMathExpression *)baseExpression
                       underExpression:(AXMathExpression *)underExpression
                         overExpression:(AXMathExpression *)overExpression
{
    self = [super init];
    if (self) {
        _baseExpression = baseExpression;
        _underExpression = underExpression;
        _overExpression = overExpression;
    }
    return self;
}

- (AXMathExpression *)baseExpression
{
    return _baseExpression;
}

- (AXMathExpression *)underExpression
{
    return _underExpression;
}

- (AXMathExpression *)overExpression
{
    return _overExpression;
}

@end

#pragma mark - AXMathExpressionRoot

@implementation AXMathExpressionRoot {
    NSArray<AXMathExpression *> *_radicandExpressions;
    AXMathExpression *_rootIndexExpression;
}

- (instancetype)initWithRadicandExpressions:(NSArray<AXMathExpression *> *)radicandExpressions
                          rootIndexExpression:(AXMathExpression *)rootIndexExpression
{
    self = [super init];
    if (self) {
        _radicandExpressions = radicandExpressions;
        _rootIndexExpression = rootIndexExpression;
    }
    return self;
}

- (NSArray<AXMathExpression *> *)radicandExpressions
{
    return _radicandExpressions;
}

- (AXMathExpression *)rootIndexExpression
{
    return _rootIndexExpression;
}

@end


#pragma mark - AXMathExpressionSubSuperscript

@implementation AXMathExpressionSubSuperscript {
    // The base is an array, because that is what the initialiser takes. The property above it is
    // declared a single expression and this answers the array; the header's own comment says which
    // and why, and the host does the same.
    NSArray<AXMathExpression *> *_baseExpression;
    NSArray<AXMathExpression *> *_subscriptExpressions;
    NSArray<AXMathExpression *> *_superscriptExpressions;
}

- (instancetype)initWithBaseExpression:(NSArray<AXMathExpression *> *)baseExpression
                 subscriptExpressions:(NSArray<AXMathExpression *> *)subscriptExpressions
                 superscriptExpressions:(NSArray<AXMathExpression *> *)superscriptExpressions
{
    self = [super init];
    if (self) {
        _baseExpression = baseExpression;
        _subscriptExpressions = subscriptExpressions;
        _superscriptExpressions = superscriptExpressions;
    }
    return self;
}

// The header declares this a single `AXMathExpression *` and the answer is the array the initialiser
// was given, which is what the host answers. The cast is the honest spelling of that: the declaration
// above is Apple's and is transcribed as written, the value here is measured, and the one place they
// disagree is the one this port cannot satisfy both ways. A caller that reads this property as the
// single expression the header declares gets an array, exactly as it would on the host, and
// `firstObject` is the caller's own way to the one it meant. See this file's header comment and
// facts/Accessibility/Accessibility.md.
- (AXMathExpression *)baseExpression
{
    return (AXMathExpression *)_baseExpression;
}

- (NSArray<AXMathExpression *> *)subscriptExpressions
{
    return _subscriptExpressions;
}

- (NSArray<AXMathExpression *> *)superscriptExpressions
{
    return _superscriptExpressions;
}

@end

#pragma mark - AXMathExpressionFraction

@implementation AXMathExpressionFraction {
    AXMathExpression *_numeratorExpression;
    AXMathExpression *_denimonatorExpression;
}

- (instancetype)initWithNumeratorExpression:(AXMathExpression *)numeratorExpression
                          denimonatorExpression:(AXMathExpression *)denimonatorExpression
{
    self = [super init];
    if (self) {
        _numeratorExpression = numeratorExpression;
        _denimonatorExpression = denimonatorExpression;
    }
    return self;
}

- (AXMathExpression *)numeratorExpression
{
    return _numeratorExpression;
}

- (AXMathExpression *)denimonatorExpression
{
    return _denimonatorExpression;
}

@end

#pragma mark - AXMathExpressionMultiscript

@implementation AXMathExpressionMultiscript {
    AXMathExpression *_baseExpression;
    NSArray<AXMathExpressionSubSuperscript *> *_prescriptExpressions;
    NSArray<AXMathExpressionSubSuperscript *> *_postscriptExpressions;
}

- (instancetype)initWithBaseExpression:(AXMathExpression *)baseExpression
                 prescriptExpressions:(NSArray<AXMathExpressionSubSuperscript *> *)prescriptExpressions
                 postscriptExpressions:(NSArray<AXMathExpressionSubSuperscript *> *)postscriptExpressions
{
    self = [super init];
    if (self) {
        _baseExpression = baseExpression;
        _prescriptExpressions = prescriptExpressions;
        _postscriptExpressions = postscriptExpressions;
    }
    return self;
}

- (AXMathExpression *)baseExpression
{
    return _baseExpression;
}

- (NSArray<AXMathExpressionSubSuperscript *> *)prescriptExpressions
{
    return _prescriptExpressions;
}

- (NSArray<AXMathExpressionSubSuperscript *> *)postscriptExpressions
{
    return _postscriptExpressions;
}

@end
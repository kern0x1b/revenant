#import "RevenantAXMathExpression.h"

#pragma mark - AXMathExpression

@implementation AXMathExpression
@end

#pragma mark - the four contents

#define REVENANT_AX_MATH_CONTENT(CLASS)                                                    \
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

REVENANT_AX_MATH_CONTENT(AXMathExpressionNumber)
REVENANT_AX_MATH_CONTENT(AXMathExpressionIdentifier)
REVENANT_AX_MATH_CONTENT(AXMathExpressionOperator)
REVENANT_AX_MATH_CONTENT(AXMathExpressionText)

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

#define REVENANT_AX_MATH_EXPRESSIONS_ONLY(CLASS)                                           \
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

REVENANT_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionTableRow)
REVENANT_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionTableCell)
REVENANT_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionRow)
REVENANT_AX_MATH_EXPRESSIONS_ONLY(AXMathExpressionTable)

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

//
//  CharonAXMathExpression.h
//  Accessibility
//
//  The declarations of iPhoneOS 26.2's AXMathExpression.h, which the port's own SDK (iPhoneOS 16.4)
//  does not carry, declared here from the interface. CharonAccessibility.h says which of the six headers
//  16.4 lacks are declared there and this is one of them; the classes themselves are built in
//  CharonAXMathExpression.m.
//
//  **What this group is, measured.** These fifteen classes are the object graph an application hands
//  to the system to describe a piece of mathematics, and nothing else: every one of them is a
//  container whose initialiser takes a value and whose properties read that same value back. There is
//  no parser here and no evaluator - `AXMathExpression.h` declares no method that takes a string and
//  no method that returns anything but the value an initialiser was given, and the host agrees: see
//  `tests/backports/host/accessibilitymath/`, where the port's answers and the host's own
//  Accessibility.framework are compared case by case.
//
//  **Two places the header disagrees with itself or with the host, and what this port does.** Both
//  are recorded in the differential's expected-differences.tsv and in facts/Accessibility/Accessibility.md.
//
//  1. `AXMathExpressionSubSuperscript`: the initialiser takes `baseExpression` as an **array** and the
//     property is declared a **single** `AXMathExpression *`. The host answers the array it was given,
//     unflattened, identity-preserved (measured: `baseExpression` is `__NSArrayI` of the two elements
//     the initialiser was given, and the very array it was given). This port does the same, because
//     the initialiser is the only source of the value and the property the only way to read it back:
//     answering one of the elements would throw away what the caller put in, and there is nothing in
//     the header that says which element that would be. A caller that wants a single expression takes
//     `firstObject` itself. The declaration below is the interface's as written and not corrected
//     - a backport that fixed the type would stop being the thing an application compiles against.
//  2. `AXMathExpressionRow` and `AXMathExpressionTable`: their initialiser takes an array their
//     property then answers **nil** on the host, whatever the array held (measured: nil for one, three
//     and mixed elements, and nil again for an empty array). This port returns the array it was given
//     instead, because the header declares the property `nonnull` and the value is the caller's own;
//     the host dropping it is a defect in Apple's implementation, not a behaviour the header states,
//     and a port that reproduced it would break every caller that compiled against the header. This is
//     the one place the two answers differ, and the differential is what says so.
//
//  A third difference is the host's and not a disagreement at all: every one of these classes answers
//  `isEqual:` by identity, because none of them declares NSCopying or overrides it. The port does the
//  same, so two contents built from the same string are two different objects, as they are on the host.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The availability is repeated on every interface because it is what places the object: the port's
// build reads a clang AST dump of the source being compiled and takes the release from this
// annotation, and an annotation on the @implementation produces none (measured, and written down in
// facts/Accessibility/Accessibility.md).
//
// `visionos(2.2)`, which Apple's copy of every one of these lines carries, is left off: the port
// compiles against iPhoneOS 16.4, whose availability macros have no such platform, and writing it
// would not compile (measured, 16 errors of `expected ','`). The release the port places an object by
// is the one this annotation carries, and visionOS is not a release the port builds for.

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpression : NSObject
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionNumber : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly) NSString *content;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionIdentifier : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly) NSString *content;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionOperator : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly) NSString *content;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionText : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly) NSString *content;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionFenced : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions openString:(NSString *)openString closeString:(NSString *)closeString;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *expressions;
@property (nonatomic, readonly) NSString *openString;
@property (nonatomic, readonly) NSString *closeString;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionRow : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *expressions;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionTable : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *expressions;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionTableRow : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *expressions;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionTableCell : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *expressions;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionUnderOver : AXMathExpression
- (instancetype)initWithBaseExpression:(AXMathExpression *)baseExpression underExpression:(AXMathExpression *)underExpression overExpression:(AXMathExpression *)overExpression;
@property (nonatomic, readonly) AXMathExpression *baseExpression;
@property (nonatomic, readonly) AXMathExpression *underExpression;
@property (nonatomic, readonly) AXMathExpression *overExpression;
@end

// The property is declared exactly as the interface declares it - a single expression - and the port's
// answer is an array; the header's own header comment above says which and why, and the measurement
// is one line in the differential.
API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionSubSuperscript : AXMathExpression
- (instancetype)initWithBaseExpression:(NSArray<AXMathExpression *> *)baseExpression subscriptExpressions:(NSArray<AXMathExpression *> *)subscriptExpressions superscriptExpressions:(NSArray<AXMathExpression *> *)superscriptExpressions;
@property (nonatomic, readonly) AXMathExpression *baseExpression;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *subscriptExpressions;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *superscriptExpressions;
@end

// `denimonator` is Apple's own spelling, in both the initialiser and the property, and it is the
// spelling the corpus row and every caller use. A backport that spelled it correctly would be a
// different API under the same name.
API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionFraction : AXMathExpression
- (instancetype)initWithNumeratorExpression:(AXMathExpression *)numeratorExpression denimonatorExpression:(AXMathExpression *)denimonatorExpression;
@property (nonatomic, readonly) AXMathExpression *numeratorExpression;
@property (nonatomic, readonly) AXMathExpression *denimonatorExpression;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionMultiscript : AXMathExpression
- (instancetype)initWithBaseExpression:(AXMathExpression *)baseExpression prescriptExpressions:(NSArray<AXMathExpressionSubSuperscript *> *)prescriptExpressions postscriptExpressions:(NSArray<AXMathExpressionSubSuperscript *> *)postscriptExpressions;
@property (nonatomic, readonly) AXMathExpression *baseExpression;
@property (nonatomic, readonly) NSArray<AXMathExpressionSubSuperscript *> *prescriptExpressions;
@property (nonatomic, readonly) NSArray<AXMathExpressionSubSuperscript *> *postscriptExpressions;
@end

API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@interface AXMathExpressionRoot : AXMathExpression
- (instancetype)initWithRadicandExpressions:(NSArray<AXMathExpression *> *)radicandExpressions rootIndexExpression:(AXMathExpression *)rootIndexExpression;
@property (nonatomic, readonly) NSArray<AXMathExpression *> *radicandExpressions;
@property (nonatomic, readonly) AXMathExpression *rootIndexExpression;
@end

// The protocol comes with the header and is carried with it, because the object that adopts it has to
// be able to name it. Its one method is a method row and not one of the two groups adjudicated here.
API_AVAILABLE(ios(18.2), macos(15.2), tvos(18.2), watchos(11.2))
@protocol AXMathExpressionProvider <NSObject>

- (nullable AXMathExpression *)accessibilityMathExpression;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface CharonPDFTextRun : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSUInteger offset;
@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) CGFloat size;
@property (nonatomic, copy, nullable) NSString *fontName;
@end

@interface CharonPDFTextRun (CharonGeometry)
- (void)charon_setGlyphRects:(const CGRect *)rects count:(NSUInteger)count;
- (CGRect)rectAtIndex:(NSUInteger)index;
@end

@interface CharonPDFFontMetrics : NSObject

+ (nullable instancetype)metricsWithFontDictionary:(nullable CGPDFDictionaryRef)fontDictionary
                                              size:(CGFloat)size;
- (CGFloat)advanceForCode:(int)code;
@property (nonatomic, readonly) CGFloat descent;
@property (nonatomic, readonly) CGFloat size;
@property (nonatomic, readonly) BOOL hasWidths;

@end

@interface CharonPDFPageText : NSObject

@property (nonatomic, readonly, copy, nullable) NSString *string;
@property (nonatomic, readonly, copy) NSArray<CharonPDFTextRun *> *runs;

+ (nullable instancetype)layoutWithRuns:(NSArray<CharonPDFTextRun *> *)drawnRuns;

- (nullable NSString *)substringForRange:(NSRange)range;

- (CGRect)boundsForRange:(NSRange)range;

- (NSUInteger)numberOfLines;
- (NSRange)lineRangeAtIndex:(NSUInteger)index;
- (NSArray<NSValue *> *)lineRangesForRange:(NSRange)range;
- (nullable CharonPDFTextRun *)runForOffset:(NSUInteger)offset;

@end

NS_ASSUME_NONNULL_END

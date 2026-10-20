#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class PDFPage;
@class RevenantPDFPageText;
@class PDFSelection;
@class PDFBorder;
@class UIColor;
@class UIFont;
@class PDFAction;
@class PDFDestination;
@class PDFOutline;

@interface PDFDocument : NSObject
- (nullable instancetype)init NS_DESIGNATED_INITIALIZER;
- (NSArray<PDFSelection *> *)findString:(NSString *)string withOptions:(NSStringCompareOptions)options;
- (nullable PDFSelection *)findString:(NSString *)string
                       fromSelection:(nullable PDFSelection *)selection
                        withOptions:(NSStringCompareOptions)options;
- (nullable instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
@property (readonly) NSUInteger pageCount;
@property (readonly, nullable) NSDictionary<NSString *, id> *documentAttributes;
- (nullable id)documentAttribute:(NSString *)attributeName;
- (nullable PDFPage *)pageAtIndex:(NSUInteger)index;
@property (readonly) BOOL isLocked;
@property (readonly) BOOL isEncrypted;
@property (readonly) BOOL allowsCopying;
- (BOOL)unlockWithPassword:(NSString *)password;
@property (readonly, nullable) NSURL *documentURL;
@property (readonly, nullable) NSData *dataRepresentation;
@property (readonly, nullable) PDFOutline *outlineRoot;
@end

extern NSString *const PDFDocumentDidUnlockNotification;

@interface PDFView : NSObject
@property (nonatomic, nullable) PDFDocument *document;
@property (nonatomic, readonly, nullable) PDFPage *currentPage;
@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic, readonly) CGFloat minScaleFactor;
@property (nonatomic, readonly) CGFloat maxScaleFactor;
@property (nonatomic) BOOL autoScales;
@property (nonatomic) NSInteger displayMode;
@property (nonatomic) NSInteger displayDirection;
@property (nonatomic) NSInteger displayBox;
@property (nonatomic, setter=enablePageShadows:) BOOL pageShadowsEnabled;
- (void)goToPage:(nullable PDFPage *)page;
@end

@interface PDFPage : NSObject
- (nullable instancetype)initWithCGPDFPage:(CGPDFPageRef)page
                                   document:(nullable PDFDocument *)document
                                      index:(NSUInteger)index;
@property (readonly, nullable, weak) PDFDocument *document;
@property (readonly) NSUInteger pageIndex;
@property (readonly) CGRect cropBox;
@property (readonly) NSInteger rotation;
@property (readonly, copy, nullable) NSString *string;
- (CGRect)boundsForBox:(CGPDFBox)box;
@property (readonly) CGRect mediaBox;
@property (readonly, copy, nullable) NSString *label;
@property (readonly) NSUInteger numberOfCharacters;
@property (readonly) NSUInteger annotationCount;
@property (readonly, copy) NSArray *annotations;
@end

@interface PDFDocument (RevenantInternals)
- (nullable CGPDFDocumentRef)revenant_CGPDFDocument;
@end

@interface PDFPage (RevenantInternals)
- (nullable CGPDFPageRef)revenant_CGPDFPage;
- (nullable RevenantPDFPageText *)revenant_textLayout;
@end

@interface PDFAnnotation : NSObject
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic) CGRect bounds;
@property (nonatomic, copy, nullable) NSString *contents;
@property (nonatomic, copy, nullable) NSString *userName;
@property (nonatomic, copy, nullable) NSDate *modificationDate;
@property (nonatomic) BOOL shouldPrint;
@property (nonatomic, weak, nullable) PDFPage *page;
@property (nonatomic, readonly, nullable) PDFAction *action;
@property (nonatomic, readonly, nullable) PDFDestination *destination;
@property (nonatomic, nullable) PDFBorder *border;
@property (readonly) BOOL hasAppearanceStream;
@property (readonly) BOOL open;
@property (readonly, nullable) NSURL *URL;
@end


@interface PDFAnnotation (RevenantInternals)
- (nullable instancetype)initWithRevenantDictionary:(CGPDFDictionaryRef)annotation
                                          onPage:(nullable PDFPage *)page;
- (CGPDFDictionaryRef)revenant_CGPDFDictionary;
- (long)revenant_flags;
@end

typedef NS_ENUM(NSInteger, PDFBorderStyle) {
    kPDFBorderStyleSolid = 0,
    kPDFBorderStyleDashed = 1,
    kPDFBorderStyleBeveled = 2,
    kPDFBorderStyleInset = 3,
    kPDFBorderStyleUnderline = 4,
};

typedef NS_ENUM(NSInteger, PDFWidgetControlType) {
    kPDFWidgetUnknownControl = -1,
    kPDFWidgetPushButtonControl = 0,
    kPDFWidgetRadioButtonControl = 1,
    kPDFWidgetCheckBoxControl = 2,
};

extern NSString *const PDFBorderKeyLineWidth;
extern NSString *const PDFBorderKeyStyle;
extern NSString *const PDFBorderKeyDashPattern;
extern NSString *const PDFAppearanceCharacteristicsKeyBackgroundColor;
extern NSString *const PDFAppearanceCharacteristicsKeyBorderColor;
extern NSString *const PDFAppearanceCharacteristicsKeyRotation;
extern NSString *const PDFAppearanceCharacteristicsKeyCaption;
extern NSString *const PDFAppearanceCharacteristicsKeyRolloverCaption;
extern NSString *const PDFAppearanceCharacteristicsKeyDownCaption;

@interface PDFBorder : NSObject
@property (nonatomic) PDFBorderStyle style;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray *dashPattern;
@property (nonatomic, readonly, copy) NSDictionary *borderKeyValues;
@end

@interface PDFBorder (RevenantInternals)
- (nullable instancetype)initWithRevenantAnnotationDictionary:(CGPDFDictionaryRef)annotation;
@end

@interface PDFAppearanceCharacteristics : NSObject
@property (nonatomic) PDFWidgetControlType controlType;
@property (nonatomic, copy, nullable) UIColor *backgroundColor;
@property (nonatomic, copy, nullable) UIColor *borderColor;
@property (nonatomic) NSInteger rotation;
@property (nonatomic, copy, nullable) NSString *caption;
@property (nonatomic, copy, nullable) NSString *rolloverCaption;
@property (nonatomic, copy, nullable) NSString *downCaption;
@property (nonatomic, readonly, copy) NSDictionary *appearanceCharacteristicsKeyValues;
@end

@interface PDFAnnotation (PDFAnnotationUtilitiesSubset)
@property (nonatomic, getter=isReadOnly) BOOL readOnly;
@property (nonatomic, getter=isMultiline) BOOL multiline;
@property (nonatomic, readonly, getter=isPasswordField) BOOL isPasswordField;
@property (nonatomic, getter=hasComb) BOOL comb;
@property (nonatomic) BOOL allowsToggleToOff;
@property (nonatomic) BOOL radiosInUnison;
@property (nonatomic, getter=isListChoice) BOOL listChoice;
@property (nonatomic) PDFWidgetControlType widgetControlType;
@property (readonly, getter=isActivatableTextField) BOOL activatableTextField;
@property (nonatomic, readonly, copy, nullable) NSString *fieldName;

@property (nonatomic, readonly, copy) NSString *buttonWidgetStateString;
@property (nonatomic, readonly) NSInteger buttonWidgetState;

@end

@interface PDFAnnotation (PDFAnnotationColours)
@property (nonatomic, readonly, copy, nullable) UIColor *backgroundColor;
@property (nonatomic, readonly, copy, nullable) UIColor *interiorColor;
@property (nonatomic, readonly, copy, nullable) UIColor *fontColor;
@property (nonatomic, readonly, copy, nullable) UIFont *font;
@end

extern const CGFloat kPDFDestinationUnspecifiedValue;

typedef NS_ENUM(NSInteger, PDFActionNamedName) {
    kPDFActionNamedNone = 0,
    kPDFActionNamedNextPage = 1,
    kPDFActionNamedPreviousPage = 2,
    kPDFActionNamedFirstPage = 3,
    kPDFActionNamedLastPage = 4,
    kPDFActionNamedGoBack = 5,
    kPDFActionNamedGoForward = 6,
    kPDFActionNamedGoToPage = 7,
    kPDFActionNamedFind = 8,
    kPDFActionNamedPrint = 9,
    kPDFActionNamedZoomIn = 10,
    kPDFActionNamedZoomOut = 11,
};

@interface PDFDestination : NSObject <NSCopying>
- (instancetype)initWithPage:(nullable PDFPage *)page atPoint:(CGPoint)point NS_DESIGNATED_INITIALIZER;
@property (nonatomic, weak, readonly, nullable) PDFPage *page;
@property (nonatomic, readonly) CGPoint point;
@property (nonatomic) CGFloat zoom;
@end

@interface PDFDestination (RevenantInternals)
- (instancetype)initWithRevenantDestinationArray:(nullable CGPDFArrayRef)array
                                    inDocument:(nullable PDFDocument *)document;
@end

@interface PDFAction : NSObject <NSCopying>
@property (nonatomic, readonly, copy, nullable) NSString *type;
@end

@interface PDFAction (RevenantInternals)
+ (nullable instancetype)revenant_actionWithDictionary:(CGPDFDictionaryRef)action
                                           inDocument:(nullable PDFDocument *)document;
- (void)revenant_setTypeName:(nullable NSString *)name;
@end

@interface PDFActionGoTo : PDFAction <NSCopying>
- (instancetype)initWithDestination:(nullable PDFDestination *)destination NS_DESIGNATED_INITIALIZER;
@property (nonatomic, strong, nullable) PDFDestination *destination;
@end

@interface PDFActionGoTo (RevenantInternals)
- (nullable instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action
                                              inDocument:(nullable PDFDocument *)document;
@end

@interface PDFActionNamed : PDFAction <NSCopying>
- (instancetype)initWithName:(PDFActionNamedName)name NS_DESIGNATED_INITIALIZER;
@property (nonatomic) PDFActionNamedName name;
@end

@interface PDFActionNamed (RevenantInternals)
- (nullable instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action;
@end

@interface PDFActionURL : PDFAction <NSCopying>
- (instancetype)initWithURL:(nullable NSURL *)url NS_DESIGNATED_INITIALIZER;
@property (nonatomic, copy, nullable) NSURL *URL;
@end

@interface PDFActionURL (RevenantInternals)
- (nullable instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action;
- (nullable instancetype)initWithRevenantLaunchDictionary:(CGPDFDictionaryRef)action
                                             inDocument:(nullable PDFDocument *)document;
@end

@interface PDFActionRemoteGoTo : PDFAction <NSCopying>
- (instancetype)initWithPageIndex:(NSUInteger)pageIndex
                         atPoint:(CGPoint)point
                         fileURL:(nullable NSURL *)url NS_DESIGNATED_INITIALIZER;
@property (nonatomic) NSUInteger pageIndex;
@property (nonatomic) CGPoint point;
@property (nonatomic, copy, nullable) NSURL *URL;
@end

@interface PDFActionRemoteGoTo (RevenantInternals)
- (nullable instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action
                                            inDocument:(nullable PDFDocument *)document;
@end

@interface PDFActionResetForm : PDFAction <NSCopying>
- (instancetype)init;
@property (nonatomic, copy, nullable) NSArray<NSString *> *fields;
@property (nonatomic) BOOL fieldsIncludedAreCleared;
@end

@interface PDFActionResetForm (RevenantInternals)
- (nullable instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action;
@end

@interface PDFOutline : NSObject
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, weak, nullable) PDFDocument *document;
@property (nonatomic, readonly, weak, nullable) PDFOutline *parent;
@property (nonatomic, readonly) NSUInteger numberOfChildren;
@property (nonatomic, readonly) NSUInteger index;
- (nullable PDFOutline *)childAtIndex:(NSUInteger)index;
@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic, readonly) BOOL isOpen;
@property (nonatomic, readonly, nullable) PDFDestination *destination;
@property (nonatomic, readonly, nullable) PDFAction *action;
@end

@interface PDFOutline (RevenantInternals)
- (nullable instancetype)initWithRevenantItem:(CGPDFDictionaryRef)item
                                  document:(nullable PDFDocument *)document
                                    parent:(nullable PDFOutline *)parent
                                     index:(NSUInteger)index;
@end

@interface PDFSelection : NSObject <NSCopying>
{
}

- (instancetype)initWithDocument:(nullable PDFDocument *)document NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSArray<PDFPage *> *pages;
@property (nonatomic, copy, nullable) UIColor *color;
@property (nonatomic, readonly, nullable) NSString *string;
@property (nonatomic, readonly, nullable) NSAttributedString *attributedString;

- (NSUInteger)numberOfTextRangesOnPage:(PDFPage *)page;
- (NSRange)rangeAtIndex:(NSUInteger)index onPage:(PDFPage *)page;
- (CGRect)boundsForPage:(PDFPage *)page;
- (NSArray<PDFSelection *> *)selectionsByLine;

- (void)addSelection:(PDFSelection *)selection;
- (void)addSelections:(NSArray<PDFSelection *> *)selections;
- (void)extendSelectionAtEnd:(NSInteger)succeed;
- (void)extendSelectionAtStart:(NSInteger)precede;
- (void)extendSelectionForLineBoundaries;
@end

@interface PDFSelection (RevenantInternals)
- (void)revenant_addSpanOnPage:(PDFPage *)page range:(NSRange)range;
@end

NS_ASSUME_NONNULL_END

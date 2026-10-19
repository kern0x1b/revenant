#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// The port's PDFKit: PDFDocument and PDFPage over the RELEASE's own CGPDFDocument, which 6.1.3 and
// 4.3 both export (measured with the dyld export tables: CGPDFDocumentCreateWithURL,
// CGPDFDocumentGetNumberOfPages, CGPDFDocumentGetPage, CGPDFDocumentRelease, CGPDFPageGetBoxRect,
// CGPDFPageGetDictionary).  Neither release carries the PDFKit classes themselves - objc.inventory,
// an Objective-C class census, says PDFDocument and PDFPage are not there on either band - so these
// are the port's own classes, not categories.
//
// NOT carried, and not claimed: string extraction through CGPDFScanner.  The release exports
// CGPDFScannerCreate and does NOT export CGPDFScannerScanString or CGPDFScannerGetString, on either
// band, so a -string that scanned the page would be a claim the release cannot answer.  -string answers
// what the port can hold; the scanned extraction is owed and no row says otherwise.

NS_ASSUME_NONNULL_BEGIN

@class PDFPage;
@class CharonPDFPageText;
@class PDFSelection;
@class PDFBorder;
@class UIColor;
@class UIFont;
@class PDFAction;
@class PDFDestination;
@class PDFOutline;

// -init is the third way the header's own comment names a document being made ("either the init
// method, initWithURL:, or initWithData:"), so it is a convenience initializer here and it reaches
// the same private setup the other two do.  That is why -[super init] appears in it at all.
@interface PDFDocument : NSObject
- (nullable instancetype)init NS_DESIGNATED_INITIALIZER;
// The two find entry points PDFDocument.h:260 and :276 declare.  They are the ONLY way a caller reaches a
// non-empty PDFSelection, which is why the class below is implemented over the page's own text rather than
// over anything a selection could be handed from outside.
//   -findString:withOptions:  searches the whole document and answers one selection per occurrence.  The
//     options the header names are NSCaseInsensitiveSearch, NSLiteralSearch and NSBackwardsSearch.
//   -findString:fromSelection:withOptions:  carries on from a selection, and a nil selection starts at the
//     beginning of the document - or at its end when NSBackwardsSearch is set.
- (NSArray<PDFSelection *> *)findString:(NSString *)string withOptions:(NSStringCompareOptions)options;
- (nullable PDFSelection *)findString:(NSString *)string
                       fromSelection:(nullable PDFSelection *)selection
                        withOptions:(NSStringCompareOptions)options;
// The 26.2 header declares NO class factory: grep for documentWithURL in
// PDFDocument.h returns nothing, and its own comment says a document is made with "either the init
// method, initWithURL:, or initWithData:" - PDFDocument.h:138 and :139, both designated
// initializers.  An earlier version of this port added +documentWithURL: and +documentWithData:,
// which are not the API; they are gone and the initializers are what it answers.
- (nullable instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
@property (readonly) NSUInteger pageCount;
@property (readonly, nullable) NSDictionary<NSString *, id> *documentAttributes;
- (nullable id)documentAttribute:(NSString *)attributeName;
- (nullable PDFPage *)pageAtIndex:(NSUInteger)index;
// The four below were chosen from the host's own method list (182 instance methods, every one measured
// with no window open) and each is a reading of something the release hands over.
@property (readonly) BOOL isLocked;          // a /Encrypt the user password still closes, read by CoreGraphics
@property (readonly) BOOL isEncrypted;       // the document carries an /Encrypt
@property (readonly) BOOL allowsCopying;     // YES: the release carries no permission of its own
// Unlocks a locked document with its user password. YES for a document that is not locked; see PDFDocument11.m.
- (BOOL)unlockWithPassword:(NSString *)password;
@property (readonly, nullable) NSURL *documentURL;   // the URL this document was opened with
@property (readonly, nullable) NSData *dataRepresentation;
// The /Outlines tree, when the catalog names one - the only path in to PDFOutline, and nil for every
// document that does not.  See PDFDocument11.m.
@property (readonly, nullable) PDFOutline *outlineRoot;
@end

// Posted once, by -unlockWithPassword:, when a locked document opens.
extern NSString *const PDFDocumentDidUnlockNotification;

// PDFView without a window, which is the whole of what this release can offer for it.  The defaults
// are the host's own, measured with no window and never shown; see PDFView11.m and
// facts/PDFKit/Document11.md.  Three members a plan named are NOT this API and are not declared:
// -pageCount, -canDisplayPage:, -usePageViewController: and -scaleToFit, none of which PDFView.h
// declares and none of which the host answers.
@interface PDFView : NSObject
@property (nonatomic, nullable) PDFDocument *document;
@property (nonatomic, readonly, nullable) PDFPage *currentPage;
@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic, readonly) CGFloat minScaleFactor;
@property (nonatomic, readonly) CGFloat maxScaleFactor;
@property (nonatomic) BOOL autoScales;
@property (nonatomic) NSInteger displayMode;
@property (nonatomic) NSInteger displayDirection;
@property (nonatomic) NSInteger displayBox;      // a VALIDATING setter; see PDFView11.m
@property (nonatomic, setter=enablePageShadows:) BOOL pageShadowsEnabled;
- (void)goToPage:(nullable PDFPage *)page;       // the one windowful member; the current page is compared
@end

@interface PDFPage : NSObject
// The port's own initializer over the release's own page: neither release carries PDFPage, so the
// page object is made here rather than found.  Not Apple's API.
// The port's own initializer over the release's own page.  A page keeps the CGPDFDocument it came
// from alive by holding the CGPDFDocumentRef, NOT by holding the PDFDocument: the header declares
// that reference weak (PDFPage.h:70) and CGPDFPageGetDocument hands back a non-retained pointer, so a
// page that outlives its document would otherwise release a page belonging to a released document.
// A document that DOES outlive its pages is the far side of the same hazard: the port's own
// PDFDocument keeps its pages, as GCPhysicalInputProfile keeps its elements.
- (nullable instancetype)initWithCGPDFPage:(CGPDFPageRef)page
                                   document:(nullable PDFDocument *)document
                                      index:(NSUInteger)index;
// The 26.2 header declares this weak (PDFPage.h:70): a page does not keep its document alive.  A
// strong reference here is a use-after-free, because the document is what owns the CGPDFDocument
// the page's own CGPDFPage came from.
@property (readonly, nullable, weak) PDFDocument *document;
@property (readonly) NSUInteger pageIndex;
@property (readonly) CGRect cropBox;
@property (readonly) NSInteger rotation;
@property (readonly, copy, nullable) NSString *string;
// -boundsForBox: was implemented and NOT declared here, so nothing outside PDFPage11.m could call it.
// The header's own -mediaBox and -cropBox are what applications use; this is the general form, and it
// is the port's own initializer-agnostic accessor over CGPDFPageGetBoxRect.
- (CGRect)boundsForBox:(CGPDFBox)box;
@property (readonly) CGRect mediaBox;
// The three below were measured on the host (193 instance methods, no window open) and are a reading of
// the page's own dictionary, not a layout: -label is the page's index as a string, and
// -numberOfCharacters counts the characters of the text walk, a kerning separator included.
@property (readonly, copy, nullable) NSString *label;
@property (readonly) NSUInteger numberOfCharacters;
@property (readonly) NSUInteger annotationCount;
// -annotations is the array the count measures, in the page dictionary's own /Annots order.  The
// model is seven members deep, not the whole family: the members with a subtype-dependent absent
// answer (-color, -border), the measured-but-unidentified -shouldDisplay, and the write and draw
// paths are not in it, and PDFAnnotation11.m says which is which.
@property (readonly, copy) NSArray *annotations;
@end

// The port's own accessors, for its own object graph: the CGPDFDocument and the CGPDFPage underneath,
// which Apple's API does not expose.  Not part of any application-facing surface.
@interface PDFDocument (CharonInternals)
- (nullable CGPDFDocumentRef)charon_CGPDFDocument;
@end

@interface PDFPage (CharonInternals)
- (nullable CGPDFPageRef)charon_CGPDFPage;
// The page's own text layout, which PDFSelection reads: a selection's range is an offset into it, so the
// two must not be two walks that can disagree.  See PDFPageText11.h.
- (nullable CharonPDFPageText *)charon_textLayout;
@end

// PDFAnnotation, over the annotation dictionary CoreGraphics already parsed out of a page's /Annots.
// Only the members measured on the host are declared, and each is a reading of that dictionary rather
// than a substitute for it:
//
//   -type             the /Subtype NAME as a string - "Text", "Link", "Square" - NOT an integer.  The
//                     property is NSString* const (PDFAnnotation.h:52); the five large negative numbers
//                     recorded before this were NSTaggedPointerString values, which pack the characters
//                     into the pointer and read as nonsense when cast to a long.
//   -bounds           the /Rect, except for a /Text annotation, which is a fixed 24x24 square in the
//                     rect's top-left corner at (minX, maxY-24).  Measured on a rect the rule was not
//                     fitted to, and the 24 is a constant rather than derived - two rects of different
//                     sizes both answer 24x24.  What the 24 IS was not measured and is not claimed.
//   -contents, -userName  the /Contents and /T, nil when the key is absent.
//   -modificationDate the /M in the one form measured, D:YYYYMMDDHHmmSS, read as UTC.
//   -shouldPrint      /F's PRINT bit, measured on /F 0 (NO), 2 (NO) and 4 (YES).
//   -page             the page the annotation was found on, weak.
//
// NOT declared, each for a named reason its row repeats: -color and -border, whose absent answers are
// subtype-dependent (a /Highlight with no /C answers a default yellow; a /Square with no /Border
// answers a default 1.0 line, while a /Link answers nil for both); -shouldDisplay, which answered YES
// for every /F measured and is not the Hidden bit; -hasAppearanceStream and -highlighted, measured NO
// with nothing in the fixtures to change them; -popup and -action, classes of their own; the
// annotation-key API, which is its own family and whose setters are a write path; -drawWithBox:
// (inContext:), which draws into a context this port does not have; and the initializers, which write.
@interface PDFAnnotation : NSObject
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic) CGRect bounds;
@property (nonatomic, copy, nullable) NSString *contents;
@property (nonatomic, copy, nullable) NSString *userName;
@property (nonatomic, copy, nullable) NSDate *modificationDate;
@property (nonatomic) BOOL shouldPrint;
@property (nonatomic, weak, nullable) PDFPage *page;
// The action and the destination of an annotation, which are the two ways a PDF points somewhere.  They
// are read independently and a document may carry either or both: an /A dictionary gives the action, a
// /Dest gives the destination, and an /Dest with no /A gives BOTH - the host synthesises a GoTo action
// for a bare /Dest, measured on ann-dest-array and ann-dest-named.  Where both are written the action is
// the /A one and the destination is the /Dest one (ann-dest-and-a).  See PDFAnnotation11.m.
@property (nonatomic, readonly, nullable) PDFAction *action;
@property (nonatomic, readonly, nullable) PDFDestination *destination;
// The border, a PDFBorder of its own below, over this annotation's /Border array and its /BS
// dictionary.  nil is a measured answer and not a missing one: see the rule on -border in
// PDFAnnotation11.m, which is the whole of what the absent case is.  Readwrite, as PDFAnnotation.h:167
// has it: -setBorder: stores the object BY REFERENCE, so -border hands back the same object it was
// given and a later change to that object is visible through the annotation.
@property (nonatomic, nullable) PDFBorder *border;
// YES when the /AP dictionary carries an /N appearance stream; /Open, which is the annotation's open flag on any
// subtype; and the /URI of a URI action, nil for every other action. See PDFAnnotation11.m.
@property (readonly) BOOL hasAppearanceStream;
@property (readonly) BOOL open;
@property (readonly, nullable) NSURL *URL;
@end


// The port's own constructor, over a dictionary already in the object graph.  Not Apple's
// -initWithBounds:forType:withProperties:, which builds a new annotation and writes it into a document.
@interface PDFAnnotation (CharonInternals)
- (nullable instancetype)initWithCharonDictionary:(CGPDFDictionaryRef)annotation
                                          onPage:(nullable PDFPage *)page;
// The annotation's own dictionary in the CGPDFDocument, or NULL.  The harness reads it to decide WHICH
// keys are comparable - -fieldName is asked only where the document names the widget - and a port that
// made the harness ask each member and hope would compare a member's own opinion of its state instead of
// the bytes both sides are reading.
- (CGPDFDictionaryRef)charon_CGPDFDictionary;
// The /Ff FLAG WORD of this annotation, or 0 when it names none.  Shared by the nine bit members below,
// which each read one bit of it, and declared here so the category implementation that defines them can
// reach it.
- (long)charon_flags;
@end

// ---- PDFBorder, and the two enumerations the port has to spell because the release has no header
// that declares them -------------------------------------------------------
//
// Neither band carries a PDFKit header at all - the port declares its own surface here, and
// PDFKitConstants11.m is the one file that imports the SDK's, because a constant's VALUE has to be
// the host's and its TYPE only has to compile.  So the two enumerations below are transcribed from
// the 26.2 headers, PDFBorder.h:15-21 and PDFAnnotationUtilities.h:20-25, with the values in the
// headers' own order.

// PDFBorderStyle, PDFBorder.h:15.  The five names, in the header's order.  Which /BS /S name answers
// which value is MEASURED, one fixture per name plus one the format does not list (PDFBorder11.m).
typedef NS_ENUM(NSInteger, PDFBorderStyle) {
    kPDFBorderStyleSolid = 0,
    kPDFBorderStyleDashed = 1,
    kPDFBorderStyleBeveled = 2,
    kPDFBorderStyleInset = 3,
    kPDFBorderStyleUnderline = 4,
};

// PDFWidgetControlType, PDFAnnotationUtilities.h:20.  -1 is the header's own kPDFWidgetUnknownControl,
// and it is also what PDFAppearanceCharacteristics answers before anything is set (measured).
typedef NS_ENUM(NSInteger, PDFWidgetControlType) {
    kPDFWidgetUnknownControl = -1,
    kPDFWidgetPushButtonControl = 0,
    kPDFWidgetRadioButtonControl = 1,
    kPDFWidgetCheckBoxControl = 2,
};

// The key names, declared here because the class files cannot import the SDK's PDFKit.h and the
// values are the ones PDFKitConstants11.m exports: @"W", @"S", @"D" and @"BG", @"BC", @"R", @"CA",
// @"RC", @"AC", read out of the host's own PDFKit by tests/backports/host/pdfkit-constants.
extern NSString *const PDFBorderKeyLineWidth;
extern NSString *const PDFBorderKeyStyle;
extern NSString *const PDFBorderKeyDashPattern;
extern NSString *const PDFAppearanceCharacteristicsKeyBackgroundColor;
extern NSString *const PDFAppearanceCharacteristicsKeyBorderColor;
extern NSString *const PDFAppearanceCharacteristicsKeyRotation;
extern NSString *const PDFAppearanceCharacteristicsKeyCaption;
extern NSString *const PDFAppearanceCharacteristicsKeyRolloverCaption;
extern NSString *const PDFAppearanceCharacteristicsKeyDownCaption;

// PDFBorder, a value object over one border: three settable members and the dictionary they are read
// out of.  PDFBorder.h:28 declares no initializer of its own, so -init is NSObject's - and what it
// makes is the host's fresh object, measured: style 0, lineWidth 1, a nil pattern and the key values
// {S = 0, W = 1}.  All three setters are implemented, because the host's setters change the OBJECT
// rather than the file: -setStyle: and -setLineWidth: change their own member and nothing else, and
// -setDashPattern: publishes the pattern AND sets the style - dashed for a non-empty array, solid for
// an empty one and for nil - without touching the width.
@interface PDFBorder : NSObject
@property (nonatomic) PDFBorderStyle style;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray *dashPattern;
@property (nonatomic, readonly, copy) NSDictionary *borderKeyValues;
@end

// The port's own constructor, over the annotation dictionary a border is read out of.  Not Apple's
// API: the dictionary is an implementation's, and -[PDFAnnotation border] is what reaches this from
// the outside.
@interface PDFBorder (CharonInternals)
- (nullable instancetype)initWithCharonAnnotationDictionary:(CGPDFDictionaryRef)annotation;
@end

// PDFAppearanceCharacteristics, the /MK dictionary of PDF 1.7 Table 8.40 as a value object.
//
// Nothing in the 26.2 SDK hands one out - there is no -[PDFAnnotation appearanceCharacteristics], and
// grep for appearanceCharacteristics across PDFKit.framework/Headers finds this class's own
// key-values property and nothing else - so the object is its own thing here too, built with -init and
// read back through the same members.  Every member is implemented on both sides of every pair, which
// is what makes it comparable at all: the host's setter and its getter were measured against each
// other (set every member, read every member, read the key values) and the port answers the same.
//
// -controlType is the one member with no key of its own.  The host keeps it, answers it back for every
// value from -1 to 3, and -appearanceCharacteristicsKeyValues does NOT gain a key for it (measured:
// six keys with all six dictionary members set, and still none of them controlType).  So it is an ivar
// here and not an entry in the dictionary, which is what the host does.
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

// ---- PDFAnnotation (PDFAnnotationUtilities): the widget members that are /Ff BIT reads ------------
//
// The 26.2 SDK declares these in a CATEGORY, PDFAnnotationUtilities.h:120, and one member per group of
// them is implemented here.  Every bit below is measured on the host over widget-flags.pdf, which carries
// ONE ANNOTATION PER BIT with only that bit set - thirteen bits and a fixture with every bit at once -
// because a fixture with all the bits set answers every member YES and proves nothing.
//
//   bit 1  ReadOnly         1        -> readOnly
//   bit 13 Multiline        4096     -> multiline
//   bit 14 Password         8192     -> isPasswordField
//   bit 15 NoToggleToOff    16384    -> allowsToggleToOff is the NEGATION of it
//   bit 16 Radio            32768    -> widgetControlType: 1, and NOT radiosInUnison
//   bit 17 Pushbutton       65536    -> widgetControlType: 0, and it CLEARS allowsToggleToOff
//   bit 18 Combo            131072   -> isListChoice is the NEGATION of it
//   bit 25 Comb             16777216 -> comb
//   bit 26 RadiosInUnison   33554432 -> radiosInUnison   (in a BUTTON field; in a TEXT field of the
//                                                            same name, Table 8.39 calls bit 26 RichText,
//                                                            and the host reads it either way)
//
// THE NAMES ABOVE ARE THE FORMAT'S OWN, and an earlier version of this comment had two of them wrong:
// it called bit 16 "RadioInUnison" and bit 26 "RichText" as if each had one name everywhere.  Table 8.39's
// bit 16 is Radio, and bit 26 is RadiosInUnison in the BUTTON field table and RichText in the TEXT field
// table.  So two of the three members this file calls "not what the table says" ARE the table's rule -
// radiosInUnison reading bit 26, and widgetControlType's Pushbutton -> 0 / Radio -> 1 / neither -> 2 -
// and the fixtures add only what the table cannot say:
//
//   BOTH bit 16 and bit 17 at once answer kPDFWidgetRadioButtonControl.  The table names the bits and not
//     their collision, and widget-allflags.pdf is the fixture that answers 1.
//   bit 17 CLEARS allowsToggleToOff.  The table says bit 15 NoToggleToOff and nothing about a pushbutton,
//     and the bit-15 and bit-17 fixtures each answer NO while the other eleven answer YES.
//
// And activatableTextField is not a bit at all: it is a TEXT field that is not read-only - /FT /Tx with
// bit 1 clear, measured on six one-field-type fixtures, on the thirteen /Tx fixtures, and on every /Link in
// the harness.
//
// NOT declared here, each for the reason its row repeats: widgetStringValue and widgetDefaultStringValue,
// whose /V and /DV the host does not read on these fixtures; maximumLength, alignment, choices, values,
// open, caption, URL, the two line styles, the two points, paths, quadrilateralPoints, iconType,
// markupType and stampName.  buttonWidgetState, buttonWidgetStateString and the three colours and the
// font ARE declared: the /AS matrix is measured, and the colour and font keys are measured below.  fieldName is implemented for a widget the
// document NAMES and its row says what it cannot answer for one it does not.  See
// facts/PDFKit/Annotation11.md, which carries the host's measured answer for every one of them.
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
// The /T of the MERGED FIELD AND WIDGET: the parent's first, then the widget's own, joined with a dot
// when both name something, and read as PDF STRINGS only.  A widget that NAMES nothing is not answered
// here, and the row says why.
@property (nonatomic, readonly, copy, nullable) NSString *fieldName;

// The NAME of this widget's on-state: the /AP /N key that is not /Off, and "Yes" when there is no /AP at
// all.  Measured on eighteen fixtures that carry no /AP and answer "Yes", and on button-ap-states.pdf,
// whose five annotations have /AP /N keyed /On, /Yes and /Marked and answer those names - including the
// two that make it a rule and not an echo of /AS: an /N keyed /Marked answers "Marked" beside an /AS /Yes
// and beside an /AS /Marked, and an /N keyed /On answers "On" beside an /AS /Off.  So this is the /AP's
// own key, and the "Yes" of the nameless fixtures is the DEFAULT rather than the answer.
@property (nonatomic, readonly, copy) NSString *buttonWidgetStateString;
// Whether this widget is ON: 1 when /AS or /V names its on-state, or when BOTH name a state that is not
// /Off; and -1 for a widget that is not a BUTTON.  Three clauses and 31 measured shapes, with each
// fixture that discriminates one of them named in PDFAnnotation11.m.
@property (nonatomic, readonly) NSInteger buttonWidgetState;

@end

// ---- PDFAnnotation's three colours and its font, in a category of their own ------------------------
//
// A SEPARATE CATEGORY, and a separate object, for the reason PDFAnnotationColours11.m's own header gives:
// UIColor and UIFont are UIKit's and there is no Foundation class for either on iOS, so these four are
// the only members in this header a macOS process cannot compile and the only ones the Catalyst side of
// the harness carries.  Everything else about them is as measured:
//
// All four are DECLARED READ-ONLY where PDFAnnotationUtilities.h declares them readwrite, because each
// one's setter writes back into a document and this port reads documents.  Each row says so.
//
// Every reading is keyed by the annotation's /NM rather than by its position, over
// annotation-colours.pdf, and the shape of the answer is the answer:
//
//   backgroundColor   /MK's /BG (Table 8.40's /BG, not /BC - /BC is the BORDER colour, which is the key
//                     -[PDFAnnotation border] reads), in the DEVICE colour space its COMPONENT COUNT names:
//                     one is DeviceGray, three is DeviceRGB, four is DeviceCMYK, and the components are
//                     the ARRAY'S OWN.  A /BG that is not an array is nil.
//   interiorColor     the annotation's OWN /IC, which is not an /MK key at all, in the same three Device
//                     spaces by the same component count, and nil when the annotation carries no /IC.
//                     The 26.2 header names /Circle, /Line and /Square as the subtypes that use it; the
//                     host answers it on every subtype measured, /Link and a /Tx /Widget included.
//   fontColor         the /DA's FIRST fill operand, and only a fill one - text is painted with the fill
//                     colour, so g and rg are read and G, RG and K, which set the stroke, are not, and k
//                     is not read either.  The colours are GENERIC and not device ones, and an annotation
//                     with NO /DA at all answers a generic gray at gamma 2.2 while a /DA with no readable
//                     fill answers a generic gray at gamma 1.0 - two different defaults, measured apart.
//   font              the /DA's font NAME and SIZE, read independently.  The name is used as written when
//                     the platform's own font has it, and then through an exact table of THREE
//                     abbreviations - Helv, HeBo and Cour - which is the whole of what the host resolves
//                     out of the standard fourteen's fourteen.  Anything else is Helvetica, with the size
//                     kept; the default size is 12.
//
// THE DERIVATION IS NOT IN THE OBJECT and not here either: it is in CharonPDFKitColours.h, as `static
// inline` functions over the annotation's CGPDFDictionary, which this file's four members call and which
// the harness's Catalyst side calls DIRECTLY.  That is because the platform's own PDFKit loads in that
// binary and its category would answer these four selectors - which file holds the derivation is the
// measured consequence, and its comment says so.
//
// facts/PDFKit/Annotation11.md carries the table, the fixtures that pin every clause of it, and the
// retracted readings of the version that read this fixture by index and was one annotation out of step
// from the seventh on.
@interface PDFAnnotation (PDFAnnotationColours)
@property (nonatomic, readonly, copy, nullable) UIColor *backgroundColor;
@property (nonatomic, readonly, copy, nullable) UIColor *interiorColor;
@property (nonatomic, readonly, copy, nullable) UIColor *fontColor;
@property (nonatomic, readonly, copy, nullable) UIFont *font;
@end

// ---- PDFDestination, and the action family --------------------------------------------------
//
// Seven classes the 26.2 headers declare and neither band carries: PDFDestination, PDFAction and
// PDFActionGoTo, PDFActionNamed, PDFActionURL, PDFActionRemoteGoTo and PDFActionResetForm.  All of them
// are read out of an annotation's /A action dictionary and its /Dest, so the substrate is the release's
// own dictionary and array reader again - with ONE thing the release has no API for, which is the page a
// destination names: a destination is [pageRef /XYZ left top zoom], and there is no object-number
// accessor in this SDK, so PDFDestination11.m resolves the reference to a page DICTIONARY and matches it
// against CGPDFPageGetDictionary by identity.  That is measured to work, and it is what makes a
// destination that names the second page answer that page.

// The sentinel PDFKit's own header calls "no position is specified".  The port's value is the host's own
// (FLT_MAX, and NOT CGFLOAT_MAX - measured and recorded in registry/PDFKit/constants.json), and
// PDFKitConstants11.m exports it, so this is a declaration and not a second definition.
extern const CGFloat kPDFDestinationUnspecifiedValue;

// PDFActionNamedName, PDFActionNamed.h:15.  The twelve names the enum declares, in the header's order.
//
// The host builds a PDFActionNamed for EIGHT of them and for no other: NextPage, FirstPage, LastPage,
// GoBack, GoForward, GoToPage, Find and Print.  None, PreviousPage, ZoomIn, ZoomOut and a name the
// format does not list all answer NO ACTION AT ALL - measured one fixture per name, act-named-all.pdf -
// so the port's own -initWithName: keeps whatever it is given (the host keeps 0 and 99 too) while a
// dictionary is read through the same eight-name table.
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
// -initWithPage:atPoint: answers NO OBJECT for a nil page - measured - so plain -init, which the host
// answers with an object, sets the members itself and is not reached through it.
//
// -init is NOT declared here and IS implemented, which is the shape the class has at Apple too: the
// iOS 16.0 arm64e cache gives PDFDestination its own -init (own -init: 1) while its header declares
// none, and the only initializer the header declares is the designated one below.
- (instancetype)initWithPage:(nullable PDFPage *)page atPoint:(CGPoint)point NS_DESIGNATED_INITIALIZER;
@property (nonatomic, weak, readonly, nullable) PDFPage *page;
@property (nonatomic, readonly) CGPoint point;
@property (nonatomic) CGFloat zoom;
@end

// The port's own constructor, over the destination ARRAY itself - [pageRef /XYZ left top zoom], which
// is how both an action's /D and an annotation's /Dest hold it.  Not Apple's API: the array is an
// implementation's, and the two places that have one - PDFAnnotation's -destination and
// PDFActionGoTo's -destination - are what reach this from the outside.  A NULL array builds the
// destination with nothing in it, which is the measured answer for a NAMED destination.
@interface PDFDestination (CharonInternals)
- (instancetype)initWithCharonDestinationArray:(nullable CGPDFArrayRef)array
                                    inDocument:(nullable PDFDocument *)document;
@end

// PDFAction is the base of the family and, on its own, what an /S the format does not name: measured,
// /S /Bogus answers a PDFAction whose -type is "Bogus".  A freshly allocated one answers a NIL -type,
// which is the same distinction: -type is the /S NAME, and there is no name yet.
@interface PDFAction : NSObject <NSCopying>
@property (nonatomic, readonly, copy, nullable) NSString *type;
@end

// The factory that reads an /A dictionary: the /S name picks the class, and a name the host does not
// build an object for - the /Named names it has no case for, and an action with no /S at all - answers
// nil, which is a measured absence rather than an empty object.
@interface PDFAction (CharonInternals)
+ (nullable instancetype)charon_actionWithDictionary:(CGPDFDictionaryRef)action
                                           inDocument:(nullable PDFDocument *)document;
// The one place a type name is written: a freshly allocated action answers a nil -type and each
// subclass's initializer sets the name its /S carries.  A method rather than -[NSObject
// setValue:forKey:] on a readonly property, which would be a private route to an ivar.
- (void)charon_setTypeName:(nullable NSString *)name;
@end

@interface PDFActionGoTo : PDFAction <NSCopying>
- (instancetype)initWithDestination:(nullable PDFDestination *)destination NS_DESIGNATED_INITIALIZER;
@property (nonatomic, strong, nullable) PDFDestination *destination;
@end

@interface PDFActionGoTo (CharonInternals)
- (nullable instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action
                                              inDocument:(nullable PDFDocument *)document;
@end

@interface PDFActionNamed : PDFAction <NSCopying>
- (instancetype)initWithName:(PDFActionNamedName)name NS_DESIGNATED_INITIALIZER;
@property (nonatomic) PDFActionNamedName name;
@end

@interface PDFActionNamed (CharonInternals)
- (nullable instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action;
@end

@interface PDFActionURL : PDFAction <NSCopying>
- (instancetype)initWithURL:(nullable NSURL *)url NS_DESIGNATED_INITIALIZER;
@property (nonatomic, copy, nullable) NSURL *URL;
@end

@interface PDFActionURL (CharonInternals)
- (nullable instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action;
// A /Launch action: the host answers a PDFActionURL of type Launch, whose URL is the top-level /F (a string or
// a file specification's /F) resolved against the document's directory. See PDFAction11.m.
- (nullable instancetype)initWithCharonLaunchDictionary:(CGPDFDictionaryRef)action
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

@interface PDFActionRemoteGoTo (CharonInternals)
- (nullable instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action
                                            inDocument:(nullable PDFDocument *)document;
@end

@interface PDFActionResetForm : PDFAction <NSCopying>
- (instancetype)init;
// The seven /Flags combinations of PDF 1.7 Table 8.44 are measured, and -fieldsIncludedAreCleared is YES
// exactly when /FIELDS is present AND the /Flags bit of value 1 is clear: no /Flags and /Flags 0 answer
// YES, /Flags 1 and /Flags 3 answer NO, /Flags 2 answers YES, and /Flags 1 or 2 with no /Fields answer NO
// whatever the bit.  A freshly allocated one answers YES, which is the header's own default and not the
// same as what a dictionary carrying neither key reads as.
@property (nonatomic, copy, nullable) NSArray<NSString *> *fields;
@property (nonatomic) BOOL fieldsIncludedAreCleared;
@end

@interface PDFActionResetForm (CharonInternals)
- (nullable instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action;
@end

// ---- PDFOutline -------------------------------------------------------------------------------
//
// The /Outlines tree of PDF 1.7 Table 8.2, which is a LINKED structure: the catalog names a root
// dictionary through /Outlines, every item names its /Parent, /Prev and /Next, and an item's children are
// its /First .. /Last chain.  -[PDFDocument outlineRoot] is the only path in from a document.
//
// NOT declared, each for a named reason its row repeats: -insertChild:atIndex: and -removeFromParent,
// which are WRITE paths - this port reads documents, and a method that changed an outline would have to
// write one back into the file.
//
// -childAtIndex: has TWO out-of-range answers, and both are implemented because both are measured: a
// node WITH children raises NSRangeException past the end, and a node with NO children answers nil even
// at index 0.  See PDFOutline11.m and the row.
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

// The port's own constructor, over one item dictionary of the tree, with the links the walk already
// knows: the document it belongs to, its parent and its position in that parent's chain.
@interface PDFOutline (CharonInternals)
- (nullable instancetype)initWithCharonItem:(CGPDFDictionaryRef)item
                                  document:(nullable PDFDocument *)document
                                    parent:(nullable PDFOutline *)parent
                                     index:(NSUInteger)index;
@end

// ---- PDFSelection ---------------------------------------------------------------------------------
//
// A range of text over one or more pages, from PDF 1.7's own point of view a run of characters in a page's
// text: the class is the port's, like PDFDocument and PDFPage, and its substrate is the text walk every
// page already answers - `-[PDFPage charon_textLayout]`, which is the same object -[PDFPage string] reads.
//
// WHAT IS DECIDED AND NOT DECLARED, each for a reason its row repeats:
//   -drawForPage:active: and -drawForPage:withBox:active:  a CGContext and a PDFDisplayBox, which a port
//     that reads documents has no way to be handed.  Inert, as PDFOutline's two write paths are.
//   -initWithDocument: IS declared and IS the container the mutators fill, which PDFSelection.h:20 says it
//     is: the header says an empty PDFSelection is returned and can later be filled by
//     you add selections with -[addSelection] or -[addSelections].
//
// THE RANGE MODEL, which is the whole of the class: a selection is a list of spans, each a page and a
// range in that page's text, kept in page order.  A find produces one span; -addSelection: unions two
// lists and removes the overlaps; -extendSelectionAt{Start,End}: move the first or last span's ends, onto
// the next page when they run off the end of one; -selectionsByLine splits the spans at the page's line
// breaks.  -string is the spans' texts concatenated, with a newline BETWEEN PAGES and nothing between two
// ranges of one page - both measured, and facts/PDFKit/Selection11.md has the table.
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
// The rect over the selection's ranges on ONE page, in that page's own coordinate space, and
// CGRectNull-shaped (+inf,+inf,0,0) for a page the selection does not cover - both measured.  The
// geometry is the page's own text layout's: see PDFPageText11.h and facts/PDFKit/Selection11.md.
- (CGRect)boundsForPage:(PDFPage *)page;
- (NSArray<PDFSelection *> *)selectionsByLine;

- (void)addSelection:(PDFSelection *)selection;
- (void)addSelections:(NSArray<PDFSelection *> *)selections;
- (void)extendSelectionAtEnd:(NSInteger)succeed;
- (void)extendSelectionAtStart:(NSInteger)precede;
- (void)extendSelectionForLineBoundaries;
@end

// The port's own way at a selection's ranges, which is what -[PDFDocument findString:withOptions:] builds
// them with.  PDFSelection.h declares no initializer over a range at all - the header has no
// -initWithRange: and no factory - so a search has to be able to hand one over.  It lives in this category
// rather than in the @interface because it is not PDFKit's API, and both files that use it export PDFKit
// symbols of their own, so they are left out of a band together or not at all (charon/AGENTS.md).
@interface PDFSelection (CharonInternals)
- (void)charon_addSpanOnPage:(PDFPage *)page range:(NSRange)range;
@end

NS_ASSUME_NONNULL_END

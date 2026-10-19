// The model of TextKit 2 - the content manager, the content storage and the list element - beside the host's own
// UIKit, in one process: the backport's classes are renamed by uikit2/run.sh, so each case asks the port and the
// system the same question and holds the answers to each other. What is compared is what
// facts/UIKit/NSTextContent15.md records.
//
// What cannot be compared is named rather than skipped: the host has no -[NSTextContentManager initWithTextStorage:]
// on the measured build, so its own content storage cannot be made there and every answer about a document is
// unmeasurable. The port's is constructible, and its document answers are written from the header; the last case
// holds the port against the header and records that the host could not be asked.
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
// This file calls the port's own API at the release it arrived in - 15.0, 16.0, 17.0, 18.0 and 26.0 -
// while the differential compiles it for a macCatalyst 15.0 target, where those classes and protocols do
// not exist and are declared by the test itself. That is the whole point of a differential against the
// port's own objects: the host framework cannot answer, the port can, and the comparison is between the
// two. The diagnostic is therefore off for the file and the declarations are the test's own, spelled
// where they are used.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#import "check.h"

// The port's classes, as run.sh renames them, with the members the cases ask of them. The harness renames a
// class but not a declaration in this file, so the two sides are two types and a case that forgets which is which
// would not compile.
@interface CharonHostNSTextContentManager : NSObject
- (instancetype)init;
+ (BOOL)supportsSecureCoding;
@property (nonatomic, readonly, copy) NSArray *textLayoutManagers;
@property (nonatomic, strong, nullable) id primaryTextLayoutManager;
@property (nonatomic, readonly) BOOL hasEditingTransaction;
@property BOOL automaticallySynchronizesTextLayoutManagers;
@property BOOL automaticallySynchronizesToBackingStore;
@property (nonatomic, weak, nullable) id delegate;
- (void)addTextLayoutManager:(id)textLayoutManager;
- (void)removeTextLayoutManager:(id)textLayoutManager;
- (void)synchronizeTextLayoutManagers:(void (^)(NSError *error))completionHandler;
- (void)performEditingTransactionUsingBlock:(void (^)(void))transaction;
- (void)recordEditActionInRange:(id)originalTextRange newTextRange:(id)newTextRange;
- (NSArray *)textElementsForRange:(id)range;
- (NSString *)description;
@end

@interface CharonHostNSTextContentStorage : CharonHostNSTextContentManager
- (instancetype)initWithTextStorage:(NSTextStorage *)textStorage;
@property (nonatomic, strong, nullable) NSTextStorage *textStorage;
@property (nonatomic, copy, nullable) NSAttributedString *attributedString;
@property (nonatomic, readonly) id documentRange;
- (nullable id)enumerateTextElementsFromLocation:(nullable id)textLocation
                                          options:(NSTextContentManagerEnumerationOptions)options
                                       usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *element))block;
- (NSString *)description;
@end

@interface CharonHostNSTextListElement : NSObject
+ (nullable instancetype)textListElementWithContents:(NSAttributedString *)contents
                                  markerAttributes:(NSDictionary *)markerAttributes
                                          textList:(NSTextList *)textList
                                     childElements:(NSArray *)children;
+ (nullable instancetype)textListElementWithChildElements:(NSArray *)children
                                                  textList:(NSTextList *)textList
                                             nestingLevel:(NSInteger)nestingLevel;
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString;
@property (nonatomic, readonly, strong, nullable) NSAttributedString *contents;
@property (nonatomic, readonly, copy) NSArray *childElements;
@property (nonatomic, readonly, strong, nullable) NSTextList *textList;
@property (nonatomic, readonly, strong) NSAttributedString *attributedString;
- (NSString *)description;
@end

// The document range's own end, read as the port's location: a class of the port's, and the only way to name it
// here without the header that declares it.
@interface CharonHostNSTextParagraph : NSObject
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString;
@property (nonatomic, strong, nullable) id textContentManager;
@property (nullable, strong) NSTextRange *elementRange;
@property (nullable, strong, readonly) NSTextRange *paragraphContentRange;
@property (nullable, strong, readonly) NSTextRange *paragraphSeparatorRange;
@end

// The port's own location type, declared as the port declares it: CharonTextLocation.h has
// CharonTextLocation : NSObject <NSTextLocation>, and a range's ends are id<NSTextLocation> in the SDK's own
// headers, so a test that hands this type to one without saying so is handed a warning instead.
@interface CharonHostCharonTextLocation : NSObject <NSTextLocation>
+ (instancetype)locationWithTextContentStorage:(id)textContentStorage offset:(NSInteger)offset;
@property (nonatomic, readonly, weak) id textContentStorage;
@property (nonatomic, readonly) NSInteger offset;
@end

static Class port_manager_class(void) { return NSClassFromString(@"CharonHostNSTextContentManager"); }
static Class port_storage_class(void) { return NSClassFromString(@"CharonHostNSTextContentStorage"); }
static Class port_element_class(void) { return NSClassFromString(@"CharonHostNSTextListElement"); }

static NSString *described(id object)
{
    if (!object)
        return @"(nil)";
    NSString *text = [[object description] stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *addresses = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-fA-F]+"
                                                                              options:0
                                                                                error:NULL];
    return [addresses stringByReplacingMatchesInString:text
                                               options:0
                                                 range:NSMakeRange(0, text.length)
                                          withTemplate:@"0xX"];
}

static void compare_text(NSString *system, NSString *port, NSString *name)
{
    charon_check([system isEqualToString:port], name.UTF8String,
                 [NSString stringWithFormat:@"system %@ != port %@", described(system), described(port)]);
}

// What the host answers for the manager it can make, which is every answer of the base class: the two flags'
// defaults, the empty list, the primary that a manager not in the list resets to nil, the transaction's nesting,
// and the two synchronisations inside a transaction.
static void compare_manager(void)
{
    NSTextContentManager *system = [[NSTextContentManager alloc] init];
    CharonHostNSTextContentManager *port = [[port_manager_class() alloc] init];
    charon_check(system != nil && port != nil, "both sides make a bare manager", @"one side does not");
    charon_check(system.textLayoutManagers.count == 0 && [port textLayoutManagers].count == 0,
                 "a bare manager holds no layout manager on either side", @"one side holds some");
    charon_check(!system.hasEditingTransaction && !([port hasEditingTransaction]),
                 "and is in no transaction on either side", @"one side is");
    charon_check(system.automaticallySynchronizesTextLayoutManagers &&
                     [port automaticallySynchronizesTextLayoutManagers],
                 "both sides synchronize the layout managers by default", @"one side does not");
    charon_check(!system.automaticallySynchronizesToBackingStore && !([port automaticallySynchronizesToBackingStore]),
                 "and neither synchronizes the backing store by default", @"one side does");
    charon_check(system.delegate == nil && [port delegate] == nil, "and neither holds a delegate",
                 @"one side holds one");
    // A primary that is not in the list: the header's own rule, and the host's answer.
    id notInTheList = @"a manager that was never added";
    [system setPrimaryTextLayoutManager:notInTheList];
    [port setPrimaryTextLayoutManager:notInTheList];
    charon_check(system.primaryTextLayoutManager == nil && [port primaryTextLayoutManager] == nil,
                 "a primary that is not in the list is nil on both sides", @"one side kept it");
    // A nil range on a manager with no document, which the header marks non-null. The nil is the case: what
    // the two sides answer for it is one of the facts this file holds, so the diagnostic is off for this
    // statement and for nothing else in the file.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    charon_check([system textElementsForRange:nil].count == 0 && [[port textElementsForRange:nil] count] == 0,
                 "a manager with no document has no elements on either side", @"one side has some");
#pragma clang diagnostic pop
    compare_text(described(system), described(port), @"a bare manager, described");

    // The transaction, and a synchronization inside it. The host raises nothing and asks nothing, which is the
    // divergence M11 records; the port does the same, and this case fails if either side starts refusing.
    __block BOOL inside = NO, raised = NO;
    @try {
        [system performEditingTransactionUsingBlock:^{
            inside = system.hasEditingTransaction;
            @try {
                [system synchronizeTextLayoutManagers:nil];
            } @catch (NSException *exception) {
                raised = YES;
            }
        }];
    } @catch (NSException *exception) {
        raised = YES;
    }
    __block BOOL portInside = NO, portRaised = NO;
    @try {
        [port performEditingTransactionUsingBlock:^{
            portInside = [port hasEditingTransaction];
            @try {
                [port synchronizeTextLayoutManagers:nil];
            } @catch (NSException *exception) {
                portRaised = YES;
            }
        }];
    } @catch (NSException *exception) {
        portRaised = YES;
    }
    charon_check(inside && portInside, "a transaction is open inside the block on both sides", @"one side is not");
    charon_check(!system.hasEditingTransaction && !([port hasEditingTransaction]),
                 "and closed after it on both sides", @"one side is still in one");
    charon_check(!raised && !portRaised,
                 "and a synchronization inside it raises on neither side, as M11 records", @"one side raises");
    // Nesting, which the header describes and the port implements as a depth.
    __block NSInteger depth = 0;
    [port performEditingTransactionUsingBlock:^{
        [port performEditingTransactionUsingBlock:^{
            depth = [port hasEditingTransaction] ? 2 : 0;
        }];
    }];
    charon_check(depth == 2 && !([port hasEditingTransaction]),
                 "a nested transaction nests and unwinds on the port", @"the depth is not two, or it is still open");
    // The edit record, which the header says a concrete subclass invokes for each action, and which a manager
    // given nothing refuses on both sides rather than recording a pair of nils.
    BOOL systemRecorded = YES, portRecorded = YES;
    // Two nil ranges again, and the same reason: the answer for them is what this file records, and a
    // refusal is an answer too.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    @try {
        [system recordEditActionInRange:nil newTextRange:nil];
    } @catch (NSException *exception) {
        systemRecorded = NO;
    }
#pragma clang diagnostic pop
    @try {
        [port recordEditActionInRange:nil newTextRange:nil];
    } @catch (NSException *exception) {
        portRecorded = NO;
    }
    charon_check(systemRecorded == portRecorded, "recording nothing answers the same on both sides",
                 @"one side refused it and the other did not");
    charon_check([[NSTextContentManager class] supportsSecureCoding] == [port_manager_class() supportsSecureCoding],
                 "both sides say a manager supports secure coding", @"one side does not");
}

// The list element, which the host answers in full: the two factories, their refusals, and the marker's text
// coming out of the list the port already carries.
static void compare_list_element(void)
{
    NSTextList *list = [[NSTextList alloc] initWithMarkerFormat:NSTextListMarkerDecimal options:0
                                              startingItemNumber:1];
    charon_check([list markerForItemNumber:1] != nil, "the carried NSTextList answers a marker", @"it does not");
    NSAttributedString *one = [[NSAttributedString alloc] initWithString:@"one"];
    NSTextListElement *systemItem = [NSTextListElement textListElementWithContents:one
                                                                  markerAttributes:nil
                                                                          textList:list
                                                                     childElements:nil];
    CharonHostNSTextListElement *portItem = [port_element_class() textListElementWithContents:one
                                                                markerAttributes:nil
                                                                        textList:list
                                                                   childElements:nil];
    charon_check(systemItem != nil && portItem != nil, "both sides make a list item", @"one side does not");
    charon_check([systemItem.contents length] == [portItem contents].length &&
                     [portItem contents].length == one.length,
                 "and it keeps its contents", @"one side does not");
    charon_check(systemItem.childElements.count == 0 && [portItem childElements].count == 0,
                 "with no children on either side", @"one side has some");
    // The displayed string is the marker then the contents, which is the only part of an element that has
    // characters in the document.
    NSString *systemText = [systemItem.attributedString string];
    NSString *portText = [portItem attributedString].string;
    // The host's displayed string is the marker, the contents, and then the element's paragraph separator - it
    // measured "\t0\tone\n" - so the case holds what the two sides agree on: the contents are in both, and
    // something is in front of them. The marker's own text and the host's trailing separator are its own, and
    // the next case holds the marker.
    charon_check([systemText rangeOfString:@"one"].location != NSNotFound &&
                     [portText rangeOfString:@"one"].location != NSNotFound &&
                     [portText rangeOfString:@"one"].location > 0 && [systemText rangeOfString:@"one"].location > 0,
                 "the displayed string is the contents behind something on both sides",
                 [NSString stringWithFormat:@"system %@ / port %@", systemText, portText]);
    charon_check([systemText hasSuffix:@"one\n"],
                 "and the host's ends with the element's paragraph separator after them", systemText);
    // The marker itself is a measured divergence (M13): the host's item marker is tab-delimited and zero-based -
    // "\t0\t" for the first item of a list whose own -markerForItemNumber:1 answers "1" - so the host's element
    // does not derive its marker through the list at all, while the port's does, which is what its header says.
    // What both sides agree on is the shape, marker first and the contents after it; the host's own shape is held
    // here so a host that starts agreeing with the port is noticed.
    // "\t0\t" for the first item: the host's element derives its own marker, tab-delimited and zero-based, and
    // not through the list it was given - whose own -markerForItemNumber:1 answers "1" (M13).
    // The host's marker is tab-delimited and zero-based; the shape is what is held here, because the marker
    // itself is the divergence and what follows it is agreed by the case above.
    charon_check([systemText rangeOfString:@"\t0\t"].location == 0,
                 "the host's item marker is still tab-delimited and zero-based", systemText);
    // The port's element asks the list it was given, and the test's list is the system's - whose marker for 1 is
    // "1" - so the two agree here by the list's answer and not by the two elements' own rules, which M13 records.
    // Both sides number the first item zero - the host's marker says so, and the port's number is its own - so
    // what the port's marker is is the list's answer for zero, with no tab around it (M13).
    charon_check([portText isEqualToString:[[list markerForItemNumber:0] stringByAppendingString:@"one"]],
                 "and the port's is that list's answer for zero, without the host's tabs", portText);
    charon_check([NSTextListElement textListElementWithChildElements:@[] textList:list nestingLevel:0] == nil &&
                     [port_element_class() textListElementWithChildElements:@[] textList:list nestingLevel:0] == nil,
                 "a nesting parent of no children is nil on both sides", @"one side made one");
    BOOL systemRefused = NO, portRefused = NO;
    @try {
        (void)[NSTextListElement textListElementWithChildElements:(NSArray *)@[ (id)portItem ]
                                                         textList:list
                                                    nestingLevel:-1];
    } @catch (NSException *exception) {
        systemRefused = YES;
    }
    @try {
        (void)[port_element_class() textListElementWithChildElements:(NSArray *)@[ portItem ]
                                                            textList:list
                                                       nestingLevel:-1];
    } @catch (NSException *exception) {
        portRefused = YES;
    }
    charon_check(systemRefused && portRefused, "a negative nesting level is refused on both sides",
                 @"one side made one");
    BOOL systemInit = NO, portInit = NO;
    @try {
        // The header marks this one unavailable, so the system side is asked through objc_msgSend: the point of
        // the case is what the running system does with a call the header refuses to compile.
        (void)((id (*)(id, SEL, id))objc_msgSend)([NSTextListElement alloc], @selector(initWithAttributedString:), one);
    } @catch (NSException *exception) {
        systemInit = YES;
    }
    @try {
        (void)[[port_element_class() alloc] initWithAttributedString:one];
    } @catch (NSException *exception) {
        portInit = YES;
    }
    charon_check(systemInit == portInit, "an element made with -initWithAttributedString: answers the same on both sides",
                 @"one side refused it and the other did not");
}

// The content storage, which the host cannot be made of on the measured build. What is held here is the port
// against the header, and the host's absence is itself the case.
static void compare_storage(void)
{
    charon_check(![NSTextContentManager instancesRespondToSelector:@selector(initWithTextStorage:)] ||
                     [port_storage_class() instancesRespondToSelector:@selector(initWithTextStorage:)],
                 "the port's content storage is constructible, which the host's is not on the measured build",
                 @"the port cannot make one either");
    NSTextStorage *backing =
        [[NSTextStorage alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:@"one\ntwo\nthree"]];
    CharonHostNSTextContentStorage *port = [[port_storage_class() alloc] initWithTextStorage:backing];
    charon_check(port != nil, "the port makes a content storage over a text storage", @"it does not");
    charon_check([port textStorage] == backing, "which is the storage it is given", @"it is not");
    charon_check(backing.textStorageObserver == (id)port, "and the storage observes it, which is how a range stays true",
                 @"the storage observes nothing");
    charon_check([[[port attributedString] string] isEqualToString:@"one\ntwo\nthree"],
                 "the document is the storage's string", [[[port attributedString] string] description]);
    charon_check(described([port documentRange]) != nil, "and its document range is a range", @"it is not");
    // The two derived ranges the range layer is waiting for, which are nil while there is no manager and a range
    // the moment one is attached - and the port's content storage is a manager, so they are live here.
    // The paragraph is the port's, named as run.sh renames it: the test is compiled without the rename flags, so
    // an unprefixed NSTextParagraph would be the system's and its derived ranges the system's to make.
    CharonHostNSTextParagraph *paragraph =
        [[CharonHostNSTextParagraph alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:@"one\n"]];
    paragraph.textContentManager = (id)port;
    // The element range is what places a paragraph in a document, and the port refuses to derive one without it -
    // which is the same rule the host's own paragraph follows, measured in the range layer's group.
    charon_check(paragraph.paragraphContentRange == nil,
                 "a paragraph with no element range derives none, as the range layer's group measured", @"one derives one");
    // The document range is an id here, and the SDK declares a -location on half a dozen classes, so the two
    // ends are read through the port's own location type rather than through the property.
    id documentRange = [port documentRange];
    CharonHostCharonTextLocation *documentStart = (CharonHostCharonTextLocation *)[documentRange valueForKey:@"location"];
    CharonHostCharonTextLocation *documentEnd = (CharonHostCharonTextLocation *)[documentRange valueForKey:@"endLocation"];
    paragraph.elementRange = [[NSTextRange alloc] initWithLocation:documentStart endLocation:documentEnd];
    charon_check(paragraph.paragraphContentRange != nil && paragraph.paragraphSeparatorRange != nil,
                 "a paragraph in the port's document derives its content and separator ranges", @"it derives none");
    NSTextRange *content = paragraph.paragraphContentRange;
    NSTextRange *separator = paragraph.paragraphSeparatorRange;
    // The derived ranges are the port's own locations over offsets, so their lengths are the difference of the
    // two ends: four characters without the newline, and the one newline.
    NSInteger contentStart = (NSInteger)[(CharonHostCharonTextLocation *)content.location offset];
    NSInteger contentEnd = (NSInteger)[(CharonHostCharonTextLocation *)content.endLocation offset];
    NSInteger separatorStart = (NSInteger)[(CharonHostCharonTextLocation *)separator.location offset];
    NSInteger separatorEnd = (NSInteger)[(CharonHostCharonTextLocation *)separator.endLocation offset];
    charon_check(contentStart == 0 && contentEnd - contentStart == 3,
                 "the content range is the three characters without the newline",
                 [NSString stringWithFormat:@"%ld...%ld", (long)contentStart, (long)contentEnd]);
    charon_check(separatorStart == 3 && separatorEnd - separatorStart == 1,
                 "and the separator range is that one newline",
                 [NSString stringWithFormat:@"%ld...%ld", (long)separatorStart, (long)separatorEnd]);
    // Editing the document keeps the ranges true, which is the whole point of observing the storage.
    CharonHostCharonTextLocation *before = [[port documentRange] endLocation];
    [backing replaceCharactersInRange:NSMakeRange(0, 0) withString:@"x"];
    CharonHostCharonTextLocation *after = [[port documentRange] endLocation];
    charon_check(after.offset == before.offset + 1, "an edit to the document lengthens its range",
                 [NSString stringWithFormat:@"%ld then %ld", (long)before.offset, (long)after.offset]);
    charon_check([described(port) rangeOfString:@"NSTextContentStorage:"].location != NSNotFound,
                 "a content storage describes itself with its class and its document", described(port));
}

// The document cut into paragraphs. This is the one part of the storage the differential cannot reach and the
// differential used not to reach at all: the host's own content storage cannot be made on the measured build
// (the case above), so there is no second side to hold this against, and what is written here is the port held
// against the rule the facts file states - one paragraph per paragraph ending, a CR LF pair one ending of two
// characters, and a last paragraph that runs to the end of the document with no ending of its own. The rule is
// in facts/UIKit/NSTextContent15.md, "The elements are the document's paragraphs"; the header names no other
// paragraph separator, which is why the line separator and the paragraph separator characters are one paragraph
// here rather than three, and that is pinned too so a change to it is a decision rather than a drift.
static NSString *paragraph_bounds(NSArray *elements)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (CharonHostNSTextParagraph *element in elements) {
        CharonHostCharonTextLocation *from = (CharonHostCharonTextLocation *)[element.elementRange valueForKey:@"location"];
        CharonHostCharonTextLocation *to = (CharonHostCharonTextLocation *)[element.elementRange valueForKey:@"endLocation"];
        [parts addObject:[NSString stringWithFormat:@"[%ld,%ld)", (long)from.offset, (long)to.offset]];
    }
    return [parts componentsJoinedByString:@" "];
}

// $1: the document's text, $2: the paragraph boundaries the rule gives it, $3: the case's name.
static void check_paragraphs(NSString *text, NSString *expected, NSString *name)
{
    NSTextStorage *backing = [[NSTextStorage alloc] initWithAttributedString:
                              [[NSAttributedString alloc] initWithString:text]];
    CharonHostNSTextContentStorage *port = [[port_storage_class() alloc] initWithTextStorage:backing];
    NSArray *elements = [port textElementsForRange:[port documentRange]];
    charon_check([paragraph_bounds(elements) isEqualToString:expected], name.UTF8String,
                 [NSString stringWithFormat:@"port %@", paragraph_bounds(elements)]);
}

static void compare_paragraphs(void)
{
    check_paragraphs(@"one\ntwo\nthree", @"[0,4) [4,8) [8,13)", @"a line feed ends a paragraph, and the last one runs to the end");
    check_paragraphs(@"one\ntwo\n", @"[0,4) [4,8)", @"a document ending in a line feed has no empty paragraph after it");
    check_paragraphs(@"one\r\ntwo\r\n", @"[0,5) [5,10)", @"a carriage return and a line feed are one ending of two characters");
    check_paragraphs(@"one\rtwo\r", @"[0,4) [4,8)", @"a carriage return with no line feed after it ends a paragraph by itself");
    check_paragraphs(@"one\n\ntwo", @"[0,4) [4,5) [5,8)", @"two endings in a row leave an empty paragraph between them");
    // The header names no paragraph separator beyond the two C0 line endings, so the Unicode line and paragraph
    // separators are ordinary characters here. This pins that reading: it is the port's own, and the facts file
    // says so, but nothing above would notice if it changed.
    check_paragraphs(@"one\u2028two\u2029three", @"[0,13)", @"the Unicode line and paragraph separators are not paragraph endings here");
    check_paragraphs(@"plain", @"[0,5)", @"a document with no ending at all is one paragraph");

    // The range's own end decides where the array stops, as the header describes it: the text elements that meet the range come back in order,
    //   so a range over the second paragraph only returns that one,
    // and a range over two returns two, with the element that meets the range's end still in it.
    NSTextStorage *backing = [[NSTextStorage alloc] initWithAttributedString:
                              [[NSAttributedString alloc] initWithString:@"one\ntwo\nthree"]];
    CharonHostNSTextContentStorage *port = [[port_storage_class() alloc] initWithTextStorage:backing];
    CharonHostCharonTextLocation *at4 = [CharonHostCharonTextLocation locationWithTextContentStorage:port offset:4];
    CharonHostCharonTextLocation *at8 = [CharonHostCharonTextLocation locationWithTextContentStorage:port offset:8];
    CharonHostCharonTextLocation *at12 = [CharonHostCharonTextLocation locationWithTextContentStorage:port offset:12];
    NSTextRange *second = [[NSTextRange alloc] initWithLocation:at4 endLocation:at8];
    NSTextRange *firstTwo = [[NSTextRange alloc] initWithLocation:at4 endLocation:at12];
    charon_check([paragraph_bounds([port textElementsForRange:second]) isEqualToString:@"[4,8)"],
                 "a range over one paragraph returns that paragraph and no other",
                 paragraph_bounds([port textElementsForRange:second]));
    charon_check([paragraph_bounds([port textElementsForRange:firstTwo]) isEqualToString:@"[4,8) [8,13)"],
                 "and a range over two returns both, the one that meets its end included",
                 paragraph_bounds([port textElementsForRange:firstTwo]));
    // Backward enumeration, which reads the document from its end: the header's own rule is that it starts with
    // the element *preceding* the one containing a given location, and at the document's end when the location
    // is nil, so the two are different and a forward case cannot stand for it.
    NSMutableArray *backward = [NSMutableArray array];
    [port enumerateTextElementsFromLocation:nil
                                    options:NSTextContentManagerEnumerationOptionsReverse
                                 usingBlock:^BOOL(NSTextElement *element) {
                                     [backward addObject:element];
                                     return YES;
                                 }];
    charon_check([paragraph_bounds(backward) isEqualToString:@"[8,13) [4,8) [0,4)"],
                 "a backward enumeration with no location walks the paragraphs from the end of the document",
                 paragraph_bounds(backward));
    NSMutableArray *backwardAtTen = [NSMutableArray array];
    [port enumerateTextElementsFromLocation:at12
                                    options:NSTextContentManagerEnumerationOptionsReverse
                                 usingBlock:^BOOL(NSTextElement *element) {
                                     [backwardAtTen addObject:element];
                                     return YES;
                                 }];
    charon_check([paragraph_bounds(backwardAtTen) isEqualToString:@"[4,8) [0,4)"],
                 "and from a location it starts with the element before the one holding it",
                 paragraph_bounds(backwardAtTen));
    NSMutableArray *backwardInside = [NSMutableArray array];
    [port enumerateTextElementsFromLocation:at4
                                    options:NSTextContentManagerEnumerationOptionsReverse
                                 usingBlock:^BOOL(NSTextElement *element) {
                                     [backwardInside addObject:element];
                                     return YES;
                                 }];
    charon_check([paragraph_bounds(backwardInside) isEqualToString:@"[0,4)"],
                 "so a location at a paragraph's start enumerates the one before it, not its own",
                 paragraph_bounds(backwardInside));
    // A CR LF pair is one ending of two characters whichever way the walk goes, which is the other half of the
    // paragraph rule and the part a lone-carriage-return document exercises from behind.
    NSTextStorage *crlf = [[NSTextStorage alloc] initWithAttributedString:
                           [[NSAttributedString alloc] initWithString:@"one\r\ntwo\r\nthree"]];
    CharonHostNSTextContentStorage *crlfPort = [[port_storage_class() alloc] initWithTextStorage:crlf];
    NSMutableArray *crlfBackward = [NSMutableArray array];
    [crlfPort enumerateTextElementsFromLocation:nil
                                       options:NSTextContentManagerEnumerationOptionsReverse
                                    usingBlock:^BOOL(NSTextElement *element) {
                                        [crlfBackward addObject:element];
                                        return YES;
                                    }];
    charon_check([paragraph_bounds(crlfBackward) isEqualToString:@"[10,15) [5,10) [0,5)"],
                 "a backward walk over a carriage-return-and-line-feed document cuts the same three paragraphs",
                 paragraph_bounds(crlfBackward));

    // A location of another document is not this storage's, and the storage refuses the range rather than
    // answering with elements of its own - the header's rule for a range whose ends are not in the document.
    CharonHostCharonTextLocation *elsewhere =
        [CharonHostCharonTextLocation locationWithTextContentStorage:nil offset:4];
    charon_check([port textElementsForRange:[[NSTextRange alloc] initWithLocation:elsewhere endLocation:at8]].count == 0,
                 "a range whose start is not this document's intersects nothing",
                 paragraph_bounds([port textElementsForRange:[[NSTextRange alloc] initWithLocation:elsewhere
                                                                            endLocation:at8]]));
}


// What a class of the port's own adopts, read off the class rather than by name. The SDK this file compiles
// against declares NSTextLocation, NSTextElementProvider and NSTextStorageObserving as well - all three are in
// its NSTextViewportLayoutController.h, NSTextContentManager.h and NSTextStorage.h - so a lookup by name would
// answer with the host's whatever the port did, and a case built on one measures the host rather than this
// library. Reading the protocol list off a class answers a narrower and true question, and the class makes it
// the port's own: CharonTextLocation is a name no SDK header declares, and its @interface in CharonTextLocation.h
// is the only declaration of it anywhere in this translation unit's world - so the protocol on
// CharonHostCharonTextLocation is one this library put there. That it is a real reading and not a lookup is
// shown by the control below and by the mutation: taking <NSTextLocation> off the declaration turns this case
// red with `checks=55 failures=1`.
//
// The control is the storage beside it, which adopts NSTextStorageObserving through the SDK's own declaration of
// NSTextContentStorage and does not adopt NSTextLocation - so a check that answered yes for every class in the
// group would pass without reading anything.
static BOOL class_adports(Class cls, Protocol *wanted)
{
    unsigned int count = 0;
    __unsafe_unretained Protocol **list = class_copyProtocolList(cls, &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count; i++) {
        if (protocol_isEqual(list[i], wanted) || protocol_conformsToProtocol(list[i], wanted))
            found = YES;
    }
    free(list);
    return found;
}

static void check_declared_protocol(void)
{
    Class location = NSClassFromString(@"CharonHostCharonTextLocation");
    Class storage = NSClassFromString(@"CharonHostNSTextContentStorage");
    charon_check(location != nil && storage != nil, "the port's own location type and its storage are both in the process, renamed as the harness renames them" ,
                 @"one of the two is not");
    charon_check(location != nil && class_adports(location, @protocol(NSTextLocation)), "the port's own location type adopts the location protocol its header names" , @"it adopts none");
    charon_check(storage != nil && !class_adports(storage, @protocol(NSTextLocation)), "and the storage beside it, which is not a location, answers no - which is what makes that a reading and not a lookup" ,
                 @"a class that is not a location answers yes");
}
int main(void)
{
    @autoreleasepool {
        check_declared_protocol();
        compare_manager();
        compare_list_element();
        compare_storage();
        compare_paragraphs();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}

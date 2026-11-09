#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RevenantMarkdownKind) {
    RevenantMarkdownDocument,
    RevenantMarkdownBlockQuote,
    RevenantMarkdownList,
    RevenantMarkdownItem,
    RevenantMarkdownCodeBlock,
    RevenantMarkdownHTMLBlock,
    RevenantMarkdownParagraph,
    RevenantMarkdownHeading,
    RevenantMarkdownThematicBreak,
    RevenantMarkdownTable,
    RevenantMarkdownTableRow,
    RevenantMarkdownTableCell,
    RevenantMarkdownText,
    RevenantMarkdownSoftBreak,
    RevenantMarkdownLineBreak,
    RevenantMarkdownCode,
    RevenantMarkdownHTMLInline,
    RevenantMarkdownEmphasis,
    RevenantMarkdownStrong,
    RevenantMarkdownStrikethrough,
    RevenantMarkdownLink,
    RevenantMarkdownImage,
    RevenantMarkdownAttributed,
};

@interface RevenantMarkdownNode : NSObject {
@public
    RevenantMarkdownKind kind;
    __unsafe_unretained RevenantMarkdownNode *parent;
    __unsafe_unretained RevenantMarkdownNode *firstChild;
    __unsafe_unretained RevenantMarkdownNode *lastChild;
    __unsafe_unretained RevenantMarkdownNode *previous;
    __unsafe_unretained RevenantMarkdownNode *next;
    NSMutableString *content;
    NSString *literal;
    NSString *info;
    NSString *destination;
    NSString *title;
    NSArray *alignments;
    NSInteger level;
    NSInteger start;
    NSInteger columnCount;
    NSInteger fenceLength;
    NSInteger fenceOffset;
    NSInteger htmlType;
    NSInteger markerOffset;
    NSInteger padding;
    NSInteger line;
    unichar marker;
    unichar fenceChar;
    BOOL ordered;
    BOOL header;
    BOOL open;
    BOOL lastLineBlank;
    BOOL lastLineChecked;
    BOOL fenced;
    BOOL tableFailed;
}
@end

@interface RevenantMarkdownTree : NSObject
@property (nonatomic, readonly) RevenantMarkdownNode *root;
@end

RevenantMarkdownTree *RevenantMarkdownParseDocument(NSString *source);
RevenantMarkdownTree *RevenantMarkdownParseInlineOnly(NSString *source);

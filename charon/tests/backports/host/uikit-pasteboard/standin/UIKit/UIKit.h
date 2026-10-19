// The RELEASE's own UIPasteboard surface, as the port's two categories compose over it. It is declared
// here, and implemented by standin.m, so the harness can link the port's real objects against a
// recording of what they asked of it. Which selectors the release has is measured, not assumed: the
// selector table of ~/.charon/dyld/<release>/selectors_armv7.txt holds -setItems:, -items,
// -setValue:forPasteboardType: and -valueForPasteboardType: on 6.1.3 and on 4.3, and the type lists are
// the release's own UIKit symbols, read that way in facts/UIKit/UIPasteboardIOS10.md.
#import <Foundation/Foundation.h>

@interface UIPasteboard : NSObject
- (void)setItems:(NSArray *)items;
- (NSArray *)items;
- (void)setValue:(id)value forPasteboardType:(NSString *)type;
- (id)valueForPasteboardType:(NSString *)type;
- (BOOL)containsPasteboardTypes:(NSArray *)types;
// The port's own three members, declared so the probe can call what it must: they are NOT the
// release's, and the stand-in does not implement them - the port's categories do, which is the point
// of linking them rather than declaring them here.
- (void)setItems:(NSArray *)items options:(NSDictionary *)options;
- (void)setObjects:(NSArray *)objects;
- (void)setObjects:(NSArray *)objects localOnly:(BOOL)localOnly expirationDate:(NSDate *)expirationDate;
- (NSArray *)charonRecordedOptionsForTest;                  // not the release's: the port's own
@end

typedef NSString *UIPasteboardOption;
extern UIPasteboardOption const UIPasteboardOptionExpirationDate;
extern UIPasteboardOption const UIPasteboardOptionLocalOnly;
extern NSArray *UIPasteboardTypeListString;
extern NSArray *UIPasteboardTypeListURL;

#import <Foundation/Foundation.h>

@interface UIPasteboard : NSObject
- (void)setItems:(NSArray *)items;
- (NSArray *)items;
- (void)setValue:(id)value forPasteboardType:(NSString *)type;
- (id)valueForPasteboardType:(NSString *)type;
- (BOOL)containsPasteboardTypes:(NSArray *)types;
- (void)setItems:(NSArray *)items options:(NSDictionary *)options;
- (void)setObjects:(NSArray *)objects;
- (void)setObjects:(NSArray *)objects localOnly:(BOOL)localOnly expirationDate:(NSDate *)expirationDate;
- (NSArray *)charonRecordedOptionsForTest;
@end

typedef NSString *UIPasteboardOption;
extern UIPasteboardOption const UIPasteboardOptionExpirationDate;
extern UIPasteboardOption const UIPasteboardOptionLocalOnly;
extern NSArray *UIPasteboardTypeListString;
extern NSArray *UIPasteboardTypeListURL;

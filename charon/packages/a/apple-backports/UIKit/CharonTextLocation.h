// CharonTextLocation.h - the port's own NSTextLocation, over an offset in the document of one
// NSTextContentStorage. What a range is made of, and what every question about a range is a comparison of.
//
// NSTextLocation is a protocol with one method, a comparison, so a location needs to hold nothing but the
// ordering of itself against another. The offset is that ordering, and the storage it belongs to is held as
// well, because an offset is only an offset in one document: -offsetFromLocation:toLocation: is what answers
// NSNotFound for two locations of two documents, and it can only do so if each location knows which document
// it is in. The host's own location type is private and this is the port's, which is what a content manager
// without a private one uses - and what the emulator call test and the differential build their documents on.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class NSTextContentStorage;

@interface CharonTextLocation : NSObject <NSTextLocation>

// The storage this location is a place in, and the offset in that document. nil for a location of no
// document, which answers the same as any other location for a comparison and is refused by the storage.
@property (nonatomic, readonly, weak) NSTextContentStorage *textContentStorage;
@property (nonatomic, readonly) NSInteger offset;

+ (instancetype)locationWithTextContentStorage:(NSTextContentStorage *)textContentStorage offset:(NSInteger)offset;
- (instancetype)initWithTextContentStorage:(NSTextContentStorage *)textContentStorage offset:(NSInteger)offset;

@end

NS_ASSUME_NONNULL_END

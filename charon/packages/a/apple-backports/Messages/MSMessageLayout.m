#import <Foundation/Foundation.h>
#import <Messages/MSMessageLayout.h>
#import <Messages/MSMessageTemplateLayout.h>

// The layout is how a message is drawn in the transcript, and MSMessageLayout is the bare class: a
// subclass says what the bubble looks like. It carries nothing itself, so what is here is the object's
// identity, its copy, and the two subclasses the port carries.
//
// The two subclasses are value objects, and a value object is copied property by property: an
// MSMessageTemplateLayout's captions, its image and its media file all travel with a copy, and the
// copy compares equal to what it was copied from. What neither can do is be *drawn*: the transcript is
// the Messages app's own view, and on this release that app has no iMessage transcript to draw it in
// (facts/Messages/MSMessage.md).

@implementation MSMessageLayout

- (id)copyWithZone:(NSZone *)zone
{
    MSMessageLayout *copy = [[[self class] allocWithZone:zone] init];
    return copy;
}

- (BOOL)isEqual:(id)other
{
    return other == self || [other isKindOfClass:[self class]];
}

- (NSUInteger)hash
{
    return (NSUInteger)self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([self class]), self];
}

@end

@implementation MSMessageTemplateLayout

@synthesize caption = _caption;
@synthesize subcaption = _subcaption;
@synthesize trailingCaption = _trailingCaption;
@synthesize trailingSubcaption = _trailingSubcaption;
@synthesize image = _image;
@synthesize mediaFileURL = _mediaFileURL;
@synthesize imageTitle = _imageTitle;
@synthesize imageSubtitle = _imageSubtitle;

- (id)copyWithZone:(NSZone *)zone
{
    MSMessageTemplateLayout *copy = [super copyWithZone:zone];
    copy->_caption = [_caption copy];
    copy->_subcaption = [_subcaption copy];
    copy->_trailingCaption = [_trailingCaption copy];
    copy->_trailingSubcaption = [_trailingSubcaption copy];
    copy->_image = _image;
    copy->_mediaFileURL = [_mediaFileURL copy];
    copy->_imageTitle = [_imageTitle copy];
    copy->_imageSubtitle = [_imageSubtitle copy];
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[MSMessageTemplateLayout class]])
        return NO;
    MSMessageTemplateLayout *layout = other;
    return [layout->_caption isEqualToString:_caption] &&
           [layout->_subcaption isEqualToString:_subcaption] &&
           [layout->_trailingCaption isEqualToString:_trailingCaption] &&
           [layout->_trailingSubcaption isEqualToString:_trailingSubcaption] &&
           layout->_image == _image &&
           [layout->_mediaFileURL isEqual:_mediaFileURL] &&
           [layout->_imageTitle isEqualToString:_imageTitle] &&
           [layout->_imageSubtitle isEqualToString:_imageSubtitle];
}

- (NSUInteger)hash
{
    return [_caption hash] ^ [_subcaption hash] ^ [_image hash] ^ [_mediaFileURL hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> caption=%@ subcaption=%@ image=%@ media=%@",
            NSStringFromClass([self class]), self, _caption, _subcaption, _image, _mediaFileURL];
}

@end

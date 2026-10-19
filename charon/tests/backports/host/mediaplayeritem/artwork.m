// The artwork initialiser's contract: a handler that records the size it was asked for, and the
// artwork the initialiser returns is a port subclass that consults it.
#import "MPMediaItemStandin.h"

@interface UIImage : NSObject
@end

@implementation UIImage
@end

@implementation MPMediaItemArtwork
- (instancetype)initWithImage:(id)image { return [super init]; }
- (UIImage *)imageWithSize:(CGSize)size { return nil; }        // the release's own answer, and nil
- (CGRect)bounds { return CGRectZero; }
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPMediaItemArtwork100.m"

static int failures = 0;

static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

static CGSize asked = {0, 0};
static UIImage *askedWith = nil;

static UIImage *recording(UIImage *image, CGSize size) {
    asked = size;
    askedWith = image;
    return image;
}

int main(void) {
    UIImage *drawn = [[UIImage alloc] init];
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(120, 60)
                                                                 requestHandler:^(CGSize size) {
        return recording(drawn, size);
    }];
    check("the initialiser answers a kind of the class it is called on",
          [artwork isKindOfClass:[MPMediaItemArtwork class]],
          [artwork isKindOfClass:[MPMediaItemArtwork class]] ? "an MPMediaItemArtwork" : "not");
    UIImage *out = [artwork imageWithSize:CGSizeMake(300, 150)];
    check("imageWithSize: returns what the handler returned", out == drawn, "the handler's image");
    check("the handler was asked for the size the caller wanted",
          asked.width == 300 && asked.height == 150,
          asked.width == 300 && asked.height == 150 ? "300x150" : "other");
    CGRect bounds = [artwork bounds];
    check("bounds is the size the initialiser was given",
          bounds.size.width == 120 && bounds.size.height == 60,
          bounds.size.width == 120 && bounds.size.height == 60 ? "120x60" : "other");
    if (failures) { printf("artwork: %d RED\n", failures); return 1; }
    printf("artwork: OK (0 failures)\n");
    return 0;
}

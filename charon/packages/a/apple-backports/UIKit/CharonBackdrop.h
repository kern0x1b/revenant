#import <UIKit/UIKit.h>

@class CharonBackdrop;

@protocol CharonBackdropClient <NSObject>
/* Whether the backdrop is worth reading now: asked on every tick, so it may follow state no
   setter reports, such as the view's hidden flag or alpha. */
- (BOOL)backdropIsWanted:(CharonBackdrop *)backdrop;
/* The region to read, in the view's coordinates. */
- (CGRect)backdropRegion:(CharonBackdrop *)backdrop;
/* The pixels read, RGBA premultiplied, row 0 at the top, which the client owns and frees with
   free(); captured is the rect they cover, in the view's coordinates. Called only when what
   lies under the region changed since the last delivery, or after -invalidate. */
- (void)backdrop:(CharonBackdrop *)backdrop captured:(uint8_t *)pixels width:(size_t)width height:(size_t)height rowBytes:(size_t)rowBytes rect:(CGRect)captured;
@end

/* What lies under a view on a release without a backdrop layer: the view's window rendered
   with -[CALayer renderInContext:], with the view and everything drawn above it hidden, read a
   few times a second through a display link while it changes and less often while it does
   not. A backdrop layer composites from the destination every frame; this is the nearest a
   release without one has, and it is not live (facts/UIKit/UIVisualEffect.md). */
@interface CharonBackdrop : NSObject
- (instancetype)initWithView:(UIView *)view client:(id<CharonBackdropClient>)client;
/* Pixels per point of the reading. */
@property (nonatomic, assign) CGFloat scale;
/* Starts reading while the view is in a window; -stop ends it and forgets what was read. */
- (void)start;
- (void)stop;
/* Reads again at the next tick; -invalidate also delivers what has not changed. */
- (void)setNeedsRefresh;
- (void)invalidate;
/* Reads now. */
- (void)refresh;
@end

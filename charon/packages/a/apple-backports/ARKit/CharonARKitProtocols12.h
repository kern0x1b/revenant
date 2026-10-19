// CharonARKitProtocols12.h - the ARKit protocols the 12.0 headers introduced.
//
// Split from the 13.0 object beside it because an object carries the API of one release. A protocol
// named only in a header nothing references emits no metadata, so each is evaluated by a retained
// function - `@protocol(X)` is the one expression that forces the runtime's description of a protocol
// to exist, and it is not a compile-time constant, so it cannot initialise a static.

#import <ARKit/ARKit.h>

__attribute__((used)) static Protocol *CharonEmitARAnchorCopying(void) { return @protocol(ARAnchorCopying); }

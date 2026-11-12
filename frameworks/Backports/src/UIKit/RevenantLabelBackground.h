#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// A UILabel made in code has an opaque white background on iOS 6 and none on iOS 7 and later. Code written for the later behaviour
// (Telegram's country list puts a label on the grey row as the accessory view) shows white rectangles. This decides whether a
// background is that default white, from the components of its colour: a gray white (white, alpha) or an RGB white (r, g, b, alpha).
// A white with transparency, a grey or any other colour is the app's own and stays.
BOOL RevenantLabelBackgroundIsDefaultWhite(const CGFloat *components, size_t count);

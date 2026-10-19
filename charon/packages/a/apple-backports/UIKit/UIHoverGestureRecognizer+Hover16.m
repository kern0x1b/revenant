// UIHoverGestureRecognizer+Hover16.m - the four members UIHoverGestureRecognizer gained in iOS 16.1
// and 16.4.
//
// Apple's own header says what each one answers for a device that cannot hover, and this release
// cannot: zOffset answers 0 for a device without z offset support (16.1), azimuthAngleInView: answers 0
// for one without azimuth support (16.4), azimuthUnitVectorInView: gives an empty vector in that case (16.4), and
// altitudeAngle answers 0 for one without altitude support (16.4). iOS 6 has no pointing
// device at all - no trackpad, no mouse, no hover - which is why UIHoverGestureRecognizer.m, the
// 13.0 object, says so once in the log and fails the recogniser at the first touch it is offered.
//
// These four are in their own file because they arrived in a later release than that class did, and
// one object carries one release. They are methods on the port's own class, so they export no symbol
// of their own and release-split reads nothing for this file: the four are held to the header's words
// by the case in tests/backports/host/uikit2/hover16_test.m, against the host's own class.
//
// The accessors the property spellings use are declared @dynamic in UIHoverGestureRecognizer.m, which
// is what says to the compiler that they arrive here rather than being synthesised; that is already
// in main and is not repeated.

#import <UIKit/UIKit.h>

@implementation UIHoverGestureRecognizer (CharonHover16)

- (CGFloat)zOffset
{
    // UIHoverGestureRecognizer.h:27 - the header says the answer is always 0 for devices without z offset support.
    return 0;
}

- (CGFloat)altitudeAngle
{
    // UIHoverGestureRecognizer.h:38 - the header gives 0 as the altitude for a device without altitude support.
    return 0;
}

- (CGFloat)azimuthAngleInView:(UIView *)view
{
    // UIHoverGestureRecognizer.h:31 - the header gives 0 for a device without azimuth support.
    return 0;
}

- (CGVector)azimuthUnitVectorInView:(UIView *)view
{
    // UIHoverGestureRecognizer.h:35 - the header says the empty vector is given for devices without azimuth support.
    return CGVectorMake(0, 0);
}

@end

#import <CoreImage/CoreImage.h>

// The iOS 14.2 band's CoreImage pixel-format codes: the four-character codes CIFormat is, that the SDK
// added in the two releases later than the 11.0 band's kCIFormatRGBA8.
//
// CIFormat is an OSType, so these are plain data: an application writes the code into a context, a
// destination or a bitmap and the release reads it there. iOS 6 exports none of them - the header
// declares each as an exported constant rather than as an enum case, so a strong reference to one is a
// link failure on the release - and they are carried with the codes the host's own CoreImage holds.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN CoreImage with dlsym, by tests/backports/host/ciimageformats,
// which COMPILES these objects and LINKS them into a reader, so the code compared against Apple s is the
// port s own and not a number this file already had. Nothing here could have been derived: the codes are
// not the characters of the name, and kCIFormatA16 of the 9.0 band is 1793, which is none of them.
//
// Split by release, because an object carries the API of one release: no held rung exports any of these
// symbols - the cache ladder ends at 10.3.4 - so the SDK's own annotation places them, and kCIFormatRGBX16
// is annotated NS_AVAILABLE(11_0, 14_2) while the three of the 17.0 object are NS_AVAILABLE(14_0, 17_0).

const CIFormat kCIFormatRGBX16 = 1804;
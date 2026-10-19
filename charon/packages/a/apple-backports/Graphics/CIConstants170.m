#import <CoreImage/CoreImage.h>

// The iOS 17.0 band's CoreImage pixel-format codes: the half-float and 10-bit formats the SDK added in
// 17.0, which no release below it exports.
//
// CIFormat is an OSType, so these are plain data: an application writes the code into a context, a
// destination or a bitmap and the release reads it there. iOS 6 exports none of them - the header declares
// each as an exported constant rather than as an enum case, so a strong reference to one is a link failure
// on the release - and they are carried with the codes the host's own CoreImage holds.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN CoreImage with dlsym, by tests/backports/host/ciimageformats,
// which COMPILES these objects and LINKS them into a reader, so the code compared against Apple s is the
// port s own and not a number this file already had. Nothing here could have been derived: the codes are
// not the characters of the name, and none of these four is the three it is named after.
//
// Split by release, because an object carries the API of one release: no held rung exports any of these
// symbols - the cache ladder ends at 10.3.4 - so the SDK's own annotation places them, and each of these
// three is annotated NS_AVAILABLE(14_0, 17_0).

const CIFormat kCIFormatRGB10 = 775;
const CIFormat kCIFormatRGBXh = 2060;
const CIFormat kCIFormatRGBXf = 2316;
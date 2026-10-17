#import <CoreGraphics/CoreGraphics.h>

// The PDF names that iOS 16.0 adds: the two context options of a linearized and of a PDF/A document. The strings are the
// ones the release's CoreGraphics holds (facts/CoreGraphics/PDFNames.md).
const CFStringRef kCGPDFContextCreateLinearizedPDF = CFSTR("CGPDFContextCreateLinearizedPDF");
const CFStringRef kCGPDFContextCreatePDFA = CFSTR("CGPDFContextCreatePDFA");

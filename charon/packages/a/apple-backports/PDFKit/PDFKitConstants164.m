// PDFKit's constants of iOS 16.4.0, read out of the host's own PDFKit with dladdr naming the
// image each value came from; tests/backports/host/pdfkit-constants compares them, and the values
// below are the host's, not a guess at the format's literals.

#import <PDFKit/PDFKit.h>

PDFKIT_EXTERN NSString *const PDFDocumentOptimizeImagesForScreenOption;
NSString *const PDFDocumentOptimizeImagesForScreenOption = @"PDFDocumentOptimizeImagesForScreenOption";
PDFKIT_EXTERN NSString *const PDFDocumentSaveImagesAsJPEGOption;
NSString *const PDFDocumentSaveImagesAsJPEGOption = @"PDFDocumentSaveImagesAsJPEGOption";

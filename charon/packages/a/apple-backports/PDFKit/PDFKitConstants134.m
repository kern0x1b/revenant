// PDFKit's constants of iOS 13.4, read out of the host's own PDFKit with dladdr naming the
// image each value came from; tests/backports/host/pdfkit-constants compares them, and the values
// below are the host's, not a guess at the format's literals.

#import <PDFKit/PDFKit.h>

PDFKIT_EXTERN NSString *const PDFDocumentAccessPermissionsOption;
NSString *const PDFDocumentAccessPermissionsOption = @"PDFDocumentAccessPermissionsOption";

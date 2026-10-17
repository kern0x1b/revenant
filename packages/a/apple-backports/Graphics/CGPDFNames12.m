#import <CoreGraphics/CoreGraphics.h>

// The PDF names that iOS 12.0 adds: the tag property names, and CGPDFTagTypeGetName, which answers the name of a tag type.
// The strings are the ones the release's CoreGraphics holds (facts/CoreGraphics/PDFNames.md).
const CFStringRef kCGPDFTagPropertyActualText = CFSTR("CGPDFTagPropertyActualText");
const CFStringRef kCGPDFTagPropertyAlternativeText = CFSTR("CGPDFTagPropertyAlternativeText");
const CFStringRef kCGPDFTagPropertyLanguageText = CFSTR("CGPDFTagPropertyLanguageText");
const CFStringRef kCGPDFTagPropertyTitleText = CFSTR("CGPDFTagPropertyTitleText");

// The name a tag type has in a PDF, as the release's CGPDFTagTypeGetName gives it: the role of the tag with its slash,
// NULL for a value that is not a tag type. The values are the enumeration's (CGPDFTagType, 13.0).
const char *CGPDFTagTypeGetName(CGPDFTagType tagType)
{
    switch (tagType) {
    case 100: return "/Document";
    case 101: return "/Part";
    case 102: return "/Art";
    case 103: return "/Sect";
    case 104: return "/Div";
    case 105: return "/BlockQuote";
    case 106: return "/Caption";
    case 107: return "/TOC";
    case 108: return "/TOCI";
    case 109: return "/Index";
    case 110: return "/NonStruct";
    case 111: return "/Private";
    case 200: return "/P";
    case 201: return "/H";
    case 202: return "/H1";
    case 203: return "/H2";
    case 204: return "/H3";
    case 205: return "/H4";
    case 206: return "/H5";
    case 207: return "/H6";
    case 300: return "/L";
    case 301: return "/LI";
    case 302: return "/Lbl";
    case 303: return "/LBody";
    case 400: return "/Table";
    case 401: return "/TR";
    case 402: return "/TH";
    case 403: return "/TD";
    case 404: return "/THead";
    case 405: return "/TBody";
    case 406: return "/TFoot";
    case 500: return "/Span";
    case 501: return "/Quote";
    case 502: return "/Note";
    case 503: return "/Reference";
    case 504: return "/BibEntry";
    case 505: return "/Code";
    case 506: return "/Link";
    case 507: return "/Annot";
    case 600: return "/Ruby";
    case 601: return "/RB";
    case 602: return "/RT";
    case 603: return "/RP";
    case 604: return "/Warichu";
    case 605: return "/WT";
    case 606: return "/WP";
    case 700: return "/Figure";
    case 701: return "/Formula";
    case 702: return "/Form";
    case 800: return "/OBJR";
    default: return NULL;
    }
}

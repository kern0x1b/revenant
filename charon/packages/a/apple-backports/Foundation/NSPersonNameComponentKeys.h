#import <Foundation/Foundation.h>

/* The attribute names the person name components formatter writes on the attributed string it hands
   back, and the key they sit under. Their values are the ones the host's own formatter hands out,
   read through a formatted name (measured: an annotated name from the host answers exactly these, one
   run per component and one for the separator). None of them is the symbol's own name, which is why
   they were read. Defined in NSPersonNameComponentsFormatter9.m. */
FOUNDATION_EXPORT NSString * const NSPersonNameComponentKey;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentGivenName;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentFamilyName;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentMiddleName;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentPrefix;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentSuffix;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentNickname;
FOUNDATION_EXPORT NSString * const NSPersonNameComponentDelimiter;

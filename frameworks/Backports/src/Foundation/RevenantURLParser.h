#import <Foundation/Foundation.h>

NSString *revenant_url_standard(NSString *string, BOOL encoding, BOOL nsurl);
NSString *revenant_url_host_unicode(NSString *host);
BOOL revenant_url_ranges(NSString *string, NSRange *ranges);
NSNumber *revenant_url_integer(NSString *text);
NSString *revenant_url_nsurl(NSString *string, BOOL encoding);

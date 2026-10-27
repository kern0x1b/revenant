#import <Foundation/Foundation.h>


extern NSString *const RevenantWebKitBridgeScheme;

extern NSString *const RevenantEncoder;

extern NSString *const RevenantShim;

id RevenantCodecParsed(NSString *text, BOOL *valid);

id RevenantCodecDecoded(id value);

NSDictionary *RevenantCodecBridgeMessage(NSURL *URL);

id RevenantCodecMessageBody(id encoded, BOOL *valid);

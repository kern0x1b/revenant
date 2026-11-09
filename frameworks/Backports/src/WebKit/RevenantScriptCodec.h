#import <Foundation/Foundation.h>


extern NSString *const RevenantWebKitBridgeScheme;

extern NSString *const RevenantEncoder;

extern NSString *const RevenantShim;

NSString *RevenantCodecStringLiteral(NSString *string);

NSString *RevenantCodecScriptLiteral(id value);

id RevenantCodecParsed(NSString *text, BOOL *valid);

id RevenantCodecDecoded(id value);

NSDictionary *RevenantCodecBridgeMessage(NSURL *URL, NSString *nonce);

id RevenantCodecMessageBody(id encoded, BOOL *valid);

NSString *RevenantOriginOf(NSURL *URL);

BOOL RevenantTargetAllows(NSString *target, NSString *senderOrigin, NSString *recipientOrigin);

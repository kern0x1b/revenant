#import <Foundation/Foundation.h>

@protocol RevenantDocumentSource <NSObject>
- (NSArray<NSString *> *)revenant_documentStartScripts;
- (void)revenant_documentDidInject;
@end

NSString *RevenantDocumentRegister(id<RevenantDocumentSource> source);
void RevenantDocumentTagRequest(NSMutableURLRequest *request, NSString *token);

NSData *RevenantDocumentRewrite(NSData *body, NSString *contentEncoding, NSString *charset, NSArray<NSString *> *scripts);
NSString *RevenantDocumentInsert(NSString *html, NSArray<NSString *> *scripts);
NSString *RevenantDocumentCSPWithHashes(NSString *policy, NSArray<NSString *> *scripts);
NSString *RevenantDocumentHash(NSString *script);

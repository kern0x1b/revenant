#import <Foundation/Foundation.h>

@class PDFSelection;

@protocol PDFDocumentDelegate <NSObject>
@optional
- (void)documentDidUnlock:(NSNotification *)notification;
- (void)documentDidBeginDocumentFind:(NSNotification *)notification;
- (void)documentDidEndDocumentFind:(NSNotification *)notification;
- (void)documentDidBeginPageFind:(NSNotification *)notification;
- (void)documentDidEndPageFind:(NSNotification *)notification;
- (void)documentDidFindMatch:(NSNotification *)notification;
- (void)didMatchString:(PDFSelection *)instance;
- (Class)classForPage;
- (Class)classForAnnotationType:(NSString *)annotationType;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(PDFDocumentDelegate);
}

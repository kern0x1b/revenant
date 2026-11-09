#import <UIKit/UIKit.h>

@class PDFView, PDFActionRemoteGoTo;

@protocol PDFViewDelegate <NSObject>
@optional
- (void)PDFViewWillClickOnLink:(PDFView *)sender withURL:(NSURL *)url;
- (UIViewController *)PDFViewParentViewController;
- (void)PDFViewPerformFind:(PDFView *)sender;
- (void)PDFViewPerformGoToPage:(PDFView *)sender;
- (void)PDFViewOpenPDF:(PDFView *)sender forRemoteGoToAction:(PDFActionRemoteGoTo *)action;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(PDFViewDelegate);
}

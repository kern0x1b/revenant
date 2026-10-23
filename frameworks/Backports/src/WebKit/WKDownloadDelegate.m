#import <WebKit/WebKit.h>

Protocol *revenant_web_download_delegate_protocol(void)
{
    return @protocol(WKDownloadDelegate);
}

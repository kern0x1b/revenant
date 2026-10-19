#import "CharonWebKit.h"
#import <objc/runtime.h>

@implementation WKNavigation {
    NSURLRequest *_request;
}

- (NSURLRequest *)charon_request
{
    return _request;
}

- (void)setCharon_request:(NSURLRequest *)request
{
    _request = [request copy];
}

@end

@implementation WKFrameInfo {
    BOOL _mainFrame;
    NSURLRequest *_request;
}

+ (instancetype)charon_frameWithMainFrame:(BOOL)mainFrame request:(NSURLRequest *)request
{
    WKFrameInfo *frame = [self alloc];
    frame->_mainFrame = mainFrame;
    frame->_request = [request copy];
    return frame;
}

- (BOOL)isMainFrame
{
    return _mainFrame;
}

- (NSURLRequest *)request
{
    return _request;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation WKNavigationAction {
    NSURLRequest *_request;
    WKNavigationType _type;
    WKFrameInfo *_sourceFrame;
    WKFrameInfo *_targetFrame;
}

+ (instancetype)charon_actionWithRequest:(NSURLRequest *)request type:(WKNavigationType)type mainFrame:(BOOL)mainFrame
{
    WKNavigationAction *action = [self alloc];
    action->_request = [request copy];
    action->_type = type;
    action->_sourceFrame = [WKFrameInfo charon_frameWithMainFrame:mainFrame request:request];
    action->_targetFrame = [WKFrameInfo charon_frameWithMainFrame:mainFrame request:request];
    return action;
}

- (NSURLRequest *)request
{
    return _request;
}

- (WKNavigationType)navigationType
{
    return _type;
}

- (WKFrameInfo *)sourceFrame
{
    return _sourceFrame;
}

- (WKFrameInfo *)targetFrame
{
    return _targetFrame;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation WKNavigationResponse

- (BOOL)isForMainFrame
{
    return YES;
}

- (NSURLResponse *)response
{
    return nil;
}

- (BOOL)canShowMIMEType
{
    return YES;
}

@end

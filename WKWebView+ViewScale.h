//
//  WKWebView+ViewScale.h
//  Vienna
//

@import WebKit;

@interface WKWebView (ViewScale)

@property (setter=_setTextZoomFactor:, nonatomic) double _textZoomFactor;
@property (assign,setter=_setViewScale:,nonatomic) double _viewScale;

@end

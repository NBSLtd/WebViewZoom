Hello 👋

This is a sample Xcode project that accompanies my blog post *Hacking WebKit - Natural page zoom in WKWebView*.

To run this project on your Mac, you need Xcode 26.0.1 (or later) and macOS Tahoe 26.1 (or later). After downloading the source code, open WebViewZoom.xcodeproj in Xcode and run the app on an iOS or macOS device.

`[fig 0 running app]`

Below follows the text of the blog post. Subscribe for updates on Substack: nbsoftware.substack.com

# Hacking WebKit - Natural page zoom in WKWebView

WebKit support was one of the headlining additions to SwiftUI at the last WWDC.

The WebKit framework on Apple platforms is strikingly powerful. With a single line of Swift code it lets you - more or less - spin up an embeddable Safari that you can drop anywhere on the screen. Fast, cheap, and flexible, this API begs to be used more.

`[fig 1 hero image]`

Opening a window into the web with `WKWebView` is like inviting a whole other world into your native iOS garden. Here you can render a line of loose HTML or someone’s entire web app on the Internet with equal ease - if it works in Safari, it can work in your web view. This simple practical truth about WebKit can be a major advantage for apps still open to mixing web and native UI.

Though despite being literal magic, the WebKit API is not without frustrating gaps. As the real consumers of the engine, i.e. the Safari team, are not limited by the iOS SDK version of framework, some of its less flashy but critical features are excluded from the public interface.

In this article, I will show how to unlock one of such features - page zoom - and build the foundations of a browser-grade WKWebView setup in your own app along the way. This full sample code of this SwiftUI project is available on GitHub for iOS and macOS.

## what is ‘page zoom’?

A major reason why you may reach for a web view in a native app is the way web views handle rich text.

Browsers are basically supercharged rich text document viewers, with their core quirks and features polished by time and generations of developers. These things are damn good at rendering flows of text and images, as they are have been built for that from the beginning, and have only got more absurdly powerful since.

A natural thing to want to do to rich text is to resize it. The simplest and most easily understood accessibility feature, page zoom, or text zoom, might not be something you use often but would expect to find in any software that deals with text, if not - in the ideal world - all software.

`[fig 2 zoom in Safari]`

In the context of web pages, page zoom is this deceptively simple mechanism of proportionally scaling all the text nodes up or down while preserving the overall layout of the document. Try it right now in whatever browser you’re using to read this page. Easily available via the Command/Control + and - hot keys on desktops, these controls are typically tucked a couple or more taps away from the main UI in mobile browsers.

Though exact implementation no doubt vary between browsers, page zoom really works on all websites, accounting for the million possible ways web pages are able to configure - or misconfigure - their default font sizes. In other words, page zoom on the web is a solved problem - exactly the kind where you would lean on the maturity of an established framework for the solution, instead of reinventing the wheel.

That is, if the framework was willing to share.

Unfortunately the WKWebView, at least as of iOS 26, does not expose this zoom functionality to you. The fiendishly named `pageZoom` property exists but does something you almost certainly not want - scale the entire page up and down without adapting it to the current viewport, “acting in the same way zoom does in CSS” (?). I will be not be referring to this API for the rest of the tutorial.

`[fig 3 broken pageZoom]`

You could inject custom scripts directly into the rendered pages that might let you control the CSS directly yourself, but that is obviously a bike-shed-shaped trap

Brittle DOM API-based solutions can never be a replacement for the native browser engines functionality, where text can be scaled at the engine level. If you think about, it wouldn’t make a lot of sense for WKWebView to not be able to scale text already. Such a fundamental feature of the framework must simply be baked in. If only there was a way to know for certain…

`[fig 4 - _viewScale in WebKit source]`

Well, there is.

Thanks to the fact that WebKit is open sourced and actively maintained online, it is actually possible to piece together a solution by peeking at the internal headers of WKWebView, which is what we will implement in this tutorial.

Note, though technically disallowed, the use of private API suggested by this tutorial is OK for App Store releases. It may be safe to think of this kind of API as semi-private due to the open source nature of WebKit, but needless to say this is not legal advice for you and your own app, so tread carefully.

For what it’s worth, Praxis News, my iOS news reader app, implements its Text Size feature using this exact mechanism. If you cannot run the sample code for this tutorial, try it in my free app, then come back and read on.

`[fig 5 - Praxis screenshot]`

## Getting started - and why not use WebKit for SwiftUI

To create a basic web view driven SwiftUI app, start by defining your ‘chrome’, which is the UI around the web view. Let’s imagine it being driven by a simple view model which we will create in a moment:

**BrowserView.swift**
```swift
struct BrowserView: View {

  @State var model = BrowserModel(
    url: URL(string: "https://www.swift.org")!
  )
  
  var body: some View {
    
    WebView()
      .toolbar {
        ToolbarItem(placement: .principal) {
          VStack(alignment: .leading) {
            Text(model.title)
            Text(model.url?.absoluteString ?? "(empty)")
              .foregroundStyle(.secondary)
          }
        }
        
        ToolbarItem(placement: .status) {
          if model.isLoading {
            ProgressView()
              .onTapGesture {
                model.stopLoading()
              }
          } else {
            Button {
              model.reload()
            } label: {
              Label("Reload", systemImage: "arrow.clockwise")
            }
          }
        }
      }
      
  }
}
```

Here we have with a basic header and a floating toolbar button.

There is no benefit to using the newly introduced WebKit for SwiftUI available in iOS 26 and macOS 26, as it’s simply a wrapper around the same WKWebView API that we can use directly to the same effect.

In fact, because our ultimate goal is to expose a private property on the WKWebView type, there is no way to avoid breaking out of the WebKit for SwiftUI sandbox anyway. You may be able to use Introspect to access the underlying web view and apply the ultimate hack that way, but my recommendation is to simply start with a standard UIViewRepresentable wrapper that’s going to be backwards-compatible all the way to the initial SwiftUI release as well:

**WebView.swift**
```swift
import SwiftUI

struct WebView: UIViewRepresentable {
  
  @Binding var model: BrowserModel

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    if let url = model.url {
      webView.load(URLRequest(url: url))
    }
    model.webView = webView
    return webView
  }
  
  func updateUIView(_ view: WKWebView, context: Context) {
    model.webView = view
  }
}
```

Finally, let’s define the model that will enable the BrowserView and the WKWebView wrapper to talk to each other. In this setup, we let the BrowserView own the model as its @State. The model itself observes internal changes on the web view (it is also a natural place to implement any of the `WK*Delegates` you may require in the future), so that they could automatically refresh the browser chrome.

**BrowserModel.swift**
```swift
import Combine

@MainActor @Observable
class BrowserModel {
  var title: String = ""
  var url: URL?
  var isLoading = false
  
  @ObservationIgnored
  weak var webView: WKWebView? {
    didSet {
      observeWebView()
    }
  }
  
  private var webViewCancellables = Set<AnyCancellable>()
  
  init(url: URL?) {
    self.url = url
  }
  
  @MainActor
  deinit {
    webViewCancellables = []
  }
  
  private func observeWebView() {
    
  }
}
```

Let’s confirm this setup works by adding some observers. Here we can hook up the `title` and `isLoading` properties, as well as the `refresh` method. It’s that easy to start assembling something browser-like in SwiftUI.

**BrowserModel.swift**
```swift
class BrowserModel {

  // …
  
  func reload() {
    webView?.reload()
  }
  
  func stopLoading() {
    webView?.stopLoading()
  }
  
  private func observeWebView() {
    guard let webView else {
      webViewCancellables = []
      return
    }
    
    webViewCancellables = [
      webView.publisher(for: \.title).sink { [weak self] newTitle in
        self?.title = newTitle ?? ""
      },
      webView.publisher(for: \.url).sink { [weak self] newURL in
        self?.url = newURL
      },
      webView.publisher(for: \.isLoading).sink { [weak self] isLoading in
        self?.isLoading = isLoading
      }
    ]
  }
}
```

`[fig 6 the app so far]`

## Unlocking page zoom

We are now ready to implement page zoom controls in this app.

To unlock the full page zoom capabilities of Safari in your own WKWebView, you will be required to tap into the Objective-C runtime. If your project does not already have a bridging header configured, refer to this article to verify your setup:

`[Apple Dev bridging header doc]`

In simple words, you need an .h file in your project and a reference to that file in your project build settings. This is your bridging header. Set the contents of the file to the following:

**My-App-Bridging-Header.h**
```objective-c
#pragma once

#import "WKWebView+ViewScale.h"
````

The first line is technically optional and indicates that this file should be processed by the compiler exactly once. The second line is a reference to another header file, where we are going to define an extension (or category in Objective-C) on the WKWebView type. Create a file named WKWebView+ViewScale.h and replace its contents with:

**WKWebView+ViewScale.h**
```objective-c
@import WebKit;

@interface WKWebView (ViewScale)

@property (setter=_setTextZoomFactor:, nonatomic) double _textZoomFactor;
@property (setter=_setViewScale:, nonatomic) double _viewScale;

@end
```

You don’t need to know or remember much of Objective-C to know what’s going on here. We are interested in two properties defined on the WKWebView - `_textZoomFactor` and `_viewScale`. By re-declaring their signatures in a .h file we have made them accessible to the rest of our app’s code.

Let’s verify this by extending our BrowserModel to support this new web view functionality. The `_viewScale` is a percentage encoded as a double (i.e. 100% = `1.0`), so some reasonable logic to clamp it within a reasonable range is required.

**BrowserModel.swift**
```swift
@MainActor @Observable
class BrowserModel {
  
  // …
  
  private(set) var pageZoom: Double = 1.0 {
    didSet {
      webView?._viewScale = pageZoom
    }
  }
  
  // …
  
  func zoomIn() {
    pageZoom = min(pageZoom + 0.1, 3.0)
  }
  
  func zoomOut() {
    pageZoom = max(pageZoom - 0.1, 0.5)
  }
  
  func resetZoom() {
    pageZoom = 1.0
  }
}
```

**BrowserView.swift**
```swift
struct BrowserView: View {
  
  // …
  
  var body: some View {
    WebView(model: $model)
      .toolbar {
        // …
        
        ToolbarItemGroup {
          Menu {
            Stepper {
              Text("Zoom: \(model.pageZoom.formatted(.percent))")
            } onIncrement: {
              model.zoomIn()
            } onDecrement: {
              model.zoomOut()
            }
            if model.pageZoom != 1.0 {
              Button {
                model.resetZoom()
              } label: {
                Text("Reset")
              }
            }
          } label: {
            Label("Page Zoom", systemImage: "textformat.size")
          }
          .pickerStyle(.palette)
          #if os(iOS)
          .menuActionDismissBehavior(.disabled)
          #endif
        }
      }
  }
}
```
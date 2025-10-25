import SwiftUI

#if os(macOS)
typealias OSViewRepresentable = NSViewRepresentable
#endif
#if os(iOS) || os(visionOS)
typealias OSViewRepresentable = UIViewRepresentable
#endif

struct WebView: OSViewRepresentable {
	
	@Binding var model: BrowserModel
	
	#if os(macOS)
	func makeNSView(context: Context) -> WKWebView {
		let configuration = WKWebViewConfiguration()
		let webView = WKWebView(frame: .zero, configuration: configuration)
		if let url = model.url {
			webView.load(URLRequest(url: url))
		}
		model.webView = webView
		return webView
	}
	
	func updateNSView(_ view: WKWebView, context: Context) {
		model.webView = view
	}
	#endif
	#if os(iOS) || os(visionOS)
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
	#endif
}

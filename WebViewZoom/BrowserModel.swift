import Combine

@MainActor @Observable
class BrowserModel {
	var title: String = ""
	var url: URL?
	var isLoading = false
	
	private(set) var pageZoom: Double = 1.0 {
		didSet {
			#if os(macOS)
			webView?._textZoomFactor = pageZoom
			#endif
			#if os(iOS) || os(visionOS)
			webView?._viewScale = pageZoom
			#endif
		}
	}
	
	@ObservationIgnored
	weak var webView: WKWebView? {
		didSet {
			observeWebView()
		}
	}
	
	@ObservationIgnored
	private var webViewCancellables = Set<AnyCancellable>()
	
	init(url: URL?) {
		self.url = url
	}
	
	@MainActor
	deinit {
		webViewCancellables = []
	}
	
	func reload() {
		webView?.reload()
	}
	
	func stopLoading() {
		webView?.stopLoading()
	}
	
	func zoomIn() {
		pageZoom = min(pageZoom + 0.1, 3.0)
	}
	
	func zoomOut() {
		pageZoom = max(pageZoom - 0.1, 0.5)
	}
	
	func resetZoom() {
		pageZoom = 1.0
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

//
//  WebViewZoomApp.swift
//  WebViewZoom
//
//  Created by Arnold Sakhnov on 10/25/25.
//

import SwiftUI

@main
struct WebViewZoomApp: App {
	var body: some Scene {
		WindowGroup {
			NavigationStack {
				BrowserView()
			}
		}
		#if os(macOS)
		.windowStyle(.hiddenTitleBar)
		#endif
	}
}

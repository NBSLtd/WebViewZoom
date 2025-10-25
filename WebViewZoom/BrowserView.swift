import SwiftUI

struct BrowserView: View {
	
	@State var model = BrowserModel(
		url: URL(string: "https://www.swift.org")!
	)
	
	var body: some View {
		WebView(model: $model)
			.toolbar {
				ToolbarItem(placement: .principal) {
					HStack {
						if let host = model.url?.host() {
							AsyncImage(
								url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico"),
								content: { image in
									image.resizable()
										.aspectRatio(contentMode: .fit)
								},
								placeholder: {
									Image(systemName: "globe")
										.tint(.secondary)
										.foregroundStyle(.secondary)
								}
							)
						}
						VStack(alignment: .leading) {
							Text(model.title)
							Text(model.url?.absoluteString ?? "(empty)")
								.foregroundStyle(.secondary)
						}
						Spacer()
					}
				}
				#if !os(visionOS)
				.sharedBackgroundVisibility(.hidden)
				#endif
				
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
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(.thickMaterial, for: .navigationBar)
			.toolbarBackgroundVisibility(.visible, for: .navigationBar)
			.ignoresSafeArea(edges: [.bottom])
			#endif
	}
}

#Preview {
	NavigationStack {
		BrowserView()
	}
}

// VectorCraft for iPad: the web build (WebAssembly), bundled in the app and run offline in a
// WKWebView. See packaging/ios/README.md.

import SwiftUI

@main
struct VectorCraftApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController { WebViewController() }
    func updateUIViewController(_ controller: WebViewController, context: Context) {}
}

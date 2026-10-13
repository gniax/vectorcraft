// The full-screen web view running VectorCraft, plus what a page can't do on its own:
// - Apple Pencil double tap / squeeze (UIPencilInteraction) → `vectorcraft-pencil-tap` event;
// - File › Save / Export (browser downloads) → the Files picker (iCloud Drive, On My iPad…);
// - no page zoom, scroll or bounce, no link previews.

import UIKit
import UniformTypeIdentifiers
import WebKit

final class WebViewController: UIViewController {
    private var webView: WKWebView!
    /// Where each download is written before it is handed to the Files picker.
    private var downloads: [ObjectIdentifier: URL] = [:]

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: BundleSchemeHandler.scheme)
        config.websiteDataStore = .default()
        config.preferences.isElementFullscreenEnabled = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        config.dataDetectorTypes = []

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = true
        webView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        view = webView

        let pencil = UIPencilInteraction()
        pencil.delegate = self
        webView.addInteraction(pencil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: BundleSchemeHandler.startURL))
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    // Edge swipes reach the app first (a pen stroke from the screen's edge).
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    /// Tell the page about a Pencil double tap or squeeze, with the action chosen in Settings.
    private func pencilTap(_ action: String) {
        let js = "window.dispatchEvent(new CustomEvent('vectorcraft-pencil-tap', { detail: '\(action)' }))"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func action(_ preferred: UIPencilPreferredAction) -> String? {
        switch preferred {
        case .switchEraser: return "switchEraser"
        case .switchPrevious: return "switchPrevious"
        case .showColorPalette: return "showColorPalette"
        default: return nil
        }
    }

    /// Hand a downloaded file to the Files picker, so the user saves it where they want.
    private func export(_ file: URL) {
        let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
        picker.shouldShowFileExtensions = true
        present(picker, animated: true)
    }
}

extension WebViewController: UIPencilInteractionDelegate {
    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        if let a = Self.action(UIPencilInteraction.preferredTapAction) { pencilTap(a) }
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        if squeeze.phase == .ended, let a = Self.action(UIPencilInteraction.preferredSqueezeAction) { pencilTap(a) }
    }

    // Before iOS 17.5.
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        if let a = Self.action(UIPencilInteraction.preferredTapAction) { pencilTap(a) }
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if action.shouldPerformDownload {
            decisionHandler(.download, preferences)
            return
        }
        // Links out of the app (Help, Discord, GitHub) open in Safari.
        if let url = action.request.url, let scheme = url.scheme, scheme == "https" || scheme == "http" || scheme == "mailto" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel, preferences)
            return
        }
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // The web content process died (memory pressure): reload; Data Recovery offers the unsaved work.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.load(URLRequest(url: BundleSchemeHandler.startURL))
    }
}

extension WebViewController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            completionHandler(nil)
            return
        }
        let name = suggestedFilename.isEmpty ? "VectorCraft" : suggestedFilename
        let file = dir.appendingPathComponent(name)
        downloads[ObjectIdentifier(download)] = file
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        export(file)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download))
    }
}

extension WebViewController: WKUIDelegate {
    // window.open (Help pages): open in Safari.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}

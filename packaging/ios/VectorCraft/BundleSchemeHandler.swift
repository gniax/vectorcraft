// Serves the bundled web build (the `web` folder) at vectorcraft://localhost/, so the page has a
// real origin: WebAssembly streaming, localStorage (Data Recovery) and Web Locks work, which a
// file:// page doesn't get.

import Foundation
import WebKit

final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "vectorcraft"
    static let startURL = URL(string: "\(scheme)://localhost/index.html")!

    private let root: URL? = Bundle.main.resourceURL?.appendingPathComponent("web", isDirectory: true)

    private static let mimeTypes: [String: String] = [
        "html": "text/html; charset=utf-8",
        "js": "text/javascript; charset=utf-8",
        "wasm": "application/wasm",
        "css": "text/css; charset=utf-8",
        "json": "application/json",
        "svg": "image/svg+xml",
        "png": "image/png",
        "ttf": "font/ttf",
        "otf": "font/otf",
        "woff2": "font/woff2",
        "txt": "text/plain; charset=utf-8",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let root else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        // Never serve anything outside the web folder.
        guard file.path.hasPrefix(root.standardizedFileURL.path),
              let data = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
            task.didReceive(response)
            task.didFinish()
            return
        }
        let mime = Self.mimeTypes[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let headers = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

import Foundation
import WebKit

/// Mirrors the SDK's loading lifecycle (see `docs/features/loading-state.md`).
enum MapLoadState: Equatable {
    case loading
    case ready
    case error(String)
}

/// Two-way bridge to the SDK running inside `MapWebView`.
///
/// - Native -> JS: calls into `window.MapBridge`, defined in `map.html`, via
///   `evaluateJavaScript`.
/// - JS -> native: implements `WKScriptMessageHandler`, receiving `{type, message?}`
///   payloads posted from `map.html` via `window.webkit.messageHandlers.mapBridge`.
///   See `docs/APP_SDK_COMMUNICATION.md` for the pattern this follows.
final class VisioOneBridge: NSObject, WKScriptMessageHandler, ObservableObject {
    static let messageHandlerName = "mapBridge"

    @Published private(set) var loadState: MapLoadState = .loading

    /// Set by `MapWebView.makeUIView` once the underlying `WKWebView` exists.
    weak var webView: WKWebView?

    /// Updates a POI's surface color to reflect an occupancy status
    /// (`color: nil` resets the surface to its normal appearance).
    ///
    /// Arguments are JSON-encoded via `JSONSerialization` before being
    /// interpolated into the generated script — never raw string
    /// concatenation, to avoid JS injection (same rule as the other
    /// platforms' native<->JS bridges).
    func updateOccupancy(planId: String, color: String?) {
        guard let webView else { return }

        let entry: [String: Any] = ["planId": planId, "color": color ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: [entry]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.updateOccupancy(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: updateOccupancy failed: \(error.localizedDescription)")
            }
        }
    }

    /// Resets to `.loading` and reloads the page, rather than leaving the UI
    /// stuck on `.error` until the next JS message arrives.
    func reload() {
        loadState = .loading
        webView?.reload()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            loadState = .ready
        case "error":
            loadState = .error(body["message"] as? String ?? "Erreur inconnue du SDK VisioOne")
        default:
            break
        }
    }
}

/// `WKUserContentController.add(_:name:)` strongly retains its handler — registering
/// this proxy instead of `VisioOneBridge` directly avoids a retain cycle with the web view.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

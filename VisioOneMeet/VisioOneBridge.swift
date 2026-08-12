import Foundation
import WebKit

/// Native -> JS bridge to the SDK running inside `MapWebView`.
///
/// There is currently no JS -> native direction (no `WKScriptMessageHandler`):
/// `map.html` reports nothing back to Swift yet (see `docs/APP_SDK_COMMUNICATION.md`
/// for the intended pattern once that's needed). This class only calls into
/// `window.MapBridge`, defined in `map.html`.
final class VisioOneBridge: ObservableObject {
    /// Set by `MapWebView.makeUIView` once the underlying `WKWebView` exists.
    weak var webView: WKWebView?

    /// Recenters the camera on the venue via `view.goToGlobal()`.
    ///
    /// Silent no-op on the JS side if `view` isn't set yet (i.e. before
    /// `createView` has resolved) — see `map.html`.
    func goToGlobal() {
        webView?.evaluateJavaScript("window.MapBridge.goToGlobal()") { _, error in
            if let error {
                print("VisioOneBridge: goToGlobal failed: \(error.localizedDescription)")
            }
        }
    }

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
}

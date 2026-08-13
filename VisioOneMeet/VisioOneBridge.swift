import Foundation
import WebKit

/// Mirrors the SDK's loading lifecycle (see `docs/features/loading-state.md`).
enum MapLoadState: Equatable {
    case loading
    case ready
    case error(String)
}

/// A POI tapped on the map, forwarded by the SDK's `poiclick` event
/// (see `docs/features/poi-click.md`). `name` mirrors whatever the SDK
/// resolves as the POI's first label for the current locale — `nil` if the
/// POI has no label at all.
struct TappedPOI: Equatable {
    let id: String
    let name: String?
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

    /// Last POI tapped on the map, `nil` once the reaction panel has been
    /// dismissed. See `docs/features/poi-click.md`.
    @Published private(set) var tappedPOI: TappedPOI?

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

    /// Centers/zooms the camera on a POI by ID via `view.goToPOI()`, and
    /// highlights its surfaces (see `docs/features/goto-poi.md`).
    ///
    /// `poiId` is JSON-encoded before being interpolated into the generated
    /// script, same rule as `updateOccupancy` above — never raw string
    /// concatenation.
    func goToPOI(_ poiId: String) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.goToPOI(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: goToPOI failed: \(error.localizedDescription)")
            }
        }
    }

    /// Clears whatever highlight `goToPOI` left on the map, without moving
    /// the camera (see `docs/features/goto-poi.md`).
    func clearPOI() {
        webView?.evaluateJavaScript("window.MapBridge.clearPOI()") { _, error in
            if let error {
                print("VisioOneBridge: clearPOI failed: \(error.localizedDescription)")
            }
        }
    }

    /// Resets to `.loading` and reloads the page, rather than leaving the UI
    /// stuck on `.error` until the next JS message arrives.
    func reload() {
        loadState = .loading
        webView?.reload()
    }

    /// Resets the reaction panel's source of truth, e.g. once the user
    /// dismisses it — so tapping the same POI again is still detected as a
    /// change (`tappedPOI` going `nil` -> non-`nil`).
    func clearTappedPOI() {
        tappedPOI = nil
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
        case "poiSelected":
            guard let payload = body["message"] as? [String: Any],
                  let id = payload["id"] as? String else { return }
            tappedPOI = TappedPOI(id: id, name: payload["name"] as? String)
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

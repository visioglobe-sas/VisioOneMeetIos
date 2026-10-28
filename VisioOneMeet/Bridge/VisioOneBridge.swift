import Foundation
import WebKit

/// Mirrors the SDK's loading lifecycle (see `docs/features/loading-state.md`).
enum MapLoadState: Equatable {
    case loading
    case ready
    case error(String)
}

/// The load/creation-time options of the page, passed to `map.html` as
/// query items by `MapWebView` (read back in `bridge/core.js`). They can't
/// change on a loaded map: a new value recreates the `WKWebView` (the
/// feature screen keys `MapWebView`'s `.id()` on them), i.e. a fresh
/// `loadVenue` + `createView`. Each screen starts from its
/// `Feature.pageOptions`.
struct MapPageOptions: Hashable {
    /// Map hash to load (values in `DemoMap.swift`).
    var mapHash: String?
    /// `loadVenue`'s `baseURL` (custom-base-url only); `nil` keeps the SDK
    /// default.
    var baseURL: String?
    /// `createView`'s `enableShadows` (custom-theme only).
    var enableShadows = false
    /// `createView`'s `cameraProjection` (camera-projection-toggle only);
    /// `nil` keeps the SDK default.
    var cameraProjection: CameraProjection?
}

/// Two-way bridge to the SDK running inside `MapWebView`. This is the core
/// only: the web view, the loading state, the two message channels and the
/// map reload. Each feature's own calls live next to that feature, as an
/// extension in `Features/<Feature>/<Feature>+Bridge.swift`, and each
/// feature's state in its own model (`Features/<Feature>/<Feature>Model.swift`).
///
/// - Native -> JS: `call(_:args:)` / `callForResult(_:args:)` /
///   `callForStatus(_:args:)` run `window.MapBridge.<function>(...)`,
///   defined by `WebContent/features/<slug>.js`, through
///   `callAsyncJavaScript`: the arguments are passed as real JS values
///   (never interpolated into the script, so no JS injection), and a
///   returned Promise is awaited.
/// - JS -> native: implements `WKScriptMessageHandler`, receiving
///   `{type, message?}` payloads posted from the page via
///   `window.webkit.messageHandlers.mapBridge` (`sendToNative` in
///   `bridge/core.js`). The core handles the loading lifecycle; every other
///   message type goes to the handlers features register with
///   `onMessage(_:_:)`.
///
/// See `docs/APP_SDK_COMMUNICATION.md` for the pattern this follows.
@MainActor
final class VisioOneBridge: NSObject, WKScriptMessageHandler, ObservableObject {
    static let messageHandlerName = "mapBridge"

    @Published private(set) var loadState: MapLoadState = .loading

    /// The options the current page was loaded with. See `MapPageOptions`.
    @Published private(set) var pageOptions: MapPageOptions

    /// Set by `MapWebView.makeUIView` once the underlying `WKWebView` exists.
    weak var webView: WKWebView?

    /// The page `MapWebView` loaded (with its query items) and the directory
    /// WebKit may read from, kept so `reload()` can load it again even when
    /// the first navigation failed (nothing to `WKWebView.reload()` then).
    var pageURL: URL?
    var pageReadAccessURL: URL?

    typealias MessageHandler = (_ payload: Any?) -> Void

    private var messageHandlers: [String: [MessageHandler]] = [:]
    private var reloadHandlers: [() -> Void] = []

    init(pageOptions: MapPageOptions = MapPageOptions()) {
        self.pageOptions = pageOptions
        super.init()
    }

    // MARK: - Feature hooks

    /// Calls `handler` with the `message` payload of every JS -> native
    /// message of this `type` (e.g. `"floorsChanged"`). `"ready"` handlers
    /// run before `loadState` turns `.ready`.
    func onMessage(_ type: String, _ handler: @escaping MessageHandler) {
        messageHandlers[type, default: []].append(handler)
    }

    /// Calls `handler` whenever the map is about to be loaded again (Retry,
    /// new `MapPageOptions`): the page, and every SDK object on it, is
    /// thrown away, so a feature resets the state it mirrors from the map.
    func onReload(_ handler: @escaping () -> Void) {
        reloadHandlers.append(handler)
    }

    // MARK: - Native -> JS

    enum CallError: LocalizedError {
        case mapNotReady

        var errorDescription: String? { "Map not ready" }
    }

    /// Runs `window.MapBridge.<function>(args...)`, fire-and-forget. A
    /// failure (the JS function threw, or the map isn't there) is only
    /// logged. `nil` arguments arrive as JS `null`.
    func call(_ function: String, args: [Any?] = []) {
        run(function, args) { _ in }
    }

    /// `call` for the JS functions that report their outcome as a
    /// `{ status, message? }` object: an outcome other than success is
    /// logged too.
    func callReportingStatus(_ function: String, args: [Any?] = []) {
        run(function, args) { result in
            if case .success(let value) = result, BridgeResult(payload: value) != .success {
                print("VisioOneBridge: \(function) failed: \(BridgeResult(payload: value))")
            }
        }
    }

    /// Runs `window.MapBridge.<function>(args...)` and returns what it
    /// returned (`nil` for `undefined`/`null`) once any returned Promise has
    /// settled. A failure (the JS function threw or rejected, or the map
    /// isn't there) is logged and returned as `.failure`.
    func callForResult(_ function: String, args: [Any?] = []) async -> Result<Any?, Error> {
        await withCheckedContinuation { continuation in
            run(function, args) { continuation.resume(returning: $0) }
        }
    }

    /// `callForResult` for the JS functions that report their outcome as a
    /// `{ status, message? }` object, mapped to a `BridgeResult`.
    func callForStatus(_ function: String, args: [Any?] = []) async -> BridgeResult {
        switch await callForResult(function, args: args) {
        case .success(let value):
            let result = BridgeResult(payload: value)
            if case .bridgeError(let message) = result {
                print("VisioOneBridge: \(function) failed: \(message)")
            }
            return result
        case .failure(let error):
            return .bridgeError(error.localizedDescription)
        }
    }

    /// The one place that talks to the page: `callAsyncJavaScript` passes
    /// `args` as real JS values and waits for a returned Promise. Calls are
    /// sent in order. Failures are logged.
    private func run(_ function: String, _ args: [Any?], completion: @escaping (Result<Any?, Error>) -> Void) {
        guard let webView else {
            completion(.failure(CallError.mapNotReady))
            return
        }
        let (script, arguments) = Self.script(function, args)
        webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                completion(.success(value is NSNull ? nil : value))
            case .failure(let error):
                print("VisioOneBridge: \(function) failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// `return window.MapBridge.<function>(a0, a1, ...);` and its
    /// `callAsyncJavaScript` arguments `["a0": ..., "a1": ...]`.
    private static func script(_ function: String, _ args: [Any?]) -> (String, [String: Any]) {
        let names = args.indices.map { "a\($0)" }
        var arguments: [String: Any] = [:]
        for (name, value) in zip(names, args) {
            arguments[name] = value ?? NSNull()
        }
        return ("return window.MapBridge.\(function)(\(names.joined(separator: ", ")));", arguments)
    }

    // MARK: - Reload

    /// Resets to `.loading` and loads the page again (the error screen's
    /// Retry button). `WKWebView.reload()` does nothing when the first
    /// navigation never committed (e.g. `map.html` failed to load), so in
    /// that case `pageURL` is loaded from scratch instead.
    func reload() {
        willReload()
        guard let webView else { return }
        if webView.url == nil, let pageURL, let pageReadAccessURL {
            webView.loadFileURL(pageURL, allowingReadAccessTo: pageReadAccessURL)
        } else {
            webView.reload()
        }
    }

    /// Loads the map again with other load/creation-time options. A new
    /// value changes the feature screen's `.id(...)` on `MapWebView`, which
    /// makes SwiftUI tear down and recreate the `WKWebView` from scratch (a
    /// fresh `loadFileURL` with the new query items, see `MapWebView.swift`);
    /// the same value wouldn't change the `.id()`, so this falls back to
    /// `reload()` instead. Either way `loadState` resets to `.loading` first
    /// so the UI doesn't sit on a stale `.ready`/`.error` while the new load
    /// is in flight.
    func reloadPage(with options: MapPageOptions) {
        if options == pageOptions {
            reload()
        } else {
            willReload()
            pageOptions = options
        }
    }

    private func willReload() {
        loadState = .loading
        reloadHandlers.forEach { $0() }
    }

    /// Called by `MapWebView`'s navigation delegate when the page itself
    /// failed to load (no SDK message will ever arrive then): shows the
    /// error screen instead of an endless spinner. See
    /// `docs/features/loading-state.md`.
    func pageLoadFailed(_ error: Error) {
        // A navigation cancelled by a newer one (e.g. Retry) is not a failure.
        if (error as NSError).code == NSURLErrorCancelled { return }
        print("VisioOneBridge: map page failed to load: \(error.localizedDescription)")
        loadState = .error(error.localizedDescription)
    }

    // MARK: - JS -> native

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        let payload = body["message"]

        messageHandlers[type]?.forEach { $0(payload) }

        switch type {
        case "ready":
            loadState = .ready
        case "error":
            loadState = .error(payload as? String ?? String(localized: "Unknown VisioOne SDK error"))
        case Self.unauthorizedMessageType:
            // auth-token sample: loadVenue rejected with the SDK's
            // UnauthorizedError, reported apart from other load errors.
            // See docs/features/auth-token.md.
            let detail = payload as? String ?? ""
            print("VisioOneBridge: protected map rejected: token invalid, expired or missing (\(detail))")
            loadState = .error(String(localized: "Token invalid, expired or missing. \(detail)"))
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

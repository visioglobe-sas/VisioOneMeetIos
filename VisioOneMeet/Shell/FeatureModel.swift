import Combine
import SwiftUI

/// What one feature brings to its map screen: its state, its control panel,
/// and its reactions to the screen's lifecycle. One instance per screen,
/// created by `Feature.makeModel` with that screen's bridge and owned by the
/// screen (`FeatureScreen`), never by the panel: the `.sheet` content is
/// recreated every time it opens, so state kept here survives closing the
/// panel to look at the map, there is only ever one loop per screen, and
/// leaving the screen stops it (`screenDidDisappear()`).
///
/// The models live in `Features/<Feature>/<Feature>Model.swift`.
@MainActor
protocol FeatureModel: AnyObject {
    /// The control panel content, shown in the bottom sheet.
    func makePanel() -> AnyView

    /// How the panel opens. Defaults to `.fab`.
    var panelTrigger: PanelTrigger { get }

    /// The map turned `.ready` (first load or reload).
    func mapDidBecomeReady()

    /// The panel was dismissed (swipe down or tap outside).
    func panelDidDismiss()

    /// Back to the menu: stop whatever this feature keeps running.
    func screenDidDisappear()
}

enum PanelTrigger {
    /// A floating action button on the map opens the panel.
    case fab
    /// No FAB: the panel opens when `requests` emits `true` and closes on
    /// `false` (poi-click opens it from the SDK's own `poiclick` event);
    /// `hint` is shown on the map while it's closed.
    case automatic(requests: AnyPublisher<Bool, Never>, hint: LocalizedStringKey)
}

extension FeatureModel {
    var panelTrigger: PanelTrigger { .fab }
    func mapDidBecomeReady() {}
    func panelDidDismiss() {}
    func screenDidDisappear() {}
}

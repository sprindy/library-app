import Foundation
import Observation

extension Notification.Name {
    static let uiCommandCenterNewBookRequested = Notification.Name("UICommandCenter.newBookRequested")
    static let uiCommandCenterFocusSearchRequested = Notification.Name("UICommandCenter.focusSearchRequested")
}

@Observable
final class UICommandCenter {
    var newBookSignal: Int = 0
    var focusSearchSignal: Int = 0

    func triggerNewBook() {
        newBookSignal += 1
        NotificationCenter.default.post(name: .uiCommandCenterNewBookRequested, object: nil)
    }

    func triggerFocusSearch() {
        focusSearchSignal += 1
        NotificationCenter.default.post(name: .uiCommandCenterFocusSearchRequested, object: nil)
    }
}

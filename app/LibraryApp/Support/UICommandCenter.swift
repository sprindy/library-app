import Foundation
import Observation

@Observable
final class UICommandCenter {
    var newBookSignal: Int = 0
    var focusSearchSignal: Int = 0

    func triggerNewBook() {
        newBookSignal += 1
    }

    func triggerFocusSearch() {
        focusSearchSignal += 1
    }
}

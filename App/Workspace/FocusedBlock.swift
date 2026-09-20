import SwiftUI

/// Publishes which block currently contains keyboard focus, so menu bar
/// commands (Move Block Up/Down, Delete Block) know what to act on.
struct ActiveBlockIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var activeBlockID: UUID? {
        get { self[ActiveBlockIDKey.self] }
        set { self[ActiveBlockIDKey.self] = newValue }
    }
}

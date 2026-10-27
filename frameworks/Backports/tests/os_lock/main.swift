import Foundation
import os

func withLock(_ body: () -> Void) {
    var lock = os_unfair_lock()
    os_unfair_lock_lock(&lock)
    body()
    os_unfair_lock_unlock(&lock)
}

final class Gate {
    private var lock = os_unfair_lock()

    func enter() -> Bool {
        if os_unfair_lock_trylock(&self.lock) {
            os_unfair_lock_assert_owner(&self.lock)
            os_unfair_lock_unlock(&self.lock)
            return true
        }
        os_unfair_lock_assert_not_owner(&self.lock)
        return false
    }
}

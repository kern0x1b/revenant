import os

func withLock(_ body: () -> Void) {
    var lock = os_unfair_lock()
    os_unfair_lock_lock(&lock)
    body()
    os_unfair_lock_unlock(&lock)
}

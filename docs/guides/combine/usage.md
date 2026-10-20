# Use Combine

```swift
import Combine

final class Counter: ObservableObject {
    @Published var value = 0
}

let counter = Counter()
var bag = Set<AnyCancellable>()

counter.objectWillChange
    .sink { _ in print("will change") }
    .store(in: &bag)

Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .sink { _ in counter.value += 1 }
    .store(in: &bag)
```

import SwiftUI

final class Store: ObservableObject {
  @Published var count = 0
}

func read(_ store: Store) -> Int {
  store.count
}

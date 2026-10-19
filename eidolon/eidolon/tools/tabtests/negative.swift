import SwiftUI

// A view is not tab content: a TabContent's body is more tab content, and a Text is not.
struct NotTabContent: View {
    var body: some View { Text("not a tab") }
}

func aViewIsNotTabContent() {
    let _: any TabContent = NotTabContent()
}

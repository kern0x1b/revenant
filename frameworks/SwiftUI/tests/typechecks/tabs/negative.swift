import SwiftUI

struct NotTabContent: View {
    var body: some View { Text("not a tab") }
}

func aViewIsNotTabContent() {
    let _: any TabContent = NotTabContent()
}

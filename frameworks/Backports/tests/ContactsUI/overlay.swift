import SwiftUI
import ContactsUI

@available(iOS 18.0, *)
struct ContactAccessPickerHostingView: View {
    @State var presented = true
    var handler: ([String]) -> ()

    init(completionHandler: @escaping ([String]) -> ()) {
        self.handler = completionHandler
    }

    var body: some View {
        Spacer()
            .contactAccessPicker(isPresented: $presented, completionHandler: handler)
            .onChange(of: presented) { newValue in
                if newValue == false {
                    handler([])
                }
            }
    }
}

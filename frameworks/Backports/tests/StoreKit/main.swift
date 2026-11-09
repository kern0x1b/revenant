import Foundation

let url = AppStoreSubscriptions.url
print("url \(url.absoluteString)")
print("scheme \(url.scheme ?? "")")
print("pane \(url.path)")

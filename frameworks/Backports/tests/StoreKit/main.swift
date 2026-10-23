import Foundation

let url = AppStoreSubscriptions.url
print("url \(url.absoluteString)")
print("scheme \(url.scheme ?? "")")
print("host \(url.host ?? "")")
print("path \(url.path)")

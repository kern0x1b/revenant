import Foundation

final class DataSink: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

func delegates(_ sink: DataSink) -> [any URLSessionDelegate] {
    let task: any URLSessionTaskDelegate = sink
    let data: any URLSessionDataDelegate = sink
    let download: any URLSessionDownloadDelegate = sink
    return [sink, task as any URLSessionDelegate, data as any URLSessionDelegate, download as any URLSessionDelegate]
}

import UIKit
import CoreGraphics

extension Text {
    public enum DateStyle {
        case time, date, relative, offset, timer

        func string(for date: Date) -> String {
            let formatter = DateFormatter()
            switch self {
            case .time:
                formatter.timeStyle = .short
                formatter.dateStyle = .none
            case .date:
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
            case .relative, .offset, .timer:
                let seconds = Int(abs(date.timeIntervalSinceNow))
                let minutes = seconds / 60
                if minutes < 60 { return "\(minutes) min" }
                return "\(minutes / 60) hr"
            }
            return formatter.string(from: date)
        }
    }

    public init(_ date: Date, style: DateStyle) {
        self.init(verbatim: style.string(for: date))
    }

    public init(_ dates: ClosedRange<Date>) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.init(verbatim: formatter.string(from: dates.lowerBound) + " – " + formatter.string(from: dates.upperBound))
    }
}

public struct AsyncImage<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let url: URL?
    let scale: CGFloat
    let makeContent: ((AsyncImagePhase) -> Content)?
    func makeNode(_ env: EnvironmentValues) -> Node { let n = AsyncImageNode(); n.update(self, env); return n }
}

public enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)

    public var image: Image? {
        if case .success(let image) = self { return image }
        return nil
    }
}

extension AsyncImage where Content == Image {
    public init(url: URL?, scale: CGFloat = 1) {
        self.init(url: url, scale: scale, makeContent: nil)
    }
}

protocol AsyncImageLike {
    var imageURL: URL? { get }
}

extension AsyncImage: AsyncImageLike {
    var imageURL: URL? { url }
}

final class AsyncImageNode: LayoutNode {
    var loaded: UIImage?
    var requested: URL?
    let spinner = UIActivityIndicatorView(style: .gray)

    init() {
        super.init(view: UIImageView())
        uiView.addSubview(spinner)
        (uiView as! UIImageView).contentMode = .scaleAspectFit
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? AsyncImageLike, let url = source.imageURL else { return }
        guard requested != url else { return }
        requested = url
        spinner.startAnimating()
        let request = NSURLRequest(url: url)
        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: .main) { [weak self] _, data, _ in
            guard let self else { return }
            self.spinner.stopAnimating()
            guard let data, let image = UIImage(data: data) else { return }
            self.loaded = image
            (self.uiView as! UIImageView).image = image
            self.invalidateLayout()
            Updates.flush()
            self.parent?.flattened.first?.uiView.setNeedsLayout()
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        if let loaded { return CGSize(width: p.width ?? loaded.size.width, height: p.height ?? loaded.size.height) }
        return CGSize(width: p.width ?? 40, height: p.height ?? 40)
    }

    override func layoutContents(_ size: CGSize) {
        spinner.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }
}

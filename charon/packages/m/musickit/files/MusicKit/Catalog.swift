import Foundation

public struct MusicCatalogSearchRequest {

    public let term: String
    public let types: [String]
    public var limit: Int?
    public var offset: Int?
    public var includeTopResults: Bool

    public init(term: String, types: [String]) {
        self.term = term
        self.types = types
        self.limit = nil
        self.offset = nil
        self.includeTopResults = true
    }

    public func url(storefront: String = MusicCatalogSearchRequest.defaultStorefront) -> URL? {
        guard var components = URLComponents(string: MusicAPIs.catalogURL(storefront: storefront, path: "search")?.absoluteString ?? "") else {
            return nil
        }
        var items = [URLQueryItem(name: "term", value: term),
                     URLQueryItem(name: "types", value: types.joined(separator: ","))]
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset { items.append(URLQueryItem(name: "offset", value: String(offset))) }
        components.queryItems = items
        return components.url
    }

    public static let defaultStorefront = "us"
}

public struct MusicCatalogResourceRequest {

    public let type: String
    public let id: MusicItemID
    public var limit: Int?
    public var properties: [String]

    public init(type: String, id: MusicItemID) {
        self.type = type
        self.id = id
        self.limit = nil
        self.properties = []
    }

    public func url(storefront: String = MusicCatalogResourceRequest.defaultStorefront) -> URL? {
        guard let base = MusicAPIs.catalogURL(storefront: storefront, path: "\(type)/\(id.rawValue)") else {
            return nil
        }
        guard !properties.isEmpty,
              var components = URLComponents(string: base.absoluteString) else { return base }
        components.queryItems = [URLQueryItem(name: "include", value: properties.joined(separator: ","))]
        return components.url
    }

    public static let defaultStorefront = MusicCatalogSearchRequest.defaultStorefront
}

public struct MusicCatalogChartRequest {

    public let type: String
    public var limit: Int?

    public init(type: String) {
        self.type = type
        self.limit = nil
    }

    public func url(storefront: String = MusicCatalogChartRequest.defaultStorefront) -> URL? {
        guard let base = MusicAPIs.catalogURL(storefront: storefront, path: "charts/\(type)") else {
            return nil
        }
        guard let limit,
              var components = URLComponents(string: base.absoluteString) else { return base }
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        return components.url
    }

    public static let defaultStorefront = MusicCatalogSearchRequest.defaultStorefront
}

public struct MusicDataRequest: Hashable {
    public let urlRequest: URLRequest
    public init(urlRequest: URLRequest) { self.urlRequest = urlRequest }
}

public struct MusicCatalogSearchResponse {
    public let songs: MusicItemCollection<Song>
    public let albums: MusicItemCollection<Album>
    public let artists: MusicItemCollection<Artist>
    public let playlists: MusicItemCollection<Playlist>

    public init(songs: MusicItemCollection<Song> = MusicItemCollection<Song>(),
                albums: MusicItemCollection<Album> = MusicItemCollection<Album>(),
                artists: MusicItemCollection<Artist> = MusicItemCollection<Artist>(),
                playlists: MusicItemCollection<Playlist> = MusicItemCollection<Playlist>()) {
        self.songs = songs
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
    }
}

public struct MusicItemCollection<Item: MusicItem> {
    public let items: [Item]
    public let next: URL?

    public init(items: [Item] = [], next: URL? = nil) {
        self.items = items
        self.next = next
    }

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }
    public var hasNextBatch: Bool { next != nil }
    public var first: Item? { items.first }
    public var last: Item? { items.last }

    public subscript(index: Int) -> Item? {
        index >= 0 && index < items.count ? items[index] : nil
    }
}

public struct Song: MusicItem {
    public let id: MusicItemID
    public let title: String
    public let artistName: String
    public let albumTitle: String?
    public let artwork: Artwork?
    public let durationInMillis: Int?
    public let url: URL?

    public init(id: MusicItemID, title: String, artistName: String, albumTitle: String? = nil,
                artwork: Artwork? = nil, durationInMillis: Int? = nil, url: URL? = nil) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.artwork = artwork
        self.durationInMillis = durationInMillis
        self.url = url
    }
}

public struct Album: MusicItem {
    public let id: MusicItemID
    public let title: String
    public let artistName: String
    public let trackCount: Int?
    public let artwork: Artwork?
    public let url: URL?

    public init(id: MusicItemID, title: String, artistName: String, trackCount: Int? = nil,
                artwork: Artwork? = nil, url: URL? = nil) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.trackCount = trackCount
        self.artwork = artwork
        self.url = url
    }
}

public struct Artist: MusicItem {
    public let id: MusicItemID
    public let name: String
    public let genre: String?
    public let artwork: Artwork?
    public let url: URL?

    public init(id: MusicItemID, name: String, genre: String? = nil,
                artwork: Artwork? = nil, url: URL? = nil) {
        self.id = id
        self.name = name
        self.genre = genre
        self.artwork = artwork
        self.url = url
    }
}

public struct Playlist: MusicItem {
    public let id: MusicItemID
    public let name: String
    public let curatorName: String?
    public let artwork: Artwork?
    public let url: URL?

    public init(id: MusicItemID, name: String, curatorName: String? = nil,
                artwork: Artwork? = nil, url: URL? = nil) {
        self.id = id
        self.name = name
        self.curatorName = curatorName
        self.artwork = artwork
        self.url = url
    }
}

public struct Artwork: Hashable {
    public let url: URL
    public let width: Int
    public let height: Int

    public init(url: URL, width: Int, height: Int) {
        self.url = url
        self.width = width
        self.height = height
    }

    public func url(width: Int, height: Int) -> URL? {
        guard let base = url.absoluteString.split(separator: "{w}").first,
              let tail = url.absoluteString.split(separator: "}").last else { return nil }
        return URL(string: "\(base)\(width)x\(height)\(tail)")
    }
}

// The catalogue requests: search, and the resource of a type, over the documented Apple Music API.
//
// The service is Apple's and the paths are the ones its reference names, under a storefront:
//
//     GET /v1/catalog/{storefront}/search?term=…&types=song,album&limit=…&offset=…
//     GET /v1/catalog/{storefront}/{type}/{id}?include=…&limit=…
//     GET /v1/catalog/{storefront}/{type}/{id}/relationships/…
//     GET /v1/catalog/{storefront/charts/{type}
//
// every one of them authenticated with `Authorization: Bearer <developer token>`, and every one of
// them answered with the service's own JSON, which is what the types below are decoded from.
//
// What the responses are built from, and what a request cannot do without, are both the service's.
// A request with no developer token fails with `MusicError.developerTokenUnauthorized` before a byte
// is sent, because the service would refuse it and a caller that waited for that would be waiting on
// a round trip to learn nothing.

import Foundation

// MARK: - The catalogue requests

/// A search of the catalogue, of the types the caller names.
public struct MusicCatalogSearchRequest {

    /// The term the caller is searching for, and the types to search.
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

    /// The URL this request is, in a storefront. The term and the types are percent-encoded, and
    /// nothing else about the call is invented: a request the service does not document is not one
    /// this module sends.
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

    /// The storefront a request is made in when the caller names none.
    ///
    /// A device has a region and the service has a storefront per region, and this release has no
    /// way to ask the device which one it is: `Locale.current` is iOS 10. So the storefront is the
    /// one the developer registered, which is what a client of the Apple Music API is given, and
    /// `us` is the documented default.
    public static let defaultStorefront = "us"
}

/// One resource of the catalogue - a song, an album, an artist - found by its identifier.
public struct MusicCatalogResourceRequest {

    /// The type of the resource, as the service names it: `songs`, `albums`, `artists`.
    public let type: String
    /// The identifier, which is the catalogue's own for the item.
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

/// The charts of a storefront, for a type.
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

/// A request whose URL the caller has built, which is what `MusicDataRequest` is.
public struct MusicDataRequest: Hashable {
    public let urlRequest: URLRequest
    public init(urlRequest: URLRequest) { self.urlRequest = urlRequest }
}

// MARK: - The answers

/// What a search found, per type. A type the caller did not ask for is empty rather than absent,
/// which is what the service sends and what the interface's own properties say.
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

/// A run of items, with the URL of the next page when there is one.
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

// MARK: - The catalogue types
//
// The fields the service sends for each, and no others: a type that carried a field the service does
// not send would be a value this port invented, and a caller of MusicKit 26 reading it would be
// reading something no catalogue has.

/// A song: an identifier, the artwork, and the names it is known by.
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

/// An album: an identifier, a title, the artist and the number of tracks.
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

/// An artist: an identifier, a name, and the genres the service places them in.
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

/// A playlist: an identifier, a name, and the curator behind it.
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

/// The artwork of an item, and the sizes it is served at.
public struct Artwork: Hashable {
    public let url: URL
    public let width: Int
    public let height: Int

    public init(url: URL, width: Int, height: Int) {
        self.url = url
        self.width = width
        self.height = height
    }

    /// The URL of the artwork at a size, which is the service's own `{w}x{h}` form.
    public func url(width: Int, height: Int) -> URL? {
        guard let base = url.absoluteString.split(separator: "{w}").first,
              let tail = url.absoluteString.split(separator: "}").last else { return nil }
        return URL(string: "\(base)\(width)x\(height)\(tail)")
    }
}

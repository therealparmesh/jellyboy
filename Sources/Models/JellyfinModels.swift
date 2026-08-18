import Foundation

struct JellyfinSession: Codable, Hashable, Identifiable {
    let serverURL: String
    let userID: String
    let username: String
    let accessToken: String
    let deviceID: String
    let isDemo: Bool

    var id: String { "\(serverURL)|\(userID)" }
    var baseURL: URL? { URL(string: serverURL) }

    static func demo() -> JellyfinSession {
        JellyfinSession(
            serverURL: "demo://sample-save",
            userID: "demo-user",
            username: "PLAYER ONE",
            accessToken: "",
            deviceID: "demo-device",
            isDemo: true
        )
    }
}

struct AuthenticationResult: Decodable {
    let user: JellyfinUser?
    let accessToken: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
    }
}

struct JellyfinUser: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct ItemQueryResult: Decodable {
    let items: [MediaItem]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

struct MediaLibraryQueryResult: Decodable {
    let items: [MediaLibrary]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

struct MediaLibrary: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let collectionType: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
    }

    var includedItemTypes: String {
        switch collectionType?.lowercased() {
        case "movies": "Movie"
        case "tvshows": "Series"
        case "music": "Audio"
        case "musicvideos": "MusicVideo"
        case "homevideos", "homevideosandphotos": "Video"
        default: "Movie,Series,Audio,Video,MusicVideo"
        }
    }
}

struct MediaSource: Codable, Hashable, Sendable {
    let id: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
    }
}

struct MediaUserData: Codable, Hashable, Sendable {
    let playedPercentage: Double?
    let playbackPositionTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case playedPercentage = "PlayedPercentage"
        case playbackPositionTicks = "PlaybackPositionTicks"
    }
}

struct MediaItem: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let type: String
    let overview: String?
    let productionYear: Int?
    let runTimeTicks: Int64?
    let communityRating: Double?
    let imageTags: [String: String]?
    let userData: MediaUserData?
    let seriesName: String?
    let seriesID: String?
    let parentIndexNumber: Int?
    let indexNumber: Int?
    let mediaSources: [MediaSource]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case communityRating = "CommunityRating"
        case imageTags = "ImageTags"
        case userData = "UserData"
        case seriesName = "SeriesName"
        case seriesID = "SeriesId"
        case parentIndexNumber = "ParentIndexNumber"
        case indexNumber = "IndexNumber"
        case mediaSources = "MediaSources"
    }

    init(
        id: String,
        name: String,
        type: String,
        overview: String? = nil,
        productionYear: Int? = nil,
        runTimeTicks: Int64? = nil,
        communityRating: Double? = nil,
        imageTags: [String: String]? = nil,
        userData: MediaUserData? = nil,
        seriesName: String? = nil,
        seriesID: String? = nil,
        parentIndexNumber: Int? = nil,
        indexNumber: Int? = nil,
        mediaSources: [MediaSource]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.overview = overview
        self.productionYear = productionYear
        self.runTimeTicks = runTimeTicks
        self.communityRating = communityRating
        self.imageTags = imageTags
        self.userData = userData
        self.seriesName = seriesName
        self.seriesID = seriesID
        self.parentIndexNumber = parentIndexNumber
        self.indexNumber = indexNumber
        self.mediaSources = mediaSources
    }

    var isSeries: Bool { type.caseInsensitiveCompare("Series") == .orderedSame }
    var isEpisode: Bool { type.caseInsensitiveCompare("Episode") == .orderedSame }
    var isAudio: Bool { type.caseInsensitiveCompare("Audio") == .orderedSame }
    var isLiveChannel: Bool { type.caseInsensitiveCompare("TvChannel") == .orderedSame }
    var mediaKind: String {
        if isSeries { return "SERIES" }
        if isEpisode { return "EPISODE" }
        if isAudio { return "AUDIO" }
        if isLiveChannel { return "LIVE TV" }
        return "MOVIE"
    }
    var imageTag: String? { imageTags?["Primary"] }
    var resumeTicks: Int64 { userData?.playbackPositionTicks ?? 0 }
    var progress: Double { min(max((userData?.playedPercentage ?? 0) / 100, 0), 1) }

    var durationText: String? {
        guard let runTimeTicks, runTimeTicks > 0 else { return nil }
        let totalMinutes = Int(runTimeTicks / 10_000_000 / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)H \(minutes)M" : "\(minutes)M"
    }

    var episodeCode: String? {
        guard isEpisode else { return nil }
        let season = parentIndexNumber.map { String(format: "%02d", $0) } ?? "??"
        let episode = indexNumber.map { String(format: "%02d", $0) } ?? "??"
        return "S\(season)E\(episode)"
    }
}

extension MediaItem {
    static let sampleLibrary: [MediaItem] = [
        MediaItem(
            id: "demo-movie-1",
            name: "Moon Harbor",
            type: "Movie",
            overview: "A quiet signal keeper finds a map hidden inside a washed-up arcade cabinet.",
            productionYear: 1989,
            runTimeTicks: 65_400_000_000,
            communityRating: 8.4
        ),
        MediaItem(
            id: "demo-series-1",
            name: "Tiny Signals",
            type: "Series",
            overview: "Three friends tune an old pocket radio and hear tomorrow's messages.",
            productionYear: 1998,
            communityRating: 9.1
        ),
        MediaItem(
            id: "demo-movie-2",
            name: "Static Garden",
            type: "Movie",
            overview: "The last botanist in a sleeping city grows flowers from television snow.",
            productionYear: 1994,
            runTimeTicks: 58_800_000_000,
            communityRating: 7.9
        ),
        MediaItem(
            id: "demo-movie-3",
            name: "Night Bus 8",
            type: "Movie",
            overview: "One bus, eight stops, and a route that only appears after midnight.",
            productionYear: 1991,
            runTimeTicks: 61_200_000_000,
            communityRating: 8.0
        ),
        MediaItem(
            id: "demo-series-2",
            name: "Cloud Club",
            type: "Series",
            overview: "A rooftop weather club catalogs clouds that refuse to move.",
            productionYear: 1997,
            communityRating: 8.7
        ),
        MediaItem(
            id: "demo-movie-4",
            name: "Blue Comet",
            type: "Movie",
            overview: "A courier races the sunrise with a mysterious parcel in the basket.",
            productionYear: 1987,
            runTimeTicks: 54_600_000_000,
            communityRating: 8.2
        ),
        MediaItem(
            id: "demo-audio-1",
            name: "Pocket Radio",
            type: "Audio",
            overview: "A tiny late-night transmission for the long walk home.",
            productionYear: 1996,
            runTimeTicks: 2_280_000_000,
            communityRating: 8.6
        ),
    ]

    static let sampleEpisodes: [MediaItem] = [
        MediaItem(
            id: "demo-episode-1", name: "The First Frequency", type: "Episode", overview: "The radio wakes up.",
            runTimeTicks: 14_400_000_000, seriesName: "Tiny Signals", seriesID: "demo-series-1", parentIndexNumber: 1,
            indexNumber: 1),
        MediaItem(
            id: "demo-episode-2", name: "Message in Rain", type: "Episode",
            overview: "A forecast arrives one day early.", runTimeTicks: 15_000_000_000, seriesName: "Tiny Signals",
            seriesID: "demo-series-1", parentIndexNumber: 1, indexNumber: 2),
        MediaItem(
            id: "demo-episode-3", name: "The Long Tone", type: "Episode", overview: "A single note points beyond town.",
            runTimeTicks: 14_700_000_000, seriesName: "Tiny Signals", seriesID: "demo-series-1", parentIndexNumber: 1,
            indexNumber: 3),
        MediaItem(
            id: "demo-episode-4", name: "Cumulus No. 9", type: "Episode",
            overview: "A cloud follows the newest member home.", runTimeTicks: 13_800_000_000, seriesName: "Cloud Club",
            seriesID: "demo-series-2", parentIndexNumber: 1, indexNumber: 1),
        MediaItem(
            id: "demo-episode-5", name: "Forecast: Maybe", type: "Episode",
            overview: "The club tests a hand-built barometer.", runTimeTicks: 14_100_000_000, seriesName: "Cloud Club",
            seriesID: "demo-series-2", parentIndexNumber: 1, indexNumber: 2),
    ]

    static let sampleLiveTV: [MediaItem] = [
        MediaItem(
            id: "demo-live-1", name: "Channel 8", type: "TvChannel",
            overview: "Local weather, tiny news, and late-night movies."),
        MediaItem(
            id: "demo-live-2", name: "Moon TV", type: "TvChannel",
            overview: "A sample live channel with no tuner attached."),
    ]
}

extension MediaLibrary {
    static let sampleLibraries = [
        MediaLibrary(id: "demo-movies", name: "Movies", collectionType: "movies"),
        MediaLibrary(id: "demo-shows", name: "TV Shows", collectionType: "tvshows"),
        MediaLibrary(id: "demo-music", name: "Music", collectionType: "music"),
    ]

    var sampleItems: [MediaItem] {
        switch collectionType {
        case "movies": MediaItem.sampleLibrary.filter { !$0.isSeries && !$0.isAudio }
        case "tvshows": MediaItem.sampleLibrary.filter(\.isSeries)
        case "music": MediaItem.sampleLibrary.filter(\.isAudio)
        default: MediaItem.sampleLibrary
        }
    }
}

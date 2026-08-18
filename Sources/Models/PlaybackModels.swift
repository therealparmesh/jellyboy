import Foundation

enum PlaybackQuality: Int, Codable, Identifiable, Sendable {
    case maximum = 360_000_000
    case mbps120 = 120_000_000
    case mbps80 = 80_000_000
    case mbps60 = 60_000_000
    case mbps40 = 40_000_000
    case mbps20 = 20_000_000
    case mbps15 = 15_000_000
    case mbps10 = 10_000_000
    case mbps8 = 8_000_000
    case mbps6 = 6_000_000
    case mbps4 = 4_000_000
    case mbps3 = 3_000_000
    case mbps2 = 2_000_000
    case kbps1500 = 1_500_000
    case mbps1 = 1_000_000
    case kbps720 = 720_000
    case kbps420 = 420_000
    case kbps320 = 320_000
    case kbps256 = 256_000
    case kbps192 = 192_000
    case kbps128 = 128_000
    case kbps96 = 96_000
    case kbps64 = 64_000

    var id: Int { rawValue }
    var maximumBitrate: Int { rawValue }

    var title: String {
        if self == .maximum { return "MAXIMUM" }
        if rawValue >= 1_000_000 {
            let megabits = Double(rawValue) / 1_000_000
            return "\(megabits.formatted(.number.precision(.fractionLength(0 ... 1)))) MBPS"
        }
        return "\(rawValue / 1_000) KBPS"
    }

    static let videoOptions: [PlaybackQuality] = [
        .maximum,
        .mbps120,
        .mbps80,
        .mbps60,
        .mbps40,
        .mbps20,
        .mbps15,
        .mbps10,
        .mbps8,
        .mbps6,
        .mbps4,
        .mbps3,
        .kbps1500,
        .kbps720,
        .kbps420,
    ]

    static let audioOptions: [PlaybackQuality] = [
        .maximum,
        .mbps2,
        .kbps1500,
        .mbps1,
        .kbps320,
        .kbps256,
        .kbps192,
        .kbps128,
        .kbps96,
        .kbps64,
    ]

    static func options(
        for source: PlaybackMediaSource?,
        audioOnly: Bool? = nil
    ) -> [PlaybackQuality] {
        let candidates = (audioOnly ?? source?.isAudioOnly ?? false) ? audioOptions : videoOptions
        guard let bitrate = source?.bitrate else { return candidates }
        return candidates.filter { $0 == .maximum || $0.rawValue <= bitrate }
    }
}

enum PlaybackEngine: String, Codable, Sendable {
    case native = "AV"
    case vlc = "VLC"
}

enum PlaybackMethod: String, Codable, Sendable {
    case directPlay = "DIRECT"
    case directStream = "DIRECT STREAM"
    case transcode = "TRANSCODE"
    case offline = "OFFLINE"
}

struct PlaybackPlan: Sendable {
    let url: URL
    let source: PlaybackMediaSource
    let engine: PlaybackEngine
    let method: PlaybackMethod
    let quality: PlaybackQuality
}

struct PlaybackInfoResponse: Decodable, Sendable {
    let mediaSources: [PlaybackMediaSource]
    let playSessionID: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
        case playSessionID = "PlaySessionId"
    }
}

struct PlaybackMediaSource: Codable, Hashable, Sendable {
    let id: String?
    let name: String?
    let container: String?
    let bitrate: Int?
    let supportsDirectPlay: Bool
    let supportsDirectStream: Bool
    let supportsTranscoding: Bool
    let path: String?
    let transcodingURL: String?
    let requiredHTTPHeaders: [String: String]?
    let liveStreamID: String?
    let mediaStreams: [PlaybackMediaStream]

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case bitrate = "Bitrate"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case path = "Path"
        case transcodingURL = "TranscodingUrl"
        case requiredHTTPHeaders = "RequiredHttpHeaders"
        case liveStreamID = "LiveStreamId"
        case mediaStreams = "MediaStreams"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        container = try values.decodeIfPresent(String.self, forKey: .container)
        bitrate = try values.decodeIfPresent(Int.self, forKey: .bitrate)
        supportsDirectPlay = try values.decodeIfPresent(Bool.self, forKey: .supportsDirectPlay) ?? false
        supportsDirectStream = try values.decodeIfPresent(Bool.self, forKey: .supportsDirectStream) ?? false
        supportsTranscoding = try values.decodeIfPresent(Bool.self, forKey: .supportsTranscoding) ?? false
        path = try values.decodeIfPresent(String.self, forKey: .path)
        transcodingURL = try values.decodeIfPresent(String.self, forKey: .transcodingURL)
        requiredHTTPHeaders = try values.decodeIfPresent([String: String].self, forKey: .requiredHTTPHeaders)
        liveStreamID = try values.decodeIfPresent(String.self, forKey: .liveStreamID)
        mediaStreams = try values.decodeIfPresent([PlaybackMediaStream].self, forKey: .mediaStreams) ?? []
    }

    init(
        id: String?,
        name: String?,
        container: String?,
        bitrate: Int?,
        supportsDirectPlay: Bool,
        supportsDirectStream: Bool,
        supportsTranscoding: Bool,
        path: String?,
        transcodingURL: String?,
        requiredHTTPHeaders: [String: String]?,
        liveStreamID: String?,
        mediaStreams: [PlaybackMediaStream]
    ) {
        self.id = id
        self.name = name
        self.container = container
        self.bitrate = bitrate
        self.supportsDirectPlay = supportsDirectPlay
        self.supportsDirectStream = supportsDirectStream
        self.supportsTranscoding = supportsTranscoding
        self.path = path
        self.transcodingURL = transcodingURL
        self.requiredHTTPHeaders = requiredHTTPHeaders
        self.liveStreamID = liveStreamID
        self.mediaStreams = mediaStreams
    }

    var audioStreams: [PlaybackMediaStream] {
        mediaStreams.filter { $0.type.caseInsensitiveCompare("Audio") == .orderedSame }
    }

    var subtitleStreams: [PlaybackMediaStream] {
        mediaStreams.filter { $0.type.caseInsensitiveCompare("Subtitle") == .orderedSame }
    }

    var isAudioOnly: Bool {
        !audioStreams.isEmpty
            && !mediaStreams.contains { $0.type.caseInsensitiveCompare("Video") == .orderedSame }
    }

    var primaryContainer: String? {
        container?
            .split(separator: ",")
            .first
            .map { String($0).lowercased() }
    }

    var isNativeApplePlayback: Bool {
        let containers = Set((container ?? "").lowercased().split(separator: ",").map(String.init))
        let videoCodecs = Set(
            mediaStreams
                .filter { $0.type.caseInsensitiveCompare("Video") == .orderedSame }
                .compactMap { $0.codec?.lowercased() }
        )
        let audioCodecs = Set(audioStreams.compactMap { $0.codec?.lowercased() })
        let nativeAudioCodecs = Set(["aac", "ac3", "eac3", "mp3", "alac", "flac", "pcm_s16le", "pcm_s24le"])

        if videoCodecs.isEmpty {
            return !containers.isDisjoint(with: ["mp3", "aac", "m4a", "m4b", "mp4", "mov", "flac", "alac", "wav"])
                && audioCodecs.isSubset(of: nativeAudioCodecs)
        }

        return !containers.isDisjoint(with: ["mp4", "m4v", "mov"])
            && videoCodecs.isSubset(of: ["h264", "hevc", "h265"])
            && audioCodecs.isSubset(of: nativeAudioCodecs)
    }

    var sanitizedForOfflineStorage: PlaybackMediaSource {
        PlaybackMediaSource(
            id: id,
            name: name,
            container: container,
            bitrate: bitrate,
            supportsDirectPlay: supportsDirectPlay,
            supportsDirectStream: supportsDirectStream,
            supportsTranscoding: supportsTranscoding,
            path: nil,
            transcodingURL: nil,
            requiredHTTPHeaders: nil,
            liveStreamID: nil,
            mediaStreams: mediaStreams
        )
    }
}

struct PlaybackMediaStream: Codable, Hashable, Identifiable, Sendable {
    let index: Int
    let type: String
    let codec: String?
    let language: String?
    let title: String?
    let displayTitle: String?
    let isDefault: Bool
    let isForced: Bool
    let isExternal: Bool
    let deliveryURL: String?

    var id: String { "\(type)-\(index)" }

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case title = "Title"
        case displayTitle = "DisplayTitle"
        case isDefault = "IsDefault"
        case isForced = "IsForced"
        case isExternal = "IsExternal"
        case deliveryURL = "DeliveryUrl"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        type = try values.decodeIfPresent(String.self, forKey: .type) ?? "Unknown"
        codec = try values.decodeIfPresent(String.self, forKey: .codec)
        language = try values.decodeIfPresent(String.self, forKey: .language)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        displayTitle = try values.decodeIfPresent(String.self, forKey: .displayTitle)
        isDefault = try values.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        isForced = try values.decodeIfPresent(Bool.self, forKey: .isForced) ?? false
        isExternal = try values.decodeIfPresent(Bool.self, forKey: .isExternal) ?? false
        deliveryURL = try values.decodeIfPresent(String.self, forKey: .deliveryURL)
    }

    var menuTitle: String {
        if let displayTitle, !displayTitle.isEmpty { return displayTitle.uppercased() }
        if let title, !title.isEmpty { return title.uppercased() }
        if let language, !language.isEmpty { return language.uppercased() }
        if let codec, !codec.isEmpty { return "\(codec.uppercased()) \(index)" }
        return "TRACK \(index)"
    }

    var selectorTitle: String {
        var parts: [String] = []
        if let language, !language.isEmpty, language.caseInsensitiveCompare("und") != .orderedSame {
            parts.append(language.uppercased())
        }
        if let codec, !codec.isEmpty {
            let normalizedCodec = codec.uppercased()
            if !parts.contains(normalizedCodec) { parts.append(normalizedCodec) }
        }
        if isForced { parts.append("FORCED") }
        if !parts.isEmpty { return parts.joined(separator: " // ") }
        return String(menuTitle.prefix(24))
    }

    var requiresBurnInForOffline: Bool {
        guard type.caseInsensitiveCompare("Subtitle") == .orderedSame else { return false }
        let value = codec?.lowercased() ?? ""
        return ["pgs", "pgssub", "dvdsub", "vobsub", "dvbsub", "hdmv_pgs_subtitle"].contains(value)
    }
}

struct PlaybackInfoRequest: Encodable {
    let userID: String
    let startTimeTicks: Int64?
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
    let maxStreamingBitrate: Int?
    let deviceProfile: PlaybackDeviceProfile
    let enableDirectPlay: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "UserId"
        case startTimeTicks = "StartTimeTicks"
        case audioStreamIndex = "AudioStreamIndex"
        case subtitleStreamIndex = "SubtitleStreamIndex"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case deviceProfile = "DeviceProfile"
        case enableDirectPlay = "EnableDirectPlay"
        case enableDirectStream = "EnableDirectStream"
        case enableTranscoding = "EnableTranscoding"
        case allowVideoStreamCopy = "AllowVideoStreamCopy"
        case allowAudioStreamCopy = "AllowAudioStreamCopy"
        case autoOpenLiveStream = "AutoOpenLiveStream"
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(userID, forKey: .userID)
        try values.encodeIfPresent(startTimeTicks, forKey: .startTimeTicks)
        try values.encodeIfPresent(audioStreamIndex, forKey: .audioStreamIndex)
        try values.encodeIfPresent(subtitleStreamIndex, forKey: .subtitleStreamIndex)
        try values.encodeIfPresent(maxStreamingBitrate, forKey: .maxStreamingBitrate)
        try values.encode(deviceProfile, forKey: .deviceProfile)
        try values.encode(enableDirectPlay, forKey: .enableDirectPlay)
        try values.encode(true, forKey: .enableDirectStream)
        try values.encode(true, forKey: .enableTranscoding)
        try values.encode(true, forKey: .allowVideoStreamCopy)
        try values.encode(true, forKey: .allowAudioStreamCopy)
        try values.encode(true, forKey: .autoOpenLiveStream)
    }
}

struct PlaybackDeviceProfile: Encodable {
    let name: String
    let maxStreamingBitrate: Int?
    let directPlayProfiles: [DirectPlayProfile]
    let transcodingProfiles: [TranscodingProfile]
    let subtitleProfiles: [SubtitleProfile]
    let codecProfiles: [CodecProfile]

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case directPlayProfiles = "DirectPlayProfiles"
        case transcodingProfiles = "TranscodingProfiles"
        case subtitleProfiles = "SubtitleProfiles"
        case codecProfiles = "CodecProfiles"
    }

    static func jellyboy(maximumBitrate: Int?) -> PlaybackDeviceProfile {
        PlaybackDeviceProfile(
            name: "jellyboy",
            maxStreamingBitrate: maximumBitrate,
            directPlayProfiles: vlcDirectPlayProfiles,
            transcodingProfiles: [
                TranscodingProfile(
                    container: "mp4",
                    type: "Video",
                    videoCodec: "h264",
                    audioCodec: "aac",
                    protocolName: "hls",
                    context: "Streaming",
                    maxAudioChannels: "8",
                    minSegments: 2,
                    breakOnNonKeyFrames: true
                ),
                TranscodingProfile(
                    container: "mp3",
                    type: "Audio",
                    videoCodec: nil,
                    audioCodec: "mp3",
                    protocolName: "http",
                    context: "Streaming",
                    maxAudioChannels: "2",
                    minSegments: 1,
                    breakOnNonKeyFrames: false
                ),
            ],
            subtitleProfiles: streamingSubtitleProfiles,
            codecProfiles: vlcCodecProfiles
        )
    }

    static func offlineDownload(maximumBitrate: Int?) -> PlaybackDeviceProfile {
        PlaybackDeviceProfile(
            name: "jellyboy offline",
            maxStreamingBitrate: maximumBitrate,
            directPlayProfiles: vlcDirectPlayProfiles,
            transcodingProfiles: [
                TranscodingProfile(
                    container: "mp4",
                    type: "Video",
                    videoCodec: "h264",
                    audioCodec: "aac",
                    protocolName: "http",
                    context: "Streaming",
                    maxAudioChannels: "2",
                    minSegments: 1,
                    breakOnNonKeyFrames: false
                ),
                TranscodingProfile(
                    container: "mp3",
                    type: "Audio",
                    videoCodec: nil,
                    audioCodec: "mp3",
                    protocolName: "http",
                    context: "Streaming",
                    maxAudioChannels: "2",
                    minSegments: 1,
                    breakOnNonKeyFrames: false
                ),
            ],
            subtitleProfiles: [
                "srt", "subrip", "vtt", "webvtt", "ass", "ssa", "microdvd",
            ].map {
                SubtitleProfile(format: $0, method: "External")
            }
                + [
                    "pgs", "pgssub", "dvdsub", "vobsub", "dvbsub", "hdmv_pgs_subtitle",
                ].map {
                    SubtitleProfile(format: $0, method: "Encode")
                },
            codecProfiles: vlcCodecProfiles
        )
    }

    private static let vlcDirectPlayProfiles = [
        DirectPlayProfile(
            container: nil,
            audioCodec: "aac,ac3,alac,amr_nb,amr_wb,dts,eac3,flac,mp1,mp2,mp3,nellymoser,opus,"
                + "pcm_alaw,pcm_bluray,pcm_dvd,pcm_mulaw,pcm_s16be,pcm_s16le,pcm_s24be,pcm_s24le,"
                + "pcm_u8,speex,truehd,vorbis,wavpack,wmalossless,wmapro,wmav1,wmav2",
            videoCodec: "dirac,dv,ffv1,flv1,h261,h263,h264,hevc,mjpeg,mpeg1video,mpeg2video,mpeg4,"
                + "msmpeg4v1,msmpeg4v2,msmpeg4v3,prores,theora,vc1,vp8,vp9,wmv1,wmv2,wmv3",
            type: "Video"
        ),
        DirectPlayProfile(
            container: nil,
            audioCodec: "aac,ac3,alac,amr_nb,amr_wb,dts,eac3,flac,mp1,mp2,mp3,nellymoser,opus,"
                + "pcm_alaw,pcm_bluray,pcm_dvd,pcm_mulaw,pcm_s16be,pcm_s16le,pcm_s24be,pcm_s24le,"
                + "pcm_u8,speex,truehd,vorbis,wavpack,wmalossless,wmapro,wmav1,wmav2",
            videoCodec: nil,
            type: "Audio"
        ),
    ]

    private static let streamingSubtitleProfiles =
        [
            "ass", "dvbsub", "dvdsub", "mov_text", "pgssub", "ssa", "subrip", "text", "vtt", "xsub",
        ].map {
            SubtitleProfile(format: $0, method: "Embed")
        }
        + ["ass", "ssa", "subrip", "text", "vtt"].map {
            SubtitleProfile(format: $0, method: "External")
        }
        + ["dvbsub", "dvdsub", "pgssub", "xsub"].map {
            SubtitleProfile(format: $0, method: "Encode")
        }

    private static let vlcCodecProfiles = [
        CodecProfile(
            codec: "h264",
            type: "Video",
            conditions: [
                ProfileCondition(
                    condition: "NotEquals",
                    property: "IsAnamorphic",
                    value: "true",
                    isRequired: false
                ),
                ProfileCondition(
                    condition: "EqualsAny",
                    property: "VideoProfile",
                    value: "high|main|baseline|constrained baseline",
                    isRequired: false
                ),
                ProfileCondition(
                    condition: "LessThanEqual",
                    property: "VideoLevel",
                    value: "80",
                    isRequired: false
                ),
            ]
        ),
        CodecProfile(
            codec: "hevc",
            type: "Video",
            conditions: [
                ProfileCondition(
                    condition: "NotEquals",
                    property: "IsAnamorphic",
                    value: "true",
                    isRequired: false
                ),
                ProfileCondition(
                    condition: "EqualsAny",
                    property: "VideoProfile",
                    value: "main|main 10",
                    isRequired: false
                ),
                ProfileCondition(
                    condition: "NotEquals",
                    property: "IsInterlaced",
                    value: "true",
                    isRequired: false
                ),
            ]
        ),
    ]
}

struct CodecProfile: Encodable {
    let codec: String
    let type: String
    let conditions: [ProfileCondition]

    enum CodingKeys: String, CodingKey {
        case codec = "Codec"
        case type = "Type"
        case conditions = "Conditions"
    }
}

struct ProfileCondition: Encodable {
    let condition: String
    let property: String
    let value: String
    let isRequired: Bool

    enum CodingKeys: String, CodingKey {
        case condition = "Condition"
        case property = "Property"
        case value = "Value"
        case isRequired = "IsRequired"
    }
}

struct DirectPlayProfile: Encodable {
    let container: String?
    let audioCodec: String
    let videoCodec: String?
    let type: String

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case audioCodec = "AudioCodec"
        case videoCodec = "VideoCodec"
        case type = "Type"
    }
}

struct TranscodingProfile: Encodable {
    let container: String
    let type: String
    let videoCodec: String?
    let audioCodec: String
    let protocolName: String
    let context: String
    let maxAudioChannels: String
    let minSegments: Int
    let breakOnNonKeyFrames: Bool

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case type = "Type"
        case videoCodec = "VideoCodec"
        case audioCodec = "AudioCodec"
        case protocolName = "Protocol"
        case context = "Context"
        case maxAudioChannels = "MaxAudioChannels"
        case minSegments = "MinSegments"
        case breakOnNonKeyFrames = "BreakOnNonKeyFrames"
    }
}

struct SubtitleProfile: Encodable {
    let format: String
    let method: String

    enum CodingKeys: String, CodingKey {
        case format = "Format"
        case method = "Method"
    }
}

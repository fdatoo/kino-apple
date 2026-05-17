import Foundation
import KinoKitGenerated

/// Library catalog API wrapper.
public struct LibraryAPI: Sendable {
  private let transport: KinoTransport

  /// Creates a library API bound to a transport.
  public init(transport: KinoTransport) {
    self.transport = transport
  }

  /// Lists media items in the library, optionally filtered by media kind.
  ///
  /// - Parameters:
  ///   - kind: Server-side media kind filter (e.g. `"movie"`, `"tv_episode"`). Pass `nil` to return all kinds.
  ///   - limit: Maximum number of items to return.
  ///   - offset: Number of matching items to skip for pagination.
  ///   - q: Full-text search query across title and related fields.
  public func list(
    kind: String? = nil,
    limit: Int? = nil,
    offset: Int? = nil,
    q: String? = nil
  ) async throws -> [MediaItem] {
    let output = try await transport.makeClient().listCatalogItems(
      query: .init(
        kind: kind,
        q: q,
        limit: limit.map(Int32.init),
        offset: offset.map(Int64.init)
      )
    )

    switch output {
    case .ok(let response):
      return try response.body.json.items.compactMap(MediaItem.init(catalogItem:))
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }

  /// Fetches one media item by id.
  public func get(id: UUID) async throws -> MediaItem {
    let output = try await transport.makeClient().getCatalogItem(
      path: .init(id: id.uuidString)
    )

    switch output {
    case .ok(let response):
      guard let item = MediaItem(catalogItem: try response.body.json) else {
        throw KinoError.decoding(ClientDecodingError.emptyMediaItem)
      }
      return item
    case .badRequest:
      throw ErrorMapper.map(httpStatus: 400, body: nil)
    case .notFound:
      throw ErrorMapper.map(httpStatus: 404, body: nil)
    case .undocumented(let statusCode, _):
      throw ErrorMapper.map(httpStatus: statusCode, body: nil)
    }
  }
}

private enum ClientDecodingError: Error {
  case emptyMediaItem
}

extension MediaItem {
  fileprivate init?(catalogItem item: Components.Schemas.CatalogMediaItem) {
    guard let id = UUID(uuidString: item.id) else {
      return nil
    }

    let sourceFiles = item.variants.compactMap(SourceFile.init(streamVariant:))
    let transcodeOutputs = item.variants.compactMap(TranscodeOutput.init(streamVariant:))
    let subtitleTracks = item.subtitleTracks.compactMap { track in
      SubtitleTrack(catalogTrack: track, itemID: item.id)
    }

    self.init(
      id: id,
      title: item.title ?? item.id,
      runtimeSeconds: nil,
      sourceFiles: sourceFiles,
      transcodeOutputs: transcodeOutputs,
      subtitleTracks: subtitleTracks,
      resumeAt: nil
    )
  }
}

extension SourceFile {
  fileprivate init?(streamVariant variant: Components.Schemas.CatalogStreamVariant) {
    guard variant.kind == .source,
      let id = UUID(uuidString: variant.variantId),
      let codec = Codec(kinoValue: variant.capabilities.codec),
      let url = URL(string: variant.streamUrl)
    else {
      return nil
    }

    self.init(
      id: id,
      container: variant.capabilities.container,
      codec: codec,
      hdr: HDRFormat(kinoValue: variant.capabilities.hdr),
      height: variant.capabilities.height ?? 0,
      url: url
    )
  }
}

extension TranscodeOutput {
  fileprivate init?(streamVariant variant: Components.Schemas.CatalogStreamVariant) {
    guard variant.kind == .transcoded,
      let id = UUID(uuidString: variant.variantId),
      let codec = Codec(kinoValue: variant.capabilities.codec),
      let url = URL(string: variant.streamUrl)
    else {
      return nil
    }

    self.init(
      id: id,
      container: variant.capabilities.container,
      codec: codec,
      hdr: HDRFormat(kinoValue: variant.capabilities.hdr),
      height: variant.capabilities.height ?? 0,
      vmafTarget: nil,
      createdAt: Date(timeIntervalSince1970: 0),
      masterURL: url
    )
  }
}

extension SubtitleTrack {
  fileprivate init?(catalogTrack track: Components.Schemas.CatalogSubtitleTrack, itemID: String) {
    guard let id = UUID(uuidString: track.id),
      let url = URL(string: "/api/v1/stream/items/\(itemID)/subtitles/\(track.trackIndex).vtt")
    else {
      return nil
    }

    self.init(
      id: id,
      language: track.language,
      isForced: track.forced,
      url: url
    )
  }
}

extension Codec {
  fileprivate init?(kinoValue value: String) {
    switch value.lowercased() {
    case "h264", "avc", "avc1":
      self = .h264
    case "h265", "hevc":
      self = .hevc
    case "av1":
      self = .av1
    default:
      return nil
    }
  }
}

extension HDRFormat {
  fileprivate init?(kinoValue value: String?) {
    switch value?.lowercased() {
    case "hdr10":
      self = .hdr10
    case "dolbyvision", "dolby_vision", "dolby-vision", "dv":
      self = .dolbyVision
    case "hlg":
      self = .hlg
    default:
      return nil
    }
  }
}

extension Components.Schemas.VariantCapabilities {
  fileprivate var height: Int? {
    guard let resolution else {
      return nil
    }

    let digits = resolution.prefix { $0.isNumber }
    return Int(digits)
  }
}

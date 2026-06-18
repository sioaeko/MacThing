import Foundation

public struct VolumeProfile: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isLocal: Bool
    public let isInternal: Bool
    public let isRemovable: Bool
    public let capacity: Int64?
    public let availableCapacity: Int64?

    public init(
        id: String,
        name: String,
        path: String,
        isLocal: Bool,
        isInternal: Bool,
        isRemovable: Bool,
        capacity: Int64?,
        availableCapacity: Int64?
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isLocal = isLocal
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.capacity = capacity
        self.availableCapacity = availableCapacity
    }

    public var displayName: String {
        name.isEmpty ? path : name
    }

    public var locationDescription: String {
        if !isLocal {
            return "Network"
        }
        if isRemovable {
            return "Removable"
        }
        if isInternal {
            return "Internal"
        }
        return "External"
    }

    public var menuTitle: String {
        let details = [locationDescription, capacityDescription]
            .compactMap { $0 }
            .joined(separator: ", ")
        return "\(displayName) (\(details)) - \(path)"
    }

    public var requiresIndexConfirmation: Bool {
        !isLocal || !isInternal || isRemovable
    }

    public var indexConfirmationMessage: String {
        switch locationDescription {
        case "Network":
            return "\(displayName) is a network volume and is never indexed automatically. Choose it again to index."
        case "Removable":
            return "\(displayName) is a removable volume. Choose it again to index."
        case "External":
            return "\(displayName) is an external volume. Choose it again to index."
        default:
            return "\(displayName) needs confirmation. Choose it again to index."
        }
    }

    public var capacityDescription: String? {
        guard let capacity else {
            return nil
        }

        let capacityText = ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
        guard let availableCapacity else {
            return capacityText
        }

        let availableText = ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
        return "\(availableText) free of \(capacityText)"
    }
}

public enum VolumeProfileProvider {
    public static func mountedVolumes() -> [VolumeProfile] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsLocalKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let path = url.path
            return VolumeProfile(
                id: path,
                name: values?.volumeName ?? url.lastPathComponent,
                path: path,
                isLocal: values?.volumeIsLocal ?? true,
                isInternal: values?.volumeIsInternal ?? false,
                isRemovable: values?.volumeIsRemovable ?? false,
                capacity: values?.volumeTotalCapacity.map(Int64.init),
                availableCapacity: values?.volumeAvailableCapacity.map(Int64.init)
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}

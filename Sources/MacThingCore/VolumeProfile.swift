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

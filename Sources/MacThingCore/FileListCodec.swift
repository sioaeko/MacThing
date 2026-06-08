import Foundation

public enum FileListCodec {
    public static func parseEFU(_ text: String, indexedAt: Date = Date()) -> [FileEntry] {
        let rows = parseCSV(text)
        guard let header = rows.first else {
            return []
        }

        let headerMap = Dictionary(uniqueKeysWithValues: header.enumerated().map { index, name in
            (name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), index)
        })

        guard let filenameIndex = headerMap["filename"] ?? headerMap["path"] else {
            return []
        }

        return rows.dropFirst().compactMap { row in
            guard filenameIndex < row.count else {
                return nil
            }

            let path = row[filenameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                return nil
            }

            let attributes = value(in: row, key: "attributes", headerMap: headerMap) ?? ""
            let byteSize = value(in: row, key: "size", headerMap: headerMap).flatMap(Int64.init)
            let modifiedAt = dateValue(in: row, keys: ["date modified", "modified"], headerMap: headerMap)
            let createdAt = dateValue(in: row, keys: ["date created", "created"], headerMap: headerMap)
            var parsedAttributes = FileAttributes.parseEFUAttributes(attributes)

            let url = URL(fileURLWithPath: path)
            let kind = kind(from: parsedAttributes)
            if parsedAttributes.isEmpty {
                parsedAttributes = FileAttributes.inferred(
                    kind: kind,
                    name: url.lastPathComponent,
                    path: path
                )
            }

            return FileEntry(
                path: path,
                name: url.lastPathComponent,
                parent: url.deletingLastPathComponent().path,
                kind: kind,
                byteSize: byteSize,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                indexedAt: indexedAt,
                attributes: parsedAttributes
            )
        }
    }

    private static func kind(from attributes: FileAttributes) -> FileKind {
        if attributes.contains(.package) {
            return .package
        }
        if attributes.contains(.symlink) {
            return .symlink
        }
        if attributes.contains(.directory) {
            return .folder
        }
        return .file
    }

    private static func value(in row: [String], key: String, headerMap: [String: Int]) -> String? {
        guard let index = headerMap[key], index < row.count else {
            return nil
        }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func dateValue(in row: [String], keys: [String], headerMap: [String: Int]) -> Date? {
        for key in keys {
            guard let value = value(in: row, key: key, headerMap: headerMap) else {
                continue
            }

            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        consumeDelimiter(next, field: &field, row: &row, rows: &rows)
                    }
                } else {
                    inQuotes.toggle()
                }
                continue
            }

            if !inQuotes {
                consumeDelimiter(character, field: &field, row: &row, rows: &rows)
            } else {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private static func consumeDelimiter(
        _ character: Character,
        field: inout String,
        row: inout [String],
        rows: inout [[String]]
    ) {
        if character == "," {
            row.append(field)
            field = ""
        } else if character == "\n" {
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        } else if character == "\r" {
        } else {
            field.append(character)
        }
    }
}

import Foundation
import ImageIO

private func canonicalSearchFunctionName<S: StringProtocol>(_ value: S) -> String {
    value.lowercased().replacingOccurrences(of: "-", with: "")
}

private let quotedSemicolonPlaceholder = "\u{1F}"
private let quotedPipePlaceholder = "\u{1E}"
private let quotedCommaPlaceholder = "\u{1D}"

private func quotedListSeparatorPlaceholder(for character: Character) -> String? {
    switch character {
    case ";":
        return quotedSemicolonPlaceholder
    case "|":
        return quotedPipePlaceholder
    case ",":
        return quotedCommaPlaceholder
    default:
        return nil
    }
}

private func unescapeQuotedListSeparators(_ value: String) -> String {
    value
        .replacingOccurrences(of: quotedSemicolonPlaceholder, with: ";")
        .replacingOccurrences(of: quotedPipePlaceholder, with: "|")
        .replacingOccurrences(of: quotedCommaPlaceholder, with: ",")
}

private func appendSearchLiteral(_ literal: String, to value: inout String) {
    for character in literal {
        if let placeholder = quotedListSeparatorPlaceholder(for: character) {
            value.append(contentsOf: placeholder)
        } else {
            value.append(character)
        }
    }
}

private func searchLiteralMacro(at index: String.Index, in value: String) -> (literal: String, nextIndex: String.Index)? {
    let namedMacros: [(name: String, literal: String)] = [
        ("quot:", "\""),
        ("apos:", "'"),
        ("amp:", "&"),
        ("lt:", "<"),
        ("gt:", ">")
    ]

    for macro in namedMacros {
        if let range = value[index...].range(of: macro.name, options: [.caseInsensitive, .anchored]) {
            return (macro.literal, range.upperBound)
        }
    }

    guard value[index] == "#" else {
        return nil
    }

    var cursor = value.index(after: index)
    var radix = 10
    if cursor < value.endIndex, (value[cursor] == "x" || value[cursor] == "X") {
        radix = 16
        cursor = value.index(after: cursor)
    }

    let digitStart = cursor
    while cursor < value.endIndex, isMacroDigit(value[cursor], radix: radix) {
        cursor = value.index(after: cursor)
    }

    guard cursor > digitStart,
          cursor < value.endIndex,
          value[cursor] == ":" else {
        return nil
    }

    let digits = String(value[digitStart..<cursor])
    guard let scalarValue = UInt32(digits, radix: radix),
          let scalar = UnicodeScalar(scalarValue) else {
        return nil
    }

    return (String(Character(scalar)), value.index(after: cursor))
}

private func isMacroDigit(_ character: Character, radix: Int) -> Bool {
    guard character.unicodeScalars.count == 1,
          let scalar = character.unicodeScalars.first else {
        return false
    }

    if radix == 10 {
        return CharacterSet.decimalDigits.contains(scalar)
    }
    return CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains(scalar)
}

private func parseParentPlusDepthFunction(_ function: String) -> Int? {
    guard function.hasPrefix("parent+") else {
        return nil
    }
    let suffix = function.dropFirst("parent+".count)
    guard let depth = Int(suffix), (0...9).contains(depth) else {
        return nil
    }
    return depth
}

private func parseParentExactDepthFunction(_ function: String) -> Int? {
    guard function.hasPrefix("parentdepth") else {
        return nil
    }
    let suffix = function.dropFirst("parentdepth".count)
    guard let depth = Int(suffix), (1...9).contains(depth) else {
        return nil
    }
    return depth
}

private func supportsSemicolonSearchFunctionValueList(function: String) -> Bool {
    if parseParentPlusDepthFunction(function) != nil ||
        parseParentExactDepthFunction(function) != nil {
        return true
    }

    switch function {
    case "size", "sz", "dm", "datemodified", "datemodifieddate", "date",
         "dc", "datecreated", "datecreateddate", "da", "dateaccessed",
         "dateaccesseddate", "dr", "daterun", "rc", "recentchange",
         "runcount", "runs", "name", "filename", "basename", "namefrequency",
         "album", "artist", "comment", "genre", "title", "track", "year",
         "exists", "fileexists", "folderexists",
         "stem", "namepart",
         "fullpath", "pathandname", "pathname", "parsefullpath", "parsefilename",
         "parsepathandname", "parsepathname", "pathlist", "fullpathlist",
         "filelistfilename", "filelistname", "filelistpath", "frn",
         "parent", "infolder", "nosubfolders", "parentname", "parentpath",
         "parentfullpath",
         "ancestor", "ancestorname", "startwith", "startswith",
         "beginwith", "beginswith", "begin", "endwith", "endswith", "end",
         "depth", "parents", "parentcount", "chars", "len", "length",
         "namelen", "namelength", "basenamelen", "basenamelength",
         "filenamelen", "filenamelength", "fullpathlen", "fullpathlength",
         "pathandnamelen", "pathandnamelength", "pathnamelen", "pathnamelength",
         "stemlen", "stemlength", "namepartlen", "namepartlength",
         "utf8len", "basenameutf8bytelength", "nameleninutf8bytes",
         "namelengthinutf8bytes", "nameutf8bytelength",
         "filenameleninutf8bytes", "filenamelengthinutf8bytes",
         "fullpathutf8bytelength", "fullpathlengthinutf8bytes",
         "pathlen", "pathlength", "pathpartlen", "pathpartlength",
         "locationlen", "locationlength", "extlen", "extlength",
         "extensionlen", "extensionlength", "extensionfrequency",
         "pathpart", "pathparts",
         "pp", "location",
         "childcount", "children", "childfilecount", "childfiles",
         "childfoldercount", "childfolders", "totalchildsize", "child", "childname",
         "childfile", "childfilename", "childfilenames", "childfolder",
         "childfoldername", "childfoldernames", "childdir", "childdirname",
         "childdirs", "childdirnames", "childda", "childdateaccessed",
         "childfileda", "childfiledateaccessed", "childfolderda",
         "childfolderdateaccessed", "childdc", "childdatecreated",
         "childfiledc", "childfiledatecreated", "childfolderdc",
         "childfolderdatecreated", "childdm", "childdatemodified",
         "childfiledm", "childfiledatemodified", "childfolderdm",
         "childfolderdatemodified", "childrc", "childdaterecentlychanged",
         "childfilerc", "childfiledaterecentlychanged", "childfolderrc",
         "childfolderdaterecentlychanged", "childdaterun", "childfiledaterun",
         "childfolderdaterun", "childruncount", "childfileruncount",
         "childfolderruncount", "childsize", "childfilesize", "childfoldersize",
         "sibling", "siblingname",
         "siblingfile", "siblingfiles", "siblingfolder", "siblingfolders",
         "siblingdir", "siblingdirs",
         "siblingcount", "siblingfilecount", "siblingfoldercount",
         "descendant", "descendantname", "descendantfile", "descendantfilename",
         "descendantfilenames", "descendantfolder", "descendantfoldername",
         "descendantfoldernames", "descendantdir", "descendantdirname",
         "descendantdirs", "descendantdirnames", "descendantcount",
         "descendantfilecount", "descendantfoldercount",
         "ancestorattr", "ancestorattrib", "ancestorattribute", "ancestorattributes",
         "ancestorchild", "ancestorchildfile", "ancestorchildfolder",
         "parentchild", "parentchildname", "parentchildfile", "parentchildfilename",
         "parentchildfolder", "parentchildfoldername", "parentchilddir", "parentchilddirname",
         "parentdatecreated", "parentdc", "parentdatemodified", "parentdm",
         "parentsize",
         "parentsibling", "parentsiblingname", "parentsiblingfile",
         "parentsiblingfolder", "ancestorsibling", "ancestorsiblingname",
         "ancestorsiblingfile", "ancestorsiblingfolder", "width", "height",
         "bitdepth", "dimension", "dimensions", "orientation", "aspectratio",
         "type", "kind", "category":
        return true
    default:
        return false
    }
}

private func supportsFunctionValueSubexpression(function: String) -> Bool {
    switch function {
    case "ext", "extension",
         "name", "filename", "basename", "stem", "namepart",
         "path", "fullpath", "pathandname", "pathname",
         "parsefullpath", "parsefilename", "parsepathandname", "parsepathname",
         "pathpart", "pathparts", "pp", "location",
         "filelist", "pathlist", "fullpathlist",
         "exists", "fileexists", "folderexists",
         "parent", "infolder", "nosubfolders", "parentname", "parentpath", "parentfullpath",
         "ancestor", "ancestorname",
         "child", "childname", "childfile", "childfilename", "childfilenames",
         "childfolder", "childfoldername", "childfoldernames", "childdir", "childdirname",
         "childdirs", "childdirnames", "childfilelist",
         "descendant", "descendantname", "descendantfile", "descendantfilename",
         "descendantfilenames", "descendantfolder", "descendantfoldername",
         "descendantfoldernames", "descendantdir", "descendantdirname",
         "descendantdirs", "descendantdirnames",
         "sibling", "siblingname", "siblingfile", "siblingfiles",
         "siblingfolder", "siblingfolders", "siblingdir", "siblingdirs",
         "ancestorchild", "ancestorchildfile", "ancestorchildfolder",
         "parentchild", "parentchildname", "parentchildfile", "parentchildfilename",
         "parentchildfolder", "parentchildfoldername", "parentchilddir", "parentchilddirname",
         "parentsibling", "parentsiblingname", "parentsiblingfile", "parentsiblingfolder",
         "ancestorsibling", "ancestorsiblingname", "ancestorsiblingfile", "ancestorsiblingfolder",
         "startwith", "startswith", "beginwith", "beginswith", "begin",
         "endwith", "endswith", "end",
         "type", "kind", "category",
         "content", "ansicontent", "utf8content", "utf16content", "utf16becontent":
        return true
    default:
        return false
    }
}

public enum SearchSortField: String, Codable, CaseIterable, Sendable {
    case relevance
    case name
    case path
    case extensionName = "extension"
    case kind
    case size
    case dateModified
    case dateCreated
    case dateAccessed
    case dateIndexed
    case runCount
    case dateRun
    case attributes
    case title
    case artist
    case album
    case comment
    case genre
    case track
    case year

    public var displayName: String {
        switch self {
        case .relevance:
            return "Relevance"
        case .name:
            return "Name"
        case .path:
            return "Path"
        case .extensionName:
            return "Extension"
        case .kind:
            return "Kind"
        case .size:
            return "Size"
        case .dateModified:
            return "Modified"
        case .dateCreated:
            return "Created"
        case .dateAccessed:
            return "Accessed"
        case .dateIndexed:
            return "Indexed"
        case .runCount:
            return "Run Count"
        case .dateRun:
            return "Date Run"
        case .attributes:
            return "Attributes"
        case .title:
            return "Title"
        case .artist:
            return "Artist"
        case .album:
            return "Album"
        case .comment:
            return "Comment"
        case .genre:
            return "Genre"
        case .track:
            return "Track"
        case .year:
            return "Year"
        }
    }

    public static func parse(_ value: String) -> SearchSortField? {
        let normalized = canonicalSearchFunctionName(value)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "relevance", "rank":
            return .relevance
        case "name", "filename", "file":
            return .name
        case "path", "fullpath":
            return .path
        case "ext", "extension", "extensionname":
            return .extensionName
        case "kind", "type", "category":
            return .kind
        case "size", "sz", "bytes":
            return .size
        case "dm", "datemodified", "datemodifieddate", "date", "modified", "modifieddate":
            return .dateModified
        case "dc", "datecreated", "datecreateddate", "created", "createddate":
            return .dateCreated
        case "da", "dateaccessed", "dateaccesseddate", "accessed", "accesseddate":
            return .dateAccessed
        case "dateindexed", "indexed", "indexeddate":
            return .dateIndexed
        case "runcount", "runs":
            return .runCount
        case "dr", "daterun", "lastrun", "lastrunat":
            return .dateRun
        case "attrib", "attr", "attribute", "attributes":
            return .attributes
        case "title", "mediatitle":
            return .title
        case "artist", "mediaartist":
            return .artist
        case "album", "mediaalbum":
            return .album
        case "comment", "mediacomment":
            return .comment
        case "genre", "mediagenre":
            return .genre
        case "track", "tracknumber", "mediatrack":
            return .track
        case "year", "recordingyear", "mediayear":
            return .year
        default:
            return SearchSortField.allCases.first { field in
                canonicalSearchFunctionName(field.rawValue)
                    .replacingOccurrences(of: "_", with: "") == normalized ||
                    canonicalSearchFunctionName(field.displayName)
                    .replacingOccurrences(of: " ", with: "") == normalized
            }
        }
    }
}

public enum SearchSortDirection: String, Codable, CaseIterable, Sendable {
    case ascending
    case descending

    public var displayName: String {
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }

    public var toggled: SearchSortDirection {
        self == .ascending ? .descending : .ascending
    }
}

public struct SearchOptions: Codable, Hashable, Sendable {
    public var matchPath: Bool
    public var fuzzyMatching: Bool
    public var caseSensitive: Bool
    public var regexMatching: Bool
    public var wholeWordMatching: Bool
    public var diacriticSensitive: Bool

    public init(
        matchPath: Bool = true,
        fuzzyMatching: Bool = true,
        caseSensitive: Bool = false,
        regexMatching: Bool = false,
        wholeWordMatching: Bool = false,
        diacriticSensitive: Bool = false
    ) {
        self.matchPath = matchPath
        self.fuzzyMatching = fuzzyMatching
        self.caseSensitive = caseSensitive
        self.regexMatching = regexMatching
        self.wholeWordMatching = wholeWordMatching
        self.diacriticSensitive = diacriticSensitive
    }

    private enum CodingKeys: String, CodingKey {
        case matchPath
        case fuzzyMatching
        case caseSensitive
        case regexMatching
        case wholeWordMatching
        case diacriticSensitive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            matchPath: try container.decodeIfPresent(Bool.self, forKey: .matchPath) ?? true,
            fuzzyMatching: try container.decodeIfPresent(Bool.self, forKey: .fuzzyMatching) ?? true,
            caseSensitive: try container.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? false,
            regexMatching: try container.decodeIfPresent(Bool.self, forKey: .regexMatching) ?? false,
            wholeWordMatching: try container.decodeIfPresent(Bool.self, forKey: .wholeWordMatching) ?? false,
            diacriticSensitive: try container.decodeIfPresent(Bool.self, forKey: .diacriticSensitive) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchPath, forKey: .matchPath)
        try container.encode(fuzzyMatching, forKey: .fuzzyMatching)
        try container.encode(caseSensitive, forKey: .caseSensitive)
        try container.encode(regexMatching, forKey: .regexMatching)
        try container.encode(wholeWordMatching, forKey: .wholeWordMatching)
        try container.encode(diacriticSensitive, forKey: .diacriticSensitive)
    }
}

public struct SearchRequest: Sendable {
    public var query: String
    public var limit: Int
    public var offset: Int
    public var sortField: SearchSortField
    public var sortDirection: SearchSortDirection
    public var options: SearchOptions

    public init(
        query: String,
        limit: Int = 500,
        offset: Int = 0,
        sortField: SearchSortField = .relevance,
        sortDirection: SearchSortDirection = .ascending,
        options: SearchOptions = SearchOptions()
    ) {
        self.query = query
        self.limit = max(1, limit)
        self.offset = max(0, offset)
        self.sortField = sortField
        self.sortDirection = sortDirection
        self.options = options
    }
}

public struct SearchResponse: Sendable {
    public let entries: [FileEntry]
    public let totalMatches: Int
    public let warnings: [String]

    public init(entries: [FileEntry], totalMatches: Int, warnings: [String] = []) {
        self.entries = entries
        self.totalMatches = totalMatches
        self.warnings = warnings
    }
}

public enum SearchCandidateComparisonOperator: String, Sendable {
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
}

public enum SearchCandidateNumericField: String, Sendable {
    case byteSize
    case runCount
}

public enum SearchCandidateDateField: String, Sendable {
    case dateModified
    case dateCreated
    case dateAccessed
    case dateIndexed
    case dateRun
}

public struct SearchCandidateNumericFilter: Sendable {
    public let field: SearchCandidateNumericField
    public let op: SearchCandidateComparisonOperator
    public let value: Int64

    public init(field: SearchCandidateNumericField, op: SearchCandidateComparisonOperator, value: Int64) {
        self.field = field
        self.op = op
        self.value = value
    }
}

public struct SearchCandidateDateFilter: Sendable {
    public let field: SearchCandidateDateField
    public let op: SearchCandidateComparisonOperator
    public let value: Date

    public init(field: SearchCandidateDateField, op: SearchCandidateComparisonOperator, value: Date) {
        self.field = field
        self.op = op
        self.value = value
    }
}

public struct SearchCandidateHint: Sendable {
    public let terms: [String]
    public let canUseDatabaseCandidates: Bool
    public let extensions: Set<String>
    public let kinds: Set<FileKind>
    public let requiredAttributes: FileAttributes
    public let excludedAttributes: FileAttributes
    public let numericFilters: [SearchCandidateNumericFilter]
    public let dateFilters: [SearchCandidateDateFilter]
    public let parentPaths: Set<String>

    public init(
        terms: [String],
        canUseDatabaseCandidates: Bool,
        extensions: Set<String> = [],
        kinds: Set<FileKind> = [],
        requiredAttributes: FileAttributes = [],
        excludedAttributes: FileAttributes = [],
        numericFilters: [SearchCandidateNumericFilter] = [],
        dateFilters: [SearchCandidateDateFilter] = [],
        parentPaths: Set<String> = []
    ) {
        self.terms = terms
        self.canUseDatabaseCandidates = canUseDatabaseCandidates
        self.extensions = extensions
        self.kinds = kinds
        self.requiredAttributes = requiredAttributes
        self.excludedAttributes = excludedAttributes
        self.numericFilters = numericFilters
        self.dateFilters = dateFilters
        self.parentPaths = parentPaths
    }

    public var hasStructuredFilters: Bool {
        !extensions.isEmpty ||
            !kinds.isEmpty ||
            !requiredAttributes.isEmpty ||
            !excludedAttributes.isEmpty ||
            !numericFilters.isEmpty ||
            !dateFilters.isEmpty ||
            !parentPaths.isEmpty
    }
}

public enum SearchEngine {
    public static func search(query: String, in entries: [FileEntry], limit: Int = 500) -> [FileEntry] {
        let request = SearchRequest(query: query, limit: limit)
        return search(request: request, in: entries).entries
    }

    public static func search(request: SearchRequest, in entries: [FileEntry]) -> SearchResponse {
        let parsed = SearchQueryParser.parse(request.query)
        let effectiveRequest = applyingQueryOverrides(request, parsed)
        let context = SearchContext(entries: entries, options: request.options)

        guard !parsed.isEmpty else {
            let sorted = sort(
                matches: entries.map { SearchMatch(score: 0, entry: $0) },
                field: effectiveRequest.sortField == .relevance ? .dateModified : effectiveRequest.sortField,
                direction: effectiveRequest.sortField == .relevance ? .descending : effectiveRequest.sortDirection
            )
            return SearchResponse(
                entries: windowedEntries(from: sorted, request: effectiveRequest),
                totalMatches: sorted.count,
                warnings: parsed.warnings
            )
        }

        var matches: [SearchMatch] = []
        matches.reserveCapacity(min(
            entries.count,
            max(effectiveRequest.limit + effectiveRequest.offset, effectiveRequest.limit) * 4
        ))

        for entry in entries {
            if let score = parsed.score(entry: entry, options: request.options, context: context) {
                matches.append(SearchMatch(score: score, entry: entry))
            }
        }

        let sorted = sort(
            matches: matches,
            field: effectiveRequest.sortField,
            direction: effectiveRequest.sortDirection
        )
        return SearchResponse(
            entries: windowedEntries(from: sorted, request: effectiveRequest),
            totalMatches: sorted.count,
            warnings: parsed.warnings
        )
    }

    private static func applyingQueryOverrides(_ request: SearchRequest, _ parsed: ParsedSearch) -> SearchRequest {
        guard parsed.limitOverride != nil ||
            parsed.offsetOverride != nil ||
            parsed.sortFieldOverride != nil ||
            parsed.sortDirectionOverride != nil else {
            return request
        }
        return SearchRequest(
            query: request.query,
            limit: parsed.limitOverride ?? request.limit,
            offset: parsed.offsetOverride ?? request.offset,
            sortField: parsed.sortFieldOverride ?? request.sortField,
            sortDirection: parsed.sortDirectionOverride ?? request.sortDirection,
            options: request.options
        )
    }

    private static func windowedEntries(from sorted: [SearchMatch], request: SearchRequest) -> [FileEntry] {
        guard request.offset < sorted.count else {
            return []
        }
        return Array(sorted.dropFirst(request.offset).prefix(request.limit).map(\.entry))
    }

    public static func candidateHint(for request: SearchRequest) -> SearchCandidateHint {
        if request.options.regexMatching {
            return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
        }
        if request.query.contains("(") || request.query.contains(")") || containsAngleGrouping(in: request.query) {
            return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
        }
        if request.query.contains("$") {
            return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
        }

        let tokens = tokenizeCandidateTerms(request.query)
        var terms: [String] = []
        var extensions = Set<String>()
        var kinds = Set<FileKind>()
        var requiredAttributes: FileAttributes = []
        var excludedAttributes: FileAttributes = []
        var numericFilters: [SearchCandidateNumericFilter] = []
        var dateFilters: [SearchCandidateDateFilter] = []
        var parentPaths = Set<String>()

        func addTerm(_ value: String) {
            let restoredValue = unescapeQuotedListSeparators(value)
            if restoredValue.count >= 3 {
                terms.append(restoredValue)
            }
        }

        func isCountDirective(_ rawToken: String) -> Bool {
            guard let colonIndex = rawToken.firstIndex(of: ":") else {
                return false
            }
            return canonicalSearchFunctionName(rawToken[..<colonIndex]) == "count"
        }

        func isOffsetDirective(_ rawToken: String) -> Bool {
            guard let colonIndex = rawToken.firstIndex(of: ":") else {
                return false
            }
            switch canonicalSearchFunctionName(rawToken[..<colonIndex]) {
            case "offset", "skip", "first":
                return true
            default:
                return false
            }
        }

        func isSortDirective(_ rawToken: String) -> Bool {
            guard let colonIndex = rawToken.firstIndex(of: ":") else {
                return false
            }
            switch canonicalSearchFunctionName(rawToken[..<colonIndex]) {
            case "sort", "ascending", "asc", "descending", "desc":
                return true
            default:
                return false
            }
        }

        func applySimpleModifier(_ rawToken: String) -> Bool? {
            guard let colonIndex = rawToken.firstIndex(of: ":") else {
                return nil
            }

            let function = canonicalSearchFunctionName(rawToken[..<colonIndex])
            let rawValue = String(rawToken[rawToken.index(after: colonIndex)...])
            let value = unescapeQuotedListSeparators(rawValue)

            switch function {
            case "ascii", "utf8", "noascii",
                 "case", "nocase",
                 "diacritics", "nodiacritics",
                 "path", "nopath",
                 "wholeword", "ww", "nowholeword", "noww",
                 "wfn", "wholefilename", "exact", "nowfn", "nowholefilename",
                 "noregex", "nofileonly", "nofolderonly":
                guard !value.isEmpty else {
                    return true
                }
                guard !value.contains(":"), !value.contains("*"), !value.contains("?") else {
                    return false
                }
                addTerm(value)
                return true
            case "file", "files":
                kinds.formUnion([.file, .symlink, .package])
                guard !value.isEmpty else {
                    return true
                }
                guard !value.contains(":"), !value.contains("*"), !value.contains("?") else {
                    return false
                }
                addTerm(value)
                return true
            case "folder", "folders", "dir", "dirs":
                kinds.insert(.folder)
                guard !value.isEmpty else {
                    return true
                }
                guard !value.contains(":"), !value.contains("*"), !value.contains("?") else {
                    return false
                }
                addTerm(value)
                return true
            case "regex", "wildcards":
                return value.isEmpty ? true : false
            case "nowildcards":
                guard !value.isEmpty else {
                    return true
                }
                guard !value.contains(":") else {
                    return false
                }
                addTerm(value)
                return true
            default:
                return nil
            }
        }

        for rawToken in tokens {
            if rawToken == "|" || rawToken.localizedCaseInsensitiveCompare("OR") == .orderedSame {
                return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
            }

            if rawToken.localizedCaseInsensitiveCompare("AND") == .orderedSame {
                continue
            }

            if isCountDirective(rawToken) {
                continue
            }

            if isOffsetDirective(rawToken) {
                continue
            }

            if isSortDirective(rawToken) {
                continue
            }

            var token = rawToken
            var isNegated = false
            while token.hasPrefix("!") || token.hasPrefix("-") {
                isNegated.toggle()
                token.removeFirst()
            }

            if isNegated || token.isEmpty {
                continue
            }

            if let modifierHandled = applySimpleModifier(token) {
                if modifierHandled {
                    continue
                }
                return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
            }

            if token.contains("*") || token.contains("?") {
                return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
            }

            let canonicalToken = canonicalSearchFunctionName(token)
            if canonicalToken == "file:" || canonicalToken == "files:" {
                kinds.formUnion([.file, .symlink, .package])
                continue
            }

            if canonicalToken == "folder:" ||
                canonicalToken == "folders:" ||
                canonicalToken == "dir:" ||
                canonicalToken == "dirs:" {
                kinds.insert(.folder)
                continue
            }

            if let colonIndex = token.firstIndex(of: ":") {
                let function = canonicalSearchFunctionName(token[..<colonIndex])
                let rawValue = String(token[token.index(after: colonIndex)...])
                if rawValue.contains(";"), supportsSemicolonSearchFunctionValueList(function: function) {
                    return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                }
                let value = unescapeQuotedListSeparators(rawValue)

                if parseParentPlusDepthFunction(function) != nil ||
                    parseParentExactDepthFunction(function) != nil {
                    return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                }

                switch function {
                case "everything", "nop":
                    continue
                case "name", "filename", "basename", "path", "fullpath", "pathandname",
                     "pathname", "parsefullpath", "parsefilename", "parsepathandname",
                     "parsepathname", "pathpart", "pathparts", "pp", "location",
                     "stem", "namepart":
                    if value.count >= 3 {
                        terms.append(value)
                    }
                case "parent", "infolder", "nosubfolders", "parentpath", "parentfullpath":
                    let normalizedParent = normalizedFolderPath(value)
                    if isAbsoluteSearchPath(normalizedParent) {
                        parentPaths.insert(normalizedParent)
                    } else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                case "ext", "extension":
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        extensions.insert("")
                        kinds.formUnion([.file, .symlink, .other])
                    } else {
                        extensions.formUnion(parseExtensionList(rawValue))
                    }
                case "size", "sz":
                    if let filters = sizeCandidateFilters(for: value) {
                        numericFilters.append(contentsOf: filters)
                        break
                    }
                    guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: parseByteSize) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    numericFilters.append(contentsOf: filter.candidateFilters(field: .byteSize))
                case "dm", "datemodified", "datemodifieddate", "date":
                    guard let filter = DateFilter.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    dateFilters.append(contentsOf: filter.candidateFilters(field: .dateModified))
                case "dc", "datecreated", "datecreateddate":
                    guard let filter = DateFilter.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    dateFilters.append(contentsOf: filter.candidateFilters(field: .dateCreated))
                case "da", "dateaccessed", "dateaccesseddate":
                    guard let filter = DateFilter.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    dateFilters.append(contentsOf: filter.candidateFilters(field: .dateAccessed))
                case "dr", "daterun":
                    guard let filter = DateFilter.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    dateFilters.append(contentsOf: filter.candidateFilters(field: .dateRun))
                case "rc", "recentchange":
                    guard let filter = DateFilter.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    dateFilters.append(contentsOf: filter.candidateFilters(field: .dateIndexed))
                case "runcount", "runs":
                    guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: { Int64($0) }) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    numericFilters.append(contentsOf: filter.candidateFilters(field: .runCount))
                case "startwith", "startswith", "beginwith", "beginswith", "begin":
                    if value.count >= 3 {
                        terms.append(value)
                    }
                case "endwith", "endswith", "end":
                    if value.count >= 3 {
                        terms.append(value)
                    }
                case "type", "kind", "category":
                    guard let category = FileCategory.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(category.candidateExtensions)
                    kinds.formUnion(category.candidateKinds)
                case "image", "images", "pic", "pics", "picture", "pictures", "photo", "photos":
                    guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(FileCategory.image.candidateExtensions)
                    kinds.formUnion(FileCategory.image.candidateKinds)
                case "audio", "audios", "music":
                    guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(FileCategory.audio.candidateExtensions)
                    kinds.formUnion(FileCategory.audio.candidateKinds)
                case "video", "videos", "movie", "movies":
                    guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(FileCategory.video.candidateExtensions)
                    kinds.formUnion(FileCategory.video.candidateKinds)
                case "doc", "docs", "document", "documents":
                    guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(FileCategory.document.candidateExtensions)
                    kinds.formUnion(FileCategory.document.candidateKinds)
                case "zip", "zips", "compressed", "compress", "archive", "archives":
                    guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(FileCategory.compressed.candidateExtensions)
                    kinds.formUnion(FileCategory.compressed.candidateKinds)
                case "exe", "exec", "executable", "executables", "app", "apps", "application", "applications":
                    guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    extensions.formUnion(FileCategory.executable.candidateExtensions)
                    kinds.formUnion(FileCategory.executable.candidateKinds)
                case "attrib", "attr", "attribute", "attributes":
                    guard let filter = AttributeFilter.parse(value) else {
                        return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                    }
                    requiredAttributes.formUnion(filter.required)
                    excludedAttributes.formUnion(filter.excluded)
                case "hidden":
                    addAttributeHint(
                        value: value,
                        attribute: .hidden,
                        required: &requiredAttributes,
                        excluded: &excludedAttributes
                    )
                case "readonly", "read-only":
                    addAttributeHint(
                        value: value,
                        attribute: .readonly,
                        required: &requiredAttributes,
                        excluded: &excludedAttributes
                    )
                case "system":
                    addAttributeHint(
                        value: value,
                        attribute: .system,
                        required: &requiredAttributes,
                        excluded: &excludedAttributes
                    )
                case "symlink", "link":
                    addAttributeHint(
                        value: value,
                        attribute: .symlink,
                        required: &requiredAttributes,
                        excluded: &excludedAttributes
                    )
                case "package":
                    addAttributeHint(
                        value: value,
                        attribute: .package,
                        required: &requiredAttributes,
                        excluded: &excludedAttributes
                    )
                case "content", "ansicontent", "utf8content", "utf16content", "utf16becontent",
                     "regex", "dupe", "dupename", "empty", "nothing",
                     "exists", "fileexists", "folderexists",
                     "child", "childname", "childcount", "children",
                     "childfilecount", "childfiles", "childfoldercount",
                     "childfolders", "childfile", "childfilename", "childfilenames",
                     "childfolder", "childfoldername", "childfoldernames",
                     "childdir", "childdirname", "childdirs", "childdirnames",
                     "childattr", "childattrib", "childattribute", "childattributes",
                     "childfileattr", "childfileattrib", "childfileattribute",
                     "childfileattributes", "childfolderattr", "childfolderattrib",
                     "childfolderattribute", "childfolderattributes",
                     "childda", "childdateaccessed", "childfileda",
                     "childfiledateaccessed", "childfolderda",
                     "childfolderdateaccessed", "childdc", "childdatecreated",
                     "childfiledc", "childfiledatecreated", "childfolderdc",
                     "childfolderdatecreated", "childdm", "childdatemodified",
                     "childfiledm", "childfiledatemodified", "childfolderdm",
                     "childfolderdatemodified", "childrc", "childdaterecentlychanged",
                     "childfilerc", "childfiledaterecentlychanged", "childfolderrc",
                     "childfolderdaterecentlychanged", "childdaterun",
                     "childfiledaterun", "childfolderdaterun", "childruncount",
                     "childfileruncount", "childfolderruncount", "childsize",
                     "childfilesize", "childfoldersize", "childfilelist",
                     "sibling", "siblingname", "siblingfile",
                     "siblingfiles", "siblingfolder", "siblingfolders",
                     "siblingdir", "siblingdirs", "chars", "stemlen", "stemlength",
                     "namefrequency", "namepartlen", "namepartlength", "basenamelen",
                     "basenamelength", "filenamelen", "filenamelength",
                     "fullpathlen", "fullpathlength", "pathandnamelen",
                     "pathandnamelength", "pathnamelen", "pathnamelength", "utf8len",
                     "basenameutf8bytelength", "nameleninutf8bytes",
                     "namelengthinutf8bytes", "nameutf8bytelength",
                     "filenameleninutf8bytes", "filenamelengthinutf8bytes",
                     "fullpathutf8bytelength", "fullpathlengthinutf8bytes",
                     "pathlen", "pathlength",
                     "pathpartlen", "pathpartlength", "locationlen",
                     "locationlength", "extlen", "extlength", "extensionlen", "extensionlength",
                     "extensionfrequency", "pathdupe",
                     "totalchildsize", "siblingcount",
                     "siblingfilecount", "siblingfoldercount",
                     "descendant", "descendantname", "descendantfile",
                     "descendantfilename", "descendantfilenames", "descendantfolder",
                     "descendantfoldername", "descendantfoldernames",
                     "descendantdir", "descendantdirname", "descendantdirs",
                     "descendantdirnames", "descendantcount", "descendantfilecount",
                     "descendantfoldercount", "ancestorattr", "ancestorattrib",
                     "ancestorattribute", "ancestorattributes",
                     "ancestorchild", "ancestorchildfile", "ancestorchildfolder",
                     "pathlist", "fullpathlist",
                     "parentname", "ancestorname",
                     "parentchild", "parentchildname", "parentchildfile",
                     "parentchildfilename", "parentchildfolder", "parentchildfoldername",
                     "parentchilddir", "parentchilddirname",
                     "parentdatecreated", "parentdc", "parentdatemodified",
                     "parentdm", "parentsize",
                     "parentsibling", "parentsiblingfile", "parentsiblingfolder",
                     "ancestorsibling", "ancestorsiblingfile", "ancestorsiblingfolder",
                     "namepartdupe", "sizedupe",
                     "attribdupe", "attrdupe", "dadupe", "dcdupe",
                     "dmdupe", "filelist", "filelistfilename", "filelistname", "filelistpath", "frn", "fsi",
                     "album", "artist", "comment", "genre", "title", "track", "year",
                     "root", "width", "height", "bitdepth",
                     "dimension", "dimensions", "orientation", "aspect-ratio",
                     "aspectratio", "ancestor", "parents", "parentcount", "depth",
                     "shell":
                    return SearchCandidateHint(terms: [], canUseDatabaseCandidates: false)
                default:
                    continue
                }
            } else if token.count >= 3 {
                terms.append(token)
            }
        }

        let uniqueTerms = Array(NSOrderedSet(array: terms).compactMap { $0 as? String })
        let hasStructuredFilters = !extensions.isEmpty ||
            !kinds.isEmpty ||
            !requiredAttributes.isEmpty ||
            !excludedAttributes.isEmpty ||
            !numericFilters.isEmpty ||
            !dateFilters.isEmpty ||
            !parentPaths.isEmpty
        return SearchCandidateHint(
            terms: uniqueTerms,
            canUseDatabaseCandidates: !uniqueTerms.isEmpty || hasStructuredFilters,
            extensions: extensions,
            kinds: kinds,
            requiredAttributes: requiredAttributes,
            excludedAttributes: excludedAttributes,
            numericFilters: numericFilters,
            dateFilters: dateFilters,
            parentPaths: parentPaths
        )
    }

    static func parseExtensionList(_ value: String) -> Set<String> {
        Set(
            value
                .split(whereSeparator: { ";,|".contains($0) })
                .map {
                    unescapeQuotedListSeparators(
                        String($0).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    ).lowercased()
                }
                .filter { !$0.isEmpty }
        )
    }

    static func parseDelimitedList(_ value: String) -> Set<String> {
        Set(
            value
                .split(whereSeparator: { ";,|".contains($0) })
                .map {
                    unescapeQuotedListSeparators(
                        String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.isEmpty }
        )
    }

    static func parseByteSize(_ value: String) -> Int64? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return nil
        }

        let numberPart = String(trimmed.prefix { $0.isNumber || $0 == "." })
        let unitPart = trimmed.dropFirst(numberPart.count)
        guard let number = Double(numberPart) else {
            return nil
        }

        let multiplier: Double
        switch unitPart {
        case "", "b", "byte", "bytes":
            multiplier = 1
        case "k", "kb", "kib":
            multiplier = 1_024
        case "m", "mb", "mib":
            multiplier = 1_024 * 1_024
        case "g", "gb", "gib":
            multiplier = 1_024 * 1_024 * 1_024
        case "t", "tb", "tib":
            multiplier = 1_024 * 1_024 * 1_024 * 1_024
        default:
            return nil
        }

        return Int64(number * multiplier)
    }

    fileprivate static func parseSizePredicate(_ value: String) -> SearchPredicate? {
        let normalized = canonicalSearchFunctionName(value.trimmingCharacters(in: .whitespacesAndNewlines))
        switch normalized {
        case "empty":
            return .size(.comparison(.equal, 0))
        case "tiny":
            return .and([
                .size(.comparison(.greaterThan, 0)),
                .size(.comparison(.lessThanOrEqual, 10 * 1_024))
            ])
        case "small":
            return .and([
                .size(.comparison(.greaterThan, 10 * 1_024)),
                .size(.comparison(.lessThanOrEqual, 100 * 1_024))
            ])
        case "medium":
            return .and([
                .size(.comparison(.greaterThan, 100 * 1_024)),
                .size(.comparison(.lessThanOrEqual, 1_024 * 1_024))
            ])
        case "large":
            return .and([
                .size(.comparison(.greaterThan, 1_024 * 1_024)),
                .size(.comparison(.lessThanOrEqual, 16 * 1_024 * 1_024))
            ])
        case "huge":
            return .and([
                .size(.comparison(.greaterThan, 16 * 1_024 * 1_024)),
                .size(.comparison(.lessThanOrEqual, 128 * 1_024 * 1_024))
            ])
        case "gigantic":
            return .size(.comparison(.greaterThan, 128 * 1_024 * 1_024))
        case "unknown":
            return .sizeUnknown
        default:
            return nil
        }
    }

    fileprivate static func sizeCandidateFilters(for value: String) -> [SearchCandidateNumericFilter]? {
        let normalized = canonicalSearchFunctionName(value.trimmingCharacters(in: .whitespacesAndNewlines))
        let filters: [ComparisonFilter<Int64>]
        switch normalized {
        case "empty":
            filters = [.comparison(.equal, 0)]
        case "tiny":
            filters = [
                .comparison(.greaterThan, 0),
                .comparison(.lessThanOrEqual, 10 * 1_024)
            ]
        case "small":
            filters = [
                .comparison(.greaterThan, 10 * 1_024),
                .comparison(.lessThanOrEqual, 100 * 1_024)
            ]
        case "medium":
            filters = [
                .comparison(.greaterThan, 100 * 1_024),
                .comparison(.lessThanOrEqual, 1_024 * 1_024)
            ]
        case "large":
            filters = [
                .comparison(.greaterThan, 1_024 * 1_024),
                .comparison(.lessThanOrEqual, 16 * 1_024 * 1_024)
            ]
        case "huge":
            filters = [
                .comparison(.greaterThan, 16 * 1_024 * 1_024),
                .comparison(.lessThanOrEqual, 128 * 1_024 * 1_024)
            ]
        case "gigantic":
            filters = [.comparison(.greaterThan, 128 * 1_024 * 1_024)]
        case "unknown":
            return nil
        default:
            return nil
        }

        return filters.flatMap { $0.candidateFilters(field: .byteSize) }
    }

    static func normalizedFolderPath(_ value: String) -> String {
        var normalized = (value as NSString)
            .expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return normalized
    }

    static func isAbsoluteSearchPath(_ value: String) -> Bool {
        value.hasPrefix("/")
    }

    static func knownShellFolderPath(_ rawValue: String) -> String? {
        let name = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !name.isEmpty else {
            return nil
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        func homeChild(_ child: String) -> String {
            URL(fileURLWithPath: home).appendingPathComponent(child).path
        }

        switch name {
        case "home", "user", "userprofile", "profile":
            return normalizedFolderPath(home)
        case "desktop":
            return normalizedFolderPath(homeChild("Desktop"))
        case "documents", "document", "personal", "mydocuments":
            return normalizedFolderPath(homeChild("Documents"))
        case "downloads", "download":
            return normalizedFolderPath(homeChild("Downloads"))
        case "pictures", "picture", "photos", "photo", "mypictures":
            return normalizedFolderPath(homeChild("Pictures"))
        case "music", "mymusic":
            return normalizedFolderPath(homeChild("Music"))
        case "movies", "movie", "videos", "video", "myvideos":
            return normalizedFolderPath(homeChild("Movies"))
        case "public":
            return normalizedFolderPath(homeChild("Public"))
        case "applications", "application", "apps", "programs", "programfiles":
            return normalizedFolderPath("/Applications")
        case "userapplications", "userapplication", "userapps":
            return normalizedFolderPath(homeChild("Applications"))
        case "library", "userlibrary":
            return normalizedFolderPath(homeChild("Library"))
        case "locallibrary":
            return normalizedFolderPath("/Library")
        case "system", "systemlibrary":
            return normalizedFolderPath("/System/Library")
        case "trash", "recyclebin", "recycler":
            return normalizedFolderPath(homeChild(".Trash"))
        case "temp", "tmp", "temporary":
            return normalizedFolderPath(NSTemporaryDirectory())
        case "root":
            return "/"
        default:
            return nil
        }
    }

    private static func addAttributeHint(
        value: String,
        attribute: FileAttributes,
        required: inout FileAttributes,
        excluded: inout FileAttributes
    ) {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "0", "false", "no", "off":
            excluded.insert(attribute)
        default:
            required.insert(attribute)
        }
    }

    private static func containsAngleGrouping(in rawQuery: String) -> Bool {
        var previous: Character?
        var inQuotes = false

        for character in rawQuery {
            if character == "\"" {
                inQuotes.toggle()
            } else if !inQuotes,
                      (character == "<" || character == ">"),
                      previous != ":" {
                return true
            }
            previous = character
        }

        return false
    }

    static func normalize(_ value: String, caseSensitive: Bool = false) -> String {
        var options: String.CompareOptions = []
        if !caseSensitive {
            options.insert(.caseInsensitive)
        }
        options.insert(.diacriticInsensitive)
        return options.isEmpty ? value : value.folding(options: options, locale: .current)
    }

    static func normalize(_ value: String, options searchOptions: SearchOptions) -> String {
        var options: String.CompareOptions = []
        if !searchOptions.caseSensitive {
            options.insert(.caseInsensitive)
        }
        if !searchOptions.diacriticSensitive {
            options.insert(.diacriticInsensitive)
        }
        return options.isEmpty ? value : value.folding(options: options, locale: .current)
    }

    static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        guard !needle.isEmpty else {
            return true
        }

        var cursor = needle.startIndex
        for character in haystack {
            if character == needle[cursor] {
                cursor = needle.index(after: cursor)
                if cursor == needle.endIndex {
                    return true
                }
            }
        }

        return false
    }

    private static func tokenizeCandidateTerms(_ rawQuery: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var index = rawQuery.startIndex

        while index < rawQuery.endIndex {
            if let macro = searchLiteralMacro(at: index, in: rawQuery) {
                appendSearchLiteral(macro.literal, to: &current)
                index = macro.nextIndex
                continue
            }

            let character = rawQuery[index]
            index = rawQuery.index(after: index)

            if character == "\"" {
                inQuotes.toggle()
                continue
            }

            if character == "\\" {
                if index < rawQuery.endIndex {
                    current.append(rawQuery[index])
                    index = rawQuery.index(after: index)
                }
                continue
            }

            if inQuotes, let placeholder = quotedListSeparatorPlaceholder(for: character) {
                current.append(contentsOf: placeholder)
                continue
            }

            if !inQuotes, character == "|" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append("|")
                continue
            }

            if !inQuotes, character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private static func sort(
        matches: [SearchMatch],
        field: SearchSortField,
        direction: SearchSortDirection
    ) -> [SearchMatch] {
        matches.sorted { lhs, rhs in
            let comparison = compare(lhs.entry, rhs.entry, by: field, lhsScore: lhs.score, rhsScore: rhs.score)
            if comparison == .orderedSame {
                return compare(lhs.entry, rhs.entry, by: .name, lhsScore: lhs.score, rhsScore: rhs.score) == .orderedAscending
            }
            return direction == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    private static func compare(
        _ lhs: FileEntry,
        _ rhs: FileEntry,
        by field: SearchSortField,
        lhsScore: Int,
        rhsScore: Int
    ) -> ComparisonResult {
        switch field {
        case .relevance:
            if lhsScore == rhsScore {
                return compareDates(lhs.modifiedAt, rhs.modifiedAt)
            }
            return lhsScore < rhsScore ? .orderedAscending : .orderedDescending
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .path:
            return lhs.path.localizedStandardCompare(rhs.path)
        case .extensionName:
            let extensionCompare = lhs.extensionName.localizedStandardCompare(rhs.extensionName)
            if extensionCompare == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name)
            }
            return extensionCompare
        case .kind:
            let kindCompare = lhs.kind.displayName.localizedStandardCompare(rhs.kind.displayName)
            if kindCompare == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name)
            }
            return kindCompare
        case .size:
            return compareNumbers(lhs.byteSize, rhs.byteSize)
        case .dateModified:
            return compareDates(lhs.modifiedAt, rhs.modifiedAt)
        case .dateCreated:
            return compareDates(lhs.createdAt, rhs.createdAt)
        case .dateAccessed:
            return compareDates(lhs.accessedAt, rhs.accessedAt)
        case .dateIndexed:
            return compareDates(lhs.indexedAt, rhs.indexedAt)
        case .runCount:
            return compareNumbers(Int64(lhs.runCountValue), Int64(rhs.runCountValue))
        case .dateRun:
            return compareDates(lhs.lastRunAt, rhs.lastRunAt)
        case .attributes:
            return ResultExporter.attributeString(for: lhs)
                .localizedStandardCompare(ResultExporter.attributeString(for: rhs))
        case .title:
            return compareStrings(lhs.mediaTitle, rhs.mediaTitle)
        case .artist:
            return compareStrings(lhs.mediaArtist, rhs.mediaArtist)
        case .album:
            return compareStrings(lhs.mediaAlbum, rhs.mediaAlbum)
        case .comment:
            return compareStrings(lhs.mediaComment, rhs.mediaComment)
        case .genre:
            return compareStrings(lhs.mediaGenre, rhs.mediaGenre)
        case .track:
            return compareNumbers(lhs.mediaTrack.map(Int64.init), rhs.mediaTrack.map(Int64.init))
        case .year:
            return compareNumbers(lhs.mediaYear.map(Int64.init), rhs.mediaYear.map(Int64.init))
        }
    }

    private static func compareStrings(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return lhs.localizedStandardCompare(rhs)
        case (_?, nil):
            return .orderedAscending
        case (nil, _?):
            return .orderedDescending
        case (nil, nil):
            return .orderedSame
        }
    }

    private static func compareNumbers(_ lhs: Int64?, _ rhs: Int64?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                return .orderedSame
            }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (_?, nil):
            return .orderedAscending
        case (nil, _?):
            return .orderedDescending
        case (nil, nil):
            return .orderedSame
        }
    }

    private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                return .orderedSame
            }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (_?, nil):
            return .orderedAscending
        case (nil, _?):
            return .orderedDescending
        case (nil, nil):
            return .orderedSame
        }
    }
}

private struct SearchMatch {
    let score: Int
    let entry: FileEntry
}

private struct SearchContext {
    let entries: [FileEntry]
    let normalizedNameCounts: [String: Int]
    let normalizedNamePartCounts: [String: Int]
    let normalizedExtensionCounts: [String: Int]
    let normalizedPathPartCounts: [String: Int]
    let byteSizeCounts: [Int64: Int]
    let createdAtCounts: [TimeInterval: Int]
    let modifiedAtCounts: [TimeInterval: Int]
    let accessedAtCounts: [TimeInterval: Int]
    let attributeCounts: [Int: Int]
    let childCountsByParentPath: [String: Int]
    let childFileCountsByParentPath: [String: Int]
    let childFolderCountsByParentPath: [String: Int]
    let childrenByParentPath: [String: [FileEntry]]
    let entriesByPath: [String: FileEntry]
    let fileSystemIndexBySourceKey: [String: Int]

    init(entries: [FileEntry], options: SearchOptions) {
        var nameCounts: [String: Int] = [:]
        var namePartCounts: [String: Int] = [:]
        var extensionCounts: [String: Int] = [:]
        var pathPartCounts: [String: Int] = [:]
        var sizeCounts: [Int64: Int] = [:]
        var createdCounts: [TimeInterval: Int] = [:]
        var modifiedCounts: [TimeInterval: Int] = [:]
        var accessedCounts: [TimeInterval: Int] = [:]
        var attributes: [Int: Int] = [:]
        var childCounts: [String: Int] = [:]
        var childFileCounts: [String: Int] = [:]
        var childFolderCounts: [String: Int] = [:]
        var children: [String: [FileEntry]] = [:]
        var entriesByPath: [String: FileEntry] = [:]
        var sourceKeys = Set<String>()

        for entry in entries {
            entriesByPath[SearchEngine.normalizedFolderPath(entry.path)] = entry
            sourceKeys.insert(Self.fileSystemSourceKey(for: entry))
            let normalizedName = SearchEngine.normalize(entry.name, options: options)
            nameCounts[normalizedName, default: 0] += 1
            let normalizedNamePart = SearchEngine.normalize(entry.namePart, options: options)
            namePartCounts[normalizedNamePart, default: 0] += 1
            if [.file, .symlink, .other].contains(entry.kind) {
                let normalizedExtension = SearchEngine.normalize(entry.extensionName, options: options)
                extensionCounts[normalizedExtension, default: 0] += 1
            }
            let normalizedPathPart = SearchEngine.normalize(
                SearchEngine.normalizedFolderPath(entry.parent),
                options: options
            )
            pathPartCounts[normalizedPathPart, default: 0] += 1
            if let byteSize = entry.byteSize {
                sizeCounts[byteSize, default: 0] += 1
            }
            if let createdAt = entry.createdAt {
                createdCounts[createdAt.timeIntervalSince1970, default: 0] += 1
            }
            if let modifiedAt = entry.modifiedAt {
                modifiedCounts[modifiedAt.timeIntervalSince1970, default: 0] += 1
            }
            if let accessedAt = entry.accessedAt {
                accessedCounts[accessedAt.timeIntervalSince1970, default: 0] += 1
            }
            attributes[entry.attributes.rawValue, default: 0] += 1
            childCounts[entry.parent, default: 0] += 1
            switch entry.kind {
            case .file, .symlink, .other:
                childFileCounts[entry.parent, default: 0] += 1
            case .folder, .package:
                childFolderCounts[entry.parent, default: 0] += 1
            }
            children[entry.parent, default: []].append(entry)
        }

        self.entries = entries
        normalizedNameCounts = nameCounts
        normalizedNamePartCounts = namePartCounts
        normalizedExtensionCounts = extensionCounts
        normalizedPathPartCounts = pathPartCounts
        byteSizeCounts = sizeCounts
        createdAtCounts = createdCounts
        modifiedAtCounts = modifiedCounts
        accessedAtCounts = accessedCounts
        attributeCounts = attributes
        childCountsByParentPath = childCounts
        childFileCountsByParentPath = childFileCounts
        childFolderCountsByParentPath = childFolderCounts
        childrenByParentPath = children
        self.entriesByPath = entriesByPath
        fileSystemIndexBySourceKey = Dictionary(uniqueKeysWithValues: sourceKeys.sorted().enumerated().map { index, key in
            (key, index)
        })
    }

    func fileSystemIndex(for entry: FileEntry) -> Int? {
        fileSystemIndexBySourceKey[Self.fileSystemSourceKey(for: entry)]
    }

    private static func fileSystemSourceKey(for entry: FileEntry) -> String {
        if let fileListPath = entry.fileListPath, !fileListPath.isEmpty {
            return "filelist:\(fileListPath)"
        }
        if let fileListName = entry.fileListName, !fileListName.isEmpty {
            return "filelist-name:\(fileListName)"
        }
        if let volumeID = entry.volumeID, !volumeID.isEmpty {
            return "volume:\(volumeID)"
        }

        let components = URL(fileURLWithPath: entry.path).standardizedFileURL.pathComponents
        if components.count >= 3, components[0] == "/", components[1] == "Volumes" {
            return "path:/Volumes/\(components[2])"
        }
        return "path:/"
    }

    func hasDuplicateName(_ entry: FileEntry, options: SearchOptions) -> Bool {
        let normalizedName = SearchEngine.normalize(entry.name, options: options)
        return (normalizedNameCounts[normalizedName] ?? 0) > 1
    }

    func hasDuplicateNamePart(_ entry: FileEntry, options: SearchOptions) -> Bool {
        let normalizedNamePart = SearchEngine.normalize(entry.namePart, options: options)
        return (normalizedNamePartCounts[normalizedNamePart] ?? 0) > 1
    }

    func nameFrequency(_ entry: FileEntry, options: SearchOptions) -> Int {
        let normalizedName = SearchEngine.normalize(entry.name, options: options)
        return normalizedNameCounts[normalizedName] ?? 0
    }

    func extensionFrequency(_ entry: FileEntry, options: SearchOptions) -> Int? {
        guard [.file, .symlink, .other].contains(entry.kind) else {
            return nil
        }
        let normalizedExtension = SearchEngine.normalize(entry.extensionName, options: options)
        return normalizedExtensionCounts[normalizedExtension] ?? 0
    }

    func hasDuplicatePathPart(_ entry: FileEntry, options: SearchOptions) -> Bool {
        let normalizedPathPart = SearchEngine.normalize(
            SearchEngine.normalizedFolderPath(entry.parent),
            options: options
        )
        return (normalizedPathPartCounts[normalizedPathPart] ?? 0) > 1
    }

    func hasDuplicateSize(_ entry: FileEntry) -> Bool {
        guard let byteSize = entry.byteSize else {
            return false
        }
        return (byteSizeCounts[byteSize] ?? 0) > 1
    }

    func hasDuplicateCreatedDate(_ entry: FileEntry) -> Bool {
        guard let createdAt = entry.createdAt else {
            return false
        }
        return (createdAtCounts[createdAt.timeIntervalSince1970] ?? 0) > 1
    }

    func hasDuplicateModifiedDate(_ entry: FileEntry) -> Bool {
        guard let modifiedAt = entry.modifiedAt else {
            return false
        }
        return (modifiedAtCounts[modifiedAt.timeIntervalSince1970] ?? 0) > 1
    }

    func hasDuplicateAccessedDate(_ entry: FileEntry) -> Bool {
        guard let accessedAt = entry.accessedAt else {
            return false
        }
        return (accessedAtCounts[accessedAt.timeIntervalSince1970] ?? 0) > 1
    }

    func hasDuplicateAttributes(_ entry: FileEntry) -> Bool {
        (attributeCounts[entry.attributes.rawValue] ?? 0) > 1
    }

    func childCount(for entry: FileEntry) -> Int {
        childCountsByParentPath[entry.path] ?? 0
    }

    func childFileCount(for entry: FileEntry) -> Int {
        childFileCountsByParentPath[entry.path] ?? 0
    }

    func childFolderCount(for entry: FileEntry) -> Int {
        childFolderCountsByParentPath[entry.path] ?? 0
    }

    func totalChildSize(for entry: FileEntry) -> Int64 {
        children(for: entry).reduce(Int64(0)) { total, child in
            switch child.kind {
            case .file, .symlink, .other:
                return total + (child.byteSize ?? 0)
            case .folder, .package:
                return total
            }
        }
    }

    func children(for entry: FileEntry) -> [FileEntry] {
        childrenByParentPath[entry.path] ?? []
    }

    func children(parentPath: String) -> [FileEntry] {
        childrenByParentPath[parentPath] ?? []
    }

    func descendants(for entry: FileEntry, allowedKinds: Set<FileKind>? = nil) -> [FileEntry] {
        var descendants: [FileEntry] = []
        var stack = children(for: entry)
        var visited = Set<String>()

        while let current = stack.popLast() {
            guard visited.insert(current.path).inserted else {
                continue
            }

            if allowedKinds?.contains(current.kind) ?? true {
                descendants.append(current)
            }

            switch current.kind {
            case .folder, .package:
                stack.append(contentsOf: children(for: current))
            case .file, .symlink, .other:
                break
            }
        }

        return descendants
    }

    func descendantCount(for entry: FileEntry, allowedKinds: Set<FileKind>? = nil) -> Int {
        descendants(for: entry, allowedKinds: allowedKinds).count
    }

    func ancestors(for entry: FileEntry) -> [FileEntry] {
        var ancestors: [FileEntry] = []
        var current = SearchEngine.normalizedFolderPath(entry.parent)
        var visited = Set<String>()

        while !current.isEmpty, visited.insert(current).inserted {
            if let ancestor = entriesByPath[current] {
                ancestors.append(ancestor)
            }
            guard current != "/" else {
                break
            }
            current = SearchEngine.normalizedFolderPath(URL(fileURLWithPath: current).deletingLastPathComponent().path)
        }

        return ancestors
    }

    func parentEntry(for entry: FileEntry) -> FileEntry? {
        entriesByPath[SearchEngine.normalizedFolderPath(entry.parent)]
    }

    func siblings(for entry: FileEntry) -> [FileEntry] {
        (childrenByParentPath[entry.parent] ?? []).filter { $0.path != entry.path }
    }

    func siblingCount(for entry: FileEntry) -> Int {
        max(0, (childCountsByParentPath[entry.parent] ?? 0) - 1)
    }

    func siblingFileCount(for entry: FileEntry) -> Int {
        let fileCount = childFileCountsByParentPath[entry.parent] ?? 0
        switch entry.kind {
        case .file, .symlink, .other:
            return max(0, fileCount - 1)
        case .folder, .package:
            return fileCount
        }
    }

    func siblingFolderCount(for entry: FileEntry) -> Int {
        let folderCount = childFolderCountsByParentPath[entry.parent] ?? 0
        switch entry.kind {
        case .folder, .package:
            return max(0, folderCount - 1)
        case .file, .symlink, .other:
            return folderCount
        }
    }
}

private struct ParsedSearch {
    let expression: SearchExpression?
    let warnings: [String]
    let limitOverride: Int?
    let offsetOverride: Int?
    let sortFieldOverride: SearchSortField?
    let sortDirectionOverride: SearchSortDirection?

    var isEmpty: Bool {
        expression?.isEmpty ?? true
    }

    func score(entry: FileEntry, options: SearchOptions, context: SearchContext) -> Int? {
        expression?.score(entry: entry, options: options, context: context)
    }
}

private indirect enum SearchExpression {
    case term(SearchTerm)
    case and([SearchExpression])
    case or([SearchExpression])
    case not(SearchExpression)

    var isEmpty: Bool {
        switch self {
        case .term:
            return false
        case let .and(expressions), let .or(expressions):
            return expressions.allSatisfy(\.isEmpty)
        case let .not(expression):
            return expression.isEmpty
        }
    }

    func score(entry: FileEntry, options: SearchOptions, context: SearchContext) -> Int? {
        switch self {
        case let .term(term):
            return term.score(entry: entry, options: options, context: context)
        case let .and(expressions):
            var total = 0
            for expression in expressions {
                guard let score = expression.score(entry: entry, options: options, context: context) else {
                    return nil
                }
                total += score
            }
            return total
        case let .or(expressions):
            let scores = expressions.compactMap {
                $0.score(entry: entry, options: options, context: context)
            }
            return scores.min()
        case let .not(expression):
            return expression.score(entry: entry, options: options, context: context) == nil ? 0 : nil
        }
    }
}

private struct SearchTerm {
    let predicate: SearchPredicate

    func score(entry: FileEntry, options: SearchOptions, context: SearchContext) -> Int? {
        predicate.score(entry: entry, options: options, context: context)
    }
}

private struct SearchOptionOverrides {
    var matchPath: Bool?
    var caseSensitive: Bool?
    var regexMatching: Bool?
    var wholeWordMatching: Bool?
    var diacriticSensitive: Bool?

    var isEmpty: Bool {
        matchPath == nil &&
            caseSensitive == nil &&
            regexMatching == nil &&
            wholeWordMatching == nil &&
            diacriticSensitive == nil
    }

    func applying(to options: SearchOptions) -> SearchOptions {
        var scoped = options
        if let matchPath {
            scoped.matchPath = matchPath
        }
        if let caseSensitive {
            scoped.caseSensitive = caseSensitive
        }
        if let regexMatching {
            scoped.regexMatching = regexMatching
        }
        if let wholeWordMatching {
            scoped.wholeWordMatching = wholeWordMatching
        }
        if let diacriticSensitive {
            scoped.diacriticSensitive = diacriticSensitive
        }
        return scoped
    }
}

private enum ContentEncoding {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian
    case ansi

    static let fallbackOrder: [ContentEncoding] = [
        .utf8,
        .utf16LittleEndian,
        .utf16BigEndian,
        .ansi
    ]

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8:
            return .utf8
        case .utf16LittleEndian:
            return .utf16LittleEndian
        case .utf16BigEndian:
            return .utf16BigEndian
        case .ansi:
            return .windowsCP1252
        }
    }
}

private indirect enum SearchPredicate {
    case and([SearchPredicate])
    case withOptions(SearchOptionOverrides, SearchPredicate)
    case text(String)
    case wildcard(String)
    case regex(String)
    case wholeFilename(String)
    case fileList(Set<String>)
    case fileListFilename(Set<String>)
    case fileReferenceNumber(Set<String>)
    case fileSystemIndex(ComparisonFilter<Int>)
    case pathList(Set<String>)
    case extensionList(Set<String>)
    case noExtension
    case path(String)
    case fullPath(String)
    case pathPart(String)
    case name(String)
    case namePart(String)
    case mediaAlbum(String)
    case mediaArtist(String)
    case mediaComment(String)
    case mediaGenre(String)
    case mediaTitle(String)
    case mediaTrack(ComparisonFilter<Int>)
    case mediaYear(ComparisonFilter<Int>)
    case exists(String, Set<FileKind>?)
    case parent(String)
    case parentPlusDepth(String, Int)
    case parentExactDepth(String, Int)
    case parentName(String)
    case parentPath(String)
    case parentDateCreated(DateFilter)
    case parentDateModified(DateFilter)
    case parentSize(ComparisonFilter<Int64>)
    case ancestor(String)
    case ancestorName(String)
    case shellFolder(String)
    case kind(Set<FileKind>)
    case size(ComparisonFilter<Int64>)
    case sizeUnknown
    case dateModified(DateFilter)
    case dateCreated(DateFilter)
    case dateAccessed(DateFilter)
    case dateRun(DateFilter)
    case recentChange(DateFilter)
    case runCount(ComparisonFilter<Int>)
    case depth(ComparisonFilter<Int>)
    case characterCount(ComparisonFilter<Int>)
    case nameLength(ComparisonFilter<Int>)
    case namePartLength(ComparisonFilter<Int>)
    case nameUTF8Length(ComparisonFilter<Int>)
    case pathLength(ComparisonFilter<Int>)
    case pathUTF8Length(ComparisonFilter<Int>)
    case pathPartLength(ComparisonFilter<Int>)
    case extensionLength(ComparisonFilter<Int>)
    case childCount(ComparisonFilter<Int>)
    case childFileCount(ComparisonFilter<Int>)
    case childFolderCount(ComparisonFilter<Int>)
    case totalChildSize(ComparisonFilter<Int64>)
    case childDateAccessed(DateFilter, Set<FileKind>?)
    case childDateCreated(DateFilter, Set<FileKind>?)
    case childDateModified(DateFilter, Set<FileKind>?)
    case childRecentChange(DateFilter, Set<FileKind>?)
    case childDateRun(DateFilter, Set<FileKind>?)
    case childRunCount(ComparisonFilter<Int>, Set<FileKind>?)
    case childSize(ComparisonFilter<Int64>, Set<FileKind>?)
    case descendantCount(ComparisonFilter<Int>, Set<FileKind>?)
    case siblingCount(ComparisonFilter<Int>)
    case siblingFileCount(ComparisonFilter<Int>)
    case siblingFolderCount(ComparisonFilter<Int>)
    case child(String, Set<FileKind>?)
    case childAttributes(AttributeFilter, Set<FileKind>?)
    case childFileList(Set<String>)
    case descendant(String, Set<FileKind>?)
    case ancestorAttributes(AttributeFilter)
    case ancestorChild(String, Set<FileKind>?)
    case parentChild(String, Set<FileKind>?)
    case sibling(String, Set<FileKind>?)
    case parentSibling(String, Set<FileKind>?)
    case ancestorSibling(String, Set<FileKind>?)
    case root
    case imageWidth(ComparisonFilter<Int>)
    case imageHeight(ComparisonFilter<Int>)
    case imageBitDepth(ComparisonFilter<Int>)
    case imageDimensions(DimensionsFilter)
    case imageOrientation(ImageOrientationFilter)
    case imageAspectRatio(AspectRatioFilter)
    case startsWith(String)
    case endsWith(String)
    case empty
    case notEmpty
    case duplicateName
    case uniqueName
    case nameFrequency(ComparisonFilter<Int>)
    case duplicateNamePart
    case uniqueNamePart
    case extensionFrequency(ComparisonFilter<Int>)
    case duplicatePathPart
    case uniquePathPart
    case duplicateSize
    case uniqueSize
    case duplicateCreatedDate
    case uniqueCreatedDate
    case duplicateModifiedDate
    case uniqueModifiedDate
    case duplicateAccessedDate
    case uniqueAccessedDate
    case duplicateAttributes
    case uniqueAttributes
    case category(FileCategory)
    case attributes(AttributeFilter)
    case content(String, ContentEncoding?)
    case formula(FormulaExpression)
    case always
    case never(String)

    func score(entry: FileEntry, options: SearchOptions, context: SearchContext) -> Int? {
        switch self {
        case let .and(predicates):
            var total = 0
            for predicate in predicates {
                guard let score = predicate.score(entry: entry, options: options, context: context) else {
                    return nil
                }
                total += score
            }
            return total
        case let .withOptions(overrides, predicate):
            return predicate.score(entry: entry, options: overrides.applying(to: options), context: context)
        case let .text(value):
            if options.regexMatching {
                return regexScore(pattern: value, entry: entry, options: options)
            }
            return textScore(value: value, entry: entry, options: options)
        case let .wildcard(pattern):
            if options.regexMatching {
                return regexScore(pattern: pattern, entry: entry, options: options)
            }
            return wildcardScore(pattern: pattern, entry: entry, options: options)
        case let .regex(pattern):
            return regexScore(pattern: pattern, entry: entry, options: options)
        case let .wholeFilename(value):
            return wholeFilenameScore(value: value, entry: entry, options: options)
        case let .fileList(values):
            return fileListScore(values: values, entry: entry, options: options)
        case let .fileListFilename(values):
            return fileListFilenameScore(values: values, entry: entry, options: options)
        case let .fileReferenceNumber(values):
            return fileReferenceNumberScore(values: values, entry: entry) ? 2 : nil
        case let .fileSystemIndex(filter):
            guard let index = context.fileSystemIndex(for: entry) else {
                return nil
            }
            return filter.matches(index) ? 2 : nil
        case let .pathList(values):
            return pathListScore(values: values, entry: entry, options: options)
        case let .extensionList(extensions):
            return extensions.contains(entry.extensionName.lowercased()) ? 2 : nil
        case .noExtension:
            return [.file, .symlink, .other].contains(entry.kind) && entry.extensionName.isEmpty ? 2 : nil
        case let .path(value):
            return contains(substituteSearchValue(value, entry: entry), in: entry.path, options: options) ? 8 : nil
        case let .fullPath(value):
            return fullPathScore(value: value, entry: entry, options: options)
        case let .pathPart(value):
            return pathPartScore(value: value, entry: entry, options: options)
        case let .name(value):
            return contains(substituteSearchValue(value, entry: entry), in: entry.name, options: options) ? 4 : nil
        case let .namePart(value):
            return contains(substituteSearchValue(value, entry: entry), in: entry.namePart, options: options) ? 4 : nil
        case let .mediaAlbum(value):
            return mediaTextScore(value: value, candidate: entry.mediaAlbum, entry: entry, options: options)
        case let .mediaArtist(value):
            return mediaTextScore(value: value, candidate: entry.mediaArtist, entry: entry, options: options)
        case let .mediaComment(value):
            return mediaTextScore(value: value, candidate: entry.mediaComment, entry: entry, options: options)
        case let .mediaGenre(value):
            return mediaTextScore(value: value, candidate: entry.mediaGenre, entry: entry, options: options)
        case let .mediaTitle(value):
            return mediaTextScore(value: value, candidate: entry.mediaTitle, entry: entry, options: options)
        case let .mediaTrack(filter):
            guard let mediaTrack = entry.mediaTrack else {
                return nil
            }
            return filter.matches(mediaTrack) ? 2 : nil
        case let .mediaYear(filter):
            guard let mediaYear = entry.mediaYear else {
                return nil
            }
            return filter.matches(mediaYear) ? 2 : nil
        case let .exists(value, kinds):
            return existsScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .parent(value):
            return parentScore(value: value, entry: entry, options: options)
        case let .parentPlusDepth(value, depth):
            return parentDepthScore(value: value, maxDepth: depth, entry: entry, options: options)
        case let .parentExactDepth(value, depth):
            return parentDepthScore(value: value, exactDepth: depth, entry: entry, options: options)
        case let .parentName(value):
            return parentNameScore(value: value, entry: entry, options: options)
        case let .parentPath(value):
            return parentPathScore(value: value, entry: entry, options: options)
        case let .parentDateCreated(filter):
            guard let parent = context.parentEntry(for: entry) else {
                return nil
            }
            return filter.matches(parent.createdAt) ? 1 : nil
        case let .parentDateModified(filter):
            guard let parent = context.parentEntry(for: entry) else {
                return nil
            }
            return filter.matches(parent.modifiedAt) ? 1 : nil
        case let .parentSize(filter):
            guard let byteSize = context.parentEntry(for: entry)?.byteSize else {
                return nil
            }
            return filter.matches(byteSize) ? 1 : nil
        case let .ancestor(value):
            return ancestorScore(value: value, entry: entry, options: options)
        case let .ancestorName(value):
            return ancestorNameScore(value: value, entry: entry, options: options)
        case let .shellFolder(path):
            return shellFolderScore(path: path, entry: entry, options: options)
        case let .kind(kinds):
            return kinds.contains(entry.kind) ? 1 : nil
        case let .size(filter):
            guard let byteSize = entry.byteSize else {
                return nil
            }
            return filter.matches(byteSize) ? 1 : nil
        case .sizeUnknown:
            return entry.byteSize == nil ? 1 : nil
        case let .dateModified(filter):
            return filter.matches(entry.modifiedAt) ? 1 : nil
        case let .dateCreated(filter):
            return filter.matches(entry.createdAt) ? 1 : nil
        case let .dateAccessed(filter):
            return filter.matches(entry.accessedAt) ? 1 : nil
        case let .dateRun(filter):
            return filter.matches(entry.lastRunAt) ? 1 : nil
        case let .recentChange(filter):
            return filter.matches(entry.indexedAt) ? 1 : nil
        case let .runCount(filter):
            return filter.matches(entry.runCountValue) ? 1 : nil
        case let .depth(filter):
            return filter.matches(entry.depth) ? 1 : nil
        case let .characterCount(filter):
            return filter.matches(entry.name.count) ? 1 : nil
        case let .nameLength(filter):
            return filter.matches(entry.name.utf16.count) ? 1 : nil
        case let .namePartLength(filter):
            return filter.matches(entry.namePart.utf16.count) ? 1 : nil
        case let .nameUTF8Length(filter):
            return filter.matches(entry.name.utf8.count) ? 1 : nil
        case let .pathLength(filter):
            return filter.matches(entry.path.utf16.count) ? 1 : nil
        case let .pathUTF8Length(filter):
            return filter.matches(entry.path.utf8.count) ? 1 : nil
        case let .pathPartLength(filter):
            return filter.matches(SearchEngine.normalizedFolderPath(entry.parent).utf16.count) ? 1 : nil
        case let .extensionLength(filter):
            return filter.matches(entry.extensionName.utf16.count) ? 1 : nil
        case let .childCount(filter):
            guard isContainer(entry) else {
                return nil
            }
            return filter.matches(context.childCount(for: entry)) ? 1 : nil
        case let .childFileCount(filter):
            guard isContainer(entry) else {
                return nil
            }
            return filter.matches(context.childFileCount(for: entry)) ? 1 : nil
        case let .childFolderCount(filter):
            guard isContainer(entry) else {
                return nil
            }
            return filter.matches(context.childFolderCount(for: entry)) ? 1 : nil
        case let .totalChildSize(filter):
            guard isContainer(entry) else {
                return nil
            }
            return filter.matches(context.totalChildSize(for: entry)) ? 1 : nil
        case let .childDateAccessed(filter, kinds):
            return childDateScore(filter: filter, allowedKinds: kinds, entry: entry, context: context) { $0.accessedAt }
        case let .childDateCreated(filter, kinds):
            return childDateScore(filter: filter, allowedKinds: kinds, entry: entry, context: context) { $0.createdAt }
        case let .childDateModified(filter, kinds):
            return childDateScore(filter: filter, allowedKinds: kinds, entry: entry, context: context) { $0.modifiedAt }
        case let .childRecentChange(filter, kinds):
            return childDateScore(filter: filter, allowedKinds: kinds, entry: entry, context: context) { $0.indexedAt }
        case let .childDateRun(filter, kinds):
            return childDateScore(filter: filter, allowedKinds: kinds, entry: entry, context: context) { $0.lastRunAt }
        case let .childRunCount(filter, kinds):
            return childRunCountScore(filter: filter, allowedKinds: kinds, entry: entry, context: context)
        case let .childSize(filter, kinds):
            return childSizeScore(filter: filter, allowedKinds: kinds, entry: entry, context: context)
        case let .descendantCount(filter, kinds):
            guard isContainer(entry) else {
                return nil
            }
            return filter.matches(context.descendantCount(for: entry, allowedKinds: kinds)) ? 1 : nil
        case let .siblingCount(filter):
            return filter.matches(context.siblingCount(for: entry)) ? 1 : nil
        case let .siblingFileCount(filter):
            return filter.matches(context.siblingFileCount(for: entry)) ? 1 : nil
        case let .siblingFolderCount(filter):
            return filter.matches(context.siblingFolderCount(for: entry)) ? 1 : nil
        case let .child(value, kinds):
            return childScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .childAttributes(filter, kinds):
            return childAttributeScore(filter: filter, allowedKinds: kinds, entry: entry, context: context)
        case let .childFileList(values):
            return childFileListScore(values: values, entry: entry, options: options, context: context)
        case let .descendant(value, kinds):
            return descendantScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .ancestorAttributes(filter):
            return ancestorAttributeScore(filter: filter, entry: entry, context: context)
        case let .ancestorChild(value, kinds):
            return ancestorChildScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .parentChild(value, kinds):
            return parentChildScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .sibling(value, kinds):
            return siblingScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .parentSibling(value, kinds):
            return parentSiblingScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case let .ancestorSibling(value, kinds):
            return ancestorSiblingScore(value: value, allowedKinds: kinds, entry: entry, options: options, context: context)
        case .root:
            return isRootEntry(entry) ? 1 : nil
        case let .imageWidth(filter):
            guard let dimensions = imageDimensions(for: entry) else {
                return nil
            }
            return filter.matches(dimensions.width) ? 1 : nil
        case let .imageHeight(filter):
            guard let dimensions = imageDimensions(for: entry) else {
                return nil
            }
            return filter.matches(dimensions.height) ? 1 : nil
        case let .imageBitDepth(filter):
            guard let bitDepth = imageBitDepth(for: entry) else {
                return nil
            }
            return filter.matches(bitDepth) ? 1 : nil
        case let .imageDimensions(filter):
            guard let dimensions = imageDimensions(for: entry) else {
                return nil
            }
            return filter.matches(dimensions) ? 1 : nil
        case let .imageOrientation(filter):
            guard let dimensions = imageDimensions(for: entry) else {
                return nil
            }
            return filter.matches(dimensions) ? 1 : nil
        case let .imageAspectRatio(filter):
            guard let dimensions = imageDimensions(for: entry) else {
                return nil
            }
            return filter.matches(dimensions) ? 1 : nil
        case let .startsWith(value):
            return startsWith(substituteSearchValue(value, entry: entry), in: entry.name, options: options) ? 4 : nil
        case let .endsWith(value):
            return endsWith(substituteSearchValue(value, entry: entry), in: entry.name, options: options) ? 8 : nil
        case .empty:
            return isEmpty(entry: entry, context: context) ? 1 : nil
        case .notEmpty:
            return isEmpty(entry: entry, context: context) ? nil : 1
        case .duplicateName:
            return context.hasDuplicateName(entry, options: options) ? 1 : nil
        case .uniqueName:
            return context.hasDuplicateName(entry, options: options) ? nil : 1
        case let .nameFrequency(filter):
            return filter.matches(context.nameFrequency(entry, options: options)) ? 1 : nil
        case .duplicateNamePart:
            return context.hasDuplicateNamePart(entry, options: options) ? 1 : nil
        case .uniqueNamePart:
            return context.hasDuplicateNamePart(entry, options: options) ? nil : 1
        case let .extensionFrequency(filter):
            guard let frequency = context.extensionFrequency(entry, options: options) else {
                return nil
            }
            return filter.matches(frequency) ? 1 : nil
        case .duplicatePathPart:
            return context.hasDuplicatePathPart(entry, options: options) ? 1 : nil
        case .uniquePathPart:
            return context.hasDuplicatePathPart(entry, options: options) ? nil : 1
        case .duplicateSize:
            return context.hasDuplicateSize(entry) ? 1 : nil
        case .uniqueSize:
            return context.hasDuplicateSize(entry) ? nil : 1
        case .duplicateCreatedDate:
            return context.hasDuplicateCreatedDate(entry) ? 1 : nil
        case .uniqueCreatedDate:
            return context.hasDuplicateCreatedDate(entry) ? nil : 1
        case .duplicateModifiedDate:
            return context.hasDuplicateModifiedDate(entry) ? 1 : nil
        case .uniqueModifiedDate:
            return context.hasDuplicateModifiedDate(entry) ? nil : 1
        case .duplicateAccessedDate:
            return context.hasDuplicateAccessedDate(entry) ? 1 : nil
        case .uniqueAccessedDate:
            return context.hasDuplicateAccessedDate(entry) ? nil : 1
        case .duplicateAttributes:
            return context.hasDuplicateAttributes(entry) ? 1 : nil
        case .uniqueAttributes:
            return context.hasDuplicateAttributes(entry) ? nil : 1
        case let .category(category):
            return category.matches(entry) ? 2 : nil
        case let .attributes(filter):
            return filter.matches(entry.attributes) ? 1 : nil
        case let .content(value, encoding):
            return contentScore(value: value, entry: entry, options: options, encoding: encoding)
        case let .formula(formula):
            return formula.matches(entry: entry, options: options, context: context) ? 1 : nil
        case .always:
            return 0
        case .never:
            return nil
        }
    }

    private func textScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let query = SearchEngine.normalize(substituteSearchValue(value, entry: entry), options: options)
        let name = SearchEngine.normalize(entry.name, options: options)
        let path = SearchEngine.normalize(entry.path, options: options)

        if name == query {
            return 0
        }
        if options.wholeWordMatching {
            if containsWholeWord(query, in: name) {
                return 10
            }
            if shouldSearchPath(query, options: options), containsWholeWord(query, in: path) {
                return 26
            }
            return nil
        }
        if name.hasPrefix(query) {
            return 4
        }
        if name.contains(query) {
            return 12
        }
        if shouldSearchPath(query, options: options), path.contains(query) {
            return 28
        }
        if options.fuzzyMatching, SearchEngine.isSubsequence(query, of: name) {
            return 56
        }

        return nil
    }

    private func wholeFilenameScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        SearchEngine.normalize(entry.name, options: options) ==
            SearchEngine.normalize(substituteSearchValue(value, entry: entry), options: options) ? 0 : nil
    }

    private func fileListScore(values: Set<String>, entry: FileEntry, options: SearchOptions) -> Int? {
        for rawValue in values {
            let value = substituteSearchValue(rawValue, entry: entry)
            let usesPath = value.contains("/") || value.contains("\\")
            let candidate = usesPath
                ? SearchEngine.normalizedFolderPath(entry.path)
                : entry.name
            let normalizedValue = usesPath
                ? SearchEngine.normalizedFolderPath(value.replacingOccurrences(of: "\\", with: "/"))
                : value

            if fileListValue(normalizedValue, matches: candidate, isPathPattern: usesPath, options: options) {
                return 2
            }
        }
        return nil
    }

    private func fileListFilenameScore(values: Set<String>, entry: FileEntry, options: SearchOptions) -> Int? {
        guard let fileListName = entry.fileListName, let fileListPath = entry.fileListPath else {
            return nil
        }
        guard !values.isEmpty else {
            return 2
        }

        let candidates = [fileListName, fileListPath, URL(fileURLWithPath: fileListPath).lastPathComponent]
        for rawValue in values {
            let value = substituteSearchValue(rawValue, entry: entry)
            let usesPath = value.contains("/") || value.contains("\\")
            let normalizedValue = usesPath
                ? SearchEngine.normalizedFolderPath(value.replacingOccurrences(of: "\\", with: "/"))
                : value

            for candidate in candidates {
                let normalizedCandidate = usesPath
                    ? SearchEngine.normalizedFolderPath(candidate)
                    : candidate
                if fileListValue(normalizedValue, matches: normalizedCandidate, isPathPattern: usesPath, options: options) {
                    return 2
                }
            }
        }
        return nil
    }

    private func fileReferenceNumberScore(values: Set<String>, entry: FileEntry) -> Bool {
        guard let fileID = entry.fileID, !fileID.isEmpty else {
            return false
        }
        guard !values.isEmpty else {
            return true
        }

        let candidates = [
            fileID,
            entry.identityKey
        ].compactMap { $0.map(normalizeFileReferenceNumber) }

        return values
            .map(normalizeFileReferenceNumber)
            .contains { value in
                candidates.contains(value)
            }
    }

    private func normalizeFileReferenceNumber(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    private func mediaTextScore(value: String, candidate: String?, entry: FileEntry, options: SearchOptions) -> Int? {
        guard let candidate, !candidate.isEmpty else {
            return nil
        }
        let resolvedValue = substituteSearchValue(value, entry: entry)
        guard !resolvedValue.isEmpty else {
            return 2
        }
        return contains(resolvedValue, in: candidate, options: options) ? 2 : nil
    }

    private func fileListValue(
        _ value: String,
        matches candidate: String,
        isPathPattern: Bool,
        options: SearchOptions
    ) -> Bool {
        let normalizedValue = SearchEngine.normalize(value, options: options)
        let normalizedCandidate = SearchEngine.normalize(candidate, options: options)

        guard normalizedValue.contains("*") || normalizedValue.contains("?") else {
            return normalizedValue == normalizedCandidate
        }

        let regex = "^" + fileListWildcardRegexPattern(
            for: normalizedValue,
            pathAware: isPathPattern
        ) + "$"
        return matchesRegex(regex, in: normalizedCandidate, caseSensitive: true)
    }

    private func fileListWildcardRegexPattern(for pattern: String, pathAware: Bool) -> String {
        var regex = ""
        var index = pattern.startIndex

        while index < pattern.endIndex {
            let character = pattern[index]
            if character == "*" {
                let nextIndex = pattern.index(after: index)
                if pathAware, nextIndex < pattern.endIndex, pattern[nextIndex] == "*" {
                    regex += ".*"
                    index = pattern.index(after: nextIndex)
                    continue
                }
                regex += pathAware ? "[^/]*" : ".*"
                index = nextIndex
                continue
            }

            if character == "?" {
                regex += pathAware ? "[^/]" : "."
                index = pattern.index(after: index)
                continue
            }

            regex += NSRegularExpression.escapedPattern(for: String(character))
            index = pattern.index(after: index)
        }

        return regex
    }

    private func fullPathScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(
            resolvedValue.replacingOccurrences(of: "\\", with: "/")
        )
        guard !normalizedValue.isEmpty else {
            return 0
        }

        if normalizedValue.contains("*") || normalizedValue.contains("?") {
            return fileListValue(
                normalizedValue,
                matches: SearchEngine.normalizedFolderPath(entry.path),
                isPathPattern: true,
                options: options
            ) ? 8 : nil
        }

        return contains(normalizedValue, in: entry.path, options: options) ? 8 : nil
    }

    private func existsScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let substituted = substituteSearchValue(value, entry: entry)
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !substituted.isEmpty else {
            return nil
        }

        let usesPath = substituted.contains("/")
        let targetPattern = usesPath
            ? SearchEngine.normalizedFolderPath(substituted)
            : SearchEngine.normalizedFolderPath(joinPath(entry.parent, substituted))

        if !targetPattern.contains("*"), !targetPattern.contains("?") {
            guard let found = context.entriesByPath[SearchEngine.normalizedFolderPath(targetPattern)] else {
                return nil
            }
            if let allowedKinds, !allowedKinds.contains(found.kind) {
                return nil
            }
            return 1
        }

        let candidates: [FileEntry]
        if usesPath {
            candidates = context.entries
        } else {
            candidates = context.children(parentPath: entry.parent)
        }

        for candidate in candidates {
            if let allowedKinds, !allowedKinds.contains(candidate.kind) {
                continue
            }
            if fileListValue(
                targetPattern,
                matches: SearchEngine.normalizedFolderPath(candidate.path),
                isPathPattern: true,
                options: options
            ) {
                return 1
            }
        }
        return nil
    }

    private func substituteSearchValue(_ value: String, entry: FileEntry) -> String {
        guard value.contains("$") else {
            return value
        }

        var result = value
        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        let parentName = parentPath == "/" ? "/" : URL(fileURLWithPath: parentPath).lastPathComponent
        let normalizedPath = SearchEngine.normalizedFolderPath(entry.path)
        let byteSize = entry.byteSize.map(String.init) ?? ""
        let nameLength = String(entry.name.utf16.count)
        let stemLength = String(entry.namePart.utf16.count)
        let extensionLength = String(entry.extensionName.utf16.count)
        let pathLength = String(entry.path.utf16.count)
        let substitutions: [(String, String)] = [
            ("$stem:", entry.namePart),
            ("$namepart:", entry.namePart),
            ("$name-part:", entry.namePart),
            ("$name:", entry.name),
            ("$filename:", entry.name),
            ("$file-name:", entry.name),
            ("$basename:", entry.name),
            ("$base-name:", entry.name),
            ("$extension:", entry.extensionName),
            ("$ext:", entry.extensionName),
            ("$parentname:", parentName),
            ("$parent-name:", parentName),
            ("$parent:", parentPath),
            ("$parentpath:", parentPath),
            ("$parent-path:", parentPath),
            ("$parentfullpath:", parentPath),
            ("$parent-full-path:", parentPath),
            ("$fullpath:", normalizedPath),
            ("$full-path:", normalizedPath),
            ("$pathandname:", normalizedPath),
            ("$path-and-name:", normalizedPath),
            ("$pathname:", normalizedPath),
            ("$path-name:", normalizedPath),
            ("$path:", normalizedPath),
            ("$filesize:", byteSize),
            ("$file-size:", byteSize),
            ("$size:", byteSize),
            ("$kind:", entry.kind.displayName),
            ("$type:", entry.kind.displayName),
            ("$attributes:", ResultExporter.attributeString(for: entry)),
            ("$attribute:", ResultExporter.attributeString(for: entry)),
            ("$attrib:", ResultExporter.attributeString(for: entry)),
            ("$attr:", ResultExporter.attributeString(for: entry)),
            ("$depth:", String(entry.depth)),
            ("$parents:", String(entry.depth)),
            ("$parentcount:", String(entry.depth)),
            ("$parent-count:", String(entry.depth)),
            ("$runcount:", String(entry.runCountValue)),
            ("$run-count:", String(entry.runCountValue)),
            ("$runs:", String(entry.runCountValue)),
            ("$namelen:", nameLength),
            ("$name-len:", nameLength),
            ("$namelength:", nameLength),
            ("$name-length:", nameLength),
            ("$basenamelen:", nameLength),
            ("$basename-len:", nameLength),
            ("$basenamelength:", nameLength),
            ("$basename-length:", nameLength),
            ("$stemlen:", stemLength),
            ("$stem-len:", stemLength),
            ("$stemlength:", stemLength),
            ("$stem-length:", stemLength),
            ("$namepartlen:", stemLength),
            ("$namepart-len:", stemLength),
            ("$namepartlength:", stemLength),
            ("$namepart-length:", stemLength),
            ("$extlen:", extensionLength),
            ("$ext-len:", extensionLength),
            ("$extlength:", extensionLength),
            ("$ext-length:", extensionLength),
            ("$extensionlen:", extensionLength),
            ("$extension-len:", extensionLength),
            ("$extensionlength:", extensionLength),
            ("$extension-length:", extensionLength),
            ("$pathlen:", pathLength),
            ("$path-len:", pathLength),
            ("$pathlength:", pathLength),
            ("$path-length:", pathLength),
            ("$fullpathlen:", pathLength),
            ("$full-path-len:", pathLength),
            ("$fullpathlength:", pathLength),
            ("$full-path-length:", pathLength)
        ]

        for (placeholder, replacement) in substitutions {
            result = result.replacingOccurrences(of: placeholder, with: replacement)
        }
        return result
    }

    private func joinPath(_ parent: String, _ name: String) -> String {
        let normalizedParent = SearchEngine.normalizedFolderPath(parent)
        if normalizedParent.isEmpty || normalizedParent == "/" {
            return "/" + name
        }
        return normalizedParent + "/" + name
    }

    private func pathListScore(values: Set<String>, entry: FileEntry, options: SearchOptions) -> Int? {
        let normalizedValues = Set(values.map {
            SearchEngine.normalize(
                SearchEngine.normalizedFolderPath(substituteSearchValue($0, entry: entry)),
                options: options
            )
        })
        let normalizedPath = SearchEngine.normalize(SearchEngine.normalizedFolderPath(entry.path), options: options)
        return normalizedValues.contains(normalizedPath) ? 2 : nil
    }

    private func parentScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(resolvedValue)
        guard !normalizedValue.isEmpty else {
            return 0
        }

        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        if SearchEngine.isAbsoluteSearchPath(normalizedValue) {
            return SearchEngine.normalize(parentPath, options: options) ==
                SearchEngine.normalize(normalizedValue, options: options) ? 8 : nil
        }

        let parentName = URL(fileURLWithPath: parentPath).lastPathComponent
        return contains(normalizedValue, in: parentName, options: options) ? 8 : nil
    }

    private func parentDepthScore(
        value: String,
        maxDepth: Int,
        entry: FileEntry,
        options: SearchOptions
    ) -> Int? {
        guard let depth = relativeParentDepth(value: value, entry: entry, options: options) else {
            return nil
        }
        return depth <= maxDepth ? 8 : nil
    }

    private func parentDepthScore(
        value: String,
        exactDepth: Int,
        entry: FileEntry,
        options: SearchOptions
    ) -> Int? {
        guard let depth = relativeParentDepth(value: value, entry: entry, options: options) else {
            return nil
        }
        return depth == exactDepth ? 8 : nil
    }

    private func relativeParentDepth(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(resolvedValue)
        guard !normalizedValue.isEmpty else {
            return 0
        }
        guard SearchEngine.isAbsoluteSearchPath(normalizedValue) else {
            return nil
        }

        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        let normalizedNeedle = SearchEngine.normalize(normalizedValue, options: options)
        let normalizedParent = SearchEngine.normalize(parentPath, options: options)

        if normalizedParent == normalizedNeedle {
            return 0
        }

        let prefix = normalizedNeedle == "/" ? "/" : normalizedNeedle + "/"
        guard normalizedParent.hasPrefix(prefix) else {
            return nil
        }

        let suffix = normalizedParent.dropFirst(prefix.count)
        return suffix.split(separator: "/", omittingEmptySubsequences: true).count
    }

    private func pathPartScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        guard !resolvedValue.isEmpty else {
            return 0
        }

        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        let parts = parentPath.split(separator: "/").map(String.init)
        let candidates = [parentPath] + parts
        guard candidates.contains(where: { !$0.isEmpty }) else {
            return nil
        }

        if resolvedValue.contains("*") || resolvedValue.contains("?") {
            let normalizedPattern = SearchEngine.normalize(resolvedValue, options: options)
            let regex = "^" + NSRegularExpression.escapedPattern(for: normalizedPattern)
                .replacingOccurrences(of: "\\*", with: ".*")
                .replacingOccurrences(of: "\\?", with: ".") + "$"
            return candidates.contains { candidate in
                let normalizedCandidate = SearchEngine.normalize(candidate, options: options)
                return matchesRegex(regex, in: normalizedCandidate, caseSensitive: true)
            } ? 8 : nil
        }

        return candidates.contains { candidate in
            contains(resolvedValue, in: candidate, options: options)
        } ? 8 : nil
    }

    private func parentNameScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(resolvedValue)
        guard !normalizedValue.isEmpty else {
            return 0
        }

        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        let parentName = parentPath == "/" ? "/" : URL(fileURLWithPath: parentPath).lastPathComponent
        return contains(normalizedValue, in: parentName, options: options) ? 8 : nil
    }

    private func parentPathScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(resolvedValue)
        guard !normalizedValue.isEmpty else {
            return 0
        }

        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        return contains(normalizedValue, in: parentPath, options: options) ? 8 : nil
    }

    private func ancestorScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(resolvedValue)
        guard !normalizedValue.isEmpty else {
            return 0
        }

        let ancestors = ancestorPaths(for: entry)
        guard !ancestors.isEmpty else {
            return nil
        }

        if SearchEngine.isAbsoluteSearchPath(normalizedValue) {
            let normalizedNeedle = SearchEngine.normalize(normalizedValue, options: options)
            return ancestors.contains { ancestor in
                SearchEngine.normalize(ancestor, options: options) == normalizedNeedle
            } ? 8 : nil
        }

        return ancestors.contains { ancestor in
            let ancestorName = ancestor == "/" ? "/" : URL(fileURLWithPath: ancestor).lastPathComponent
            return contains(normalizedValue, in: ancestorName, options: options)
        } ? 8 : nil
    }

    private func ancestorNameScore(value: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let normalizedValue = SearchEngine.normalizedFolderPath(resolvedValue)
        guard !normalizedValue.isEmpty else {
            return 0
        }

        return ancestorPaths(for: entry).contains { ancestor in
            let ancestorName = ancestor == "/" ? "/" : URL(fileURLWithPath: ancestor).lastPathComponent
            return contains(normalizedValue, in: ancestorName, options: options)
        } ? 8 : nil
    }

    private func shellFolderScore(path: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let folder = SearchEngine.normalizedFolderPath(path)
        guard !folder.isEmpty else {
            return nil
        }

        let normalizedFolder = SearchEngine.normalize(folder, options: options)
        let entryPath = SearchEngine.normalize(SearchEngine.normalizedFolderPath(entry.path), options: options)
        let parentPath = SearchEngine.normalize(SearchEngine.normalizedFolderPath(entry.parent), options: options)

        if entryPath == normalizedFolder || parentPath == normalizedFolder {
            return 8
        }

        let prefix = normalizedFolder == "/" ? "/" : normalizedFolder + "/"
        return parentPath.hasPrefix(prefix) ? 8 : nil
    }

    private func ancestorPaths(for entry: FileEntry) -> [String] {
        var paths: [String] = []
        var current = SearchEngine.normalizedFolderPath(entry.parent)
        var seen = Set<String>()

        while !current.isEmpty, !seen.contains(current) {
            paths.append(current)
            seen.insert(current)

            guard current != "/" else {
                break
            }

            let parent = SearchEngine.normalizedFolderPath(
                URL(fileURLWithPath: current).deletingLastPathComponent().path
            )
            guard parent != current else {
                break
            }
            current = parent
        }

        return paths
    }

    private func wildcardScore(pattern: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedPattern = substituteSearchValue(pattern, entry: entry)
        let normalizedPattern = SearchEngine.normalize(resolvedPattern, options: options)
        let normalizedName = SearchEngine.normalize(entry.name, options: options)
        let regex = "^" + NSRegularExpression.escapedPattern(for: normalizedPattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".") + "$"

        let candidates = wildcardCandidates(for: resolvedPattern, entry: entry, options: options)
        for candidate in candidates {
            let normalizedCandidate = SearchEngine.normalize(candidate, options: options)
            if matchesRegex(regex, in: normalizedCandidate, caseSensitive: true) {
                return normalizedCandidate == normalizedName ? 6 : 22
            }
        }

        return nil
    }

    private func regexScore(pattern: String, entry: FileEntry, options: SearchOptions) -> Int? {
        let resolvedPattern = substituteSearchValue(pattern, entry: entry)
        let normalizedPattern = regexPattern(resolvedPattern, options: options)
        let candidates = regexCandidates(entry: entry, options: options)
        for (index, candidate) in candidates.enumerated() {
            if matchesRegex(normalizedPattern, in: candidate, caseSensitive: options.caseSensitive) {
                return index == 0 ? 5 : 20
            }
        }
        return nil
    }

    private func contentScore(
        value: String,
        entry: FileEntry,
        options: SearchOptions,
        encoding: ContentEncoding?
    ) -> Int? {
        guard entry.kind == .file,
              let byteSize = entry.byteSize,
              byteSize <= 4 * 1_024 * 1_024 else {
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: entry.path)) else {
            return nil
        }

        let encodings = encoding.map { [$0] } ?? ContentEncoding.fallbackOrder
        let normalizedNeedle = SearchEngine.normalize(substituteSearchValue(value, entry: entry), options: options)
        for encoding in encodings {
            guard let text = String(data: data, encoding: encoding.stringEncoding) else {
                continue
            }

            let normalizedText = SearchEngine.normalize(text, options: options)
            if options.wholeWordMatching {
                if containsWholeWord(normalizedNeedle, in: normalizedText) {
                    return 120
                }
            } else if normalizedText.contains(normalizedNeedle) {
                return 120
            }
        }
        return nil
    }

    private func isEmpty(entry: FileEntry, context: SearchContext) -> Bool {
        switch entry.kind {
        case .file, .symlink, .other:
            return entry.byteSize == 0
        case .folder, .package:
            return context.childCount(for: entry) == 0
        }
    }

    private func isContainer(_ entry: FileEntry) -> Bool {
        entry.kind == .folder || entry.kind == .package
    }

    private func isRootEntry(_ entry: FileEntry) -> Bool {
        entry.parent.isEmpty || entry.parent == "/" || entry.path == "/"
    }

    private func imageDimensions(for entry: FileEntry) -> ImageDimensions? {
        guard entry.kind == .file,
              FileCategory.image.matches(entry),
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: entry.path) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return ImageDimensions(width: width, height: height)
    }

    private func imageBitDepth(for entry: FileEntry) -> Int? {
        guard entry.kind == .file,
              FileCategory.image.matches(entry),
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: entry.path) as CFURL, nil) else {
            return nil
        }

        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let depth = properties[kCGImagePropertyDepth] as? Int {
                return depth
            }
            if let depth = properties[kCGImagePropertyDepth] as? NSNumber {
                return depth.intValue
            }
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image.bitsPerPixel
    }

    private func childScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }
        let resolvedValue = substituteSearchValue(value, entry: entry)

        let children = context.children(for: entry).filter { child in
            guard let allowedKinds else {
                return true
            }
            return allowedKinds.contains(child.kind)
        }
        guard !children.isEmpty else {
            return nil
        }

        guard !resolvedValue.isEmpty else {
            return 1
        }

        for child in children where childMatches(value: resolvedValue, child: child, options: options) {
            return 1
        }
        return nil
    }

    private func childAttributeScore(
        filter: AttributeFilter,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        context: SearchContext
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }

        for child in context.children(for: entry) {
            if let allowedKinds, !allowedKinds.contains(child.kind) {
                continue
            }
            if filter.matches(child.attributes) {
                return 1
            }
        }
        return nil
    }

    private func childDateScore(
        filter: DateFilter,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        context: SearchContext,
        dateValue: (FileEntry) -> Date?
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }

        for child in context.children(for: entry) {
            if let allowedKinds, !allowedKinds.contains(child.kind) {
                continue
            }
            if filter.matches(dateValue(child)) {
                return 1
            }
        }
        return nil
    }

    private func childRunCountScore(
        filter: ComparisonFilter<Int>,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        context: SearchContext
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }

        for child in context.children(for: entry) {
            if let allowedKinds, !allowedKinds.contains(child.kind) {
                continue
            }
            if filter.matches(child.runCountValue) {
                return 1
            }
        }
        return nil
    }

    private func childSizeScore(
        filter: ComparisonFilter<Int64>,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        context: SearchContext
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }

        for child in context.children(for: entry) {
            if let allowedKinds, !allowedKinds.contains(child.kind) {
                continue
            }
            guard let byteSize = child.byteSize else {
                continue
            }
            if filter.matches(byteSize) {
                return 1
            }
        }
        return nil
    }

    private func childFileListScore(
        values: Set<String>,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }

        let normalizedNameValues = Set(values
            .filter { !$0.contains("/") && !$0.contains("\\") }
            .map { SearchEngine.normalize($0, options: options) })
        let normalizedPathValues = Set(values
            .filter { $0.contains("/") || $0.contains("\\") }
            .map {
                SearchEngine.normalize(
                    SearchEngine.normalizedFolderPath($0.replacingOccurrences(of: "\\", with: "/")),
                    options: options
                )
            })

        guard !normalizedNameValues.isEmpty || !normalizedPathValues.isEmpty else {
            return nil
        }

        for child in context.children(for: entry) {
            let childName = SearchEngine.normalize(child.name, options: options)
            if normalizedNameValues.contains(childName) {
                return 1
            }

            let childPath = SearchEngine.normalize(
                SearchEngine.normalizedFolderPath(child.path),
                options: options
            )
            if normalizedPathValues.contains(childPath) {
                return 1
            }
        }
        return nil
    }

    private func ancestorAttributeScore(
        filter: AttributeFilter,
        entry: FileEntry,
        context: SearchContext
    ) -> Int? {
        for ancestor in context.ancestors(for: entry) where filter.matches(ancestor.attributes) {
            return 1
        }
        return nil
    }

    private func ancestorChildScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        for ancestor in ancestorPaths(for: entry) {
            let children = context.children(parentPath: ancestor).filter { child in
                guard let allowedKinds else {
                    return true
                }
                return allowedKinds.contains(child.kind)
            }
            guard !children.isEmpty else {
                continue
            }

            if resolvedValue.isEmpty {
                return 1
            }

            for child in children where childMatches(value: resolvedValue, child: child, options: options) {
                return 1
            }
        }
        return nil
    }

    private func parentChildScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let children = context.children(parentPath: entry.parent).filter { child in
            guard let allowedKinds else {
                return true
            }
            return allowedKinds.contains(child.kind)
        }
        guard !children.isEmpty else {
            return nil
        }

        guard !resolvedValue.isEmpty else {
            return 1
        }

        for child in children where childMatches(value: resolvedValue, child: child, options: options) {
            return 1
        }
        return nil
    }

    private func descendantScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        guard entry.kind == .folder || entry.kind == .package else {
            return nil
        }
        let resolvedValue = substituteSearchValue(value, entry: entry)

        let descendants = context.descendants(for: entry, allowedKinds: allowedKinds)
        guard !descendants.isEmpty else {
            return nil
        }

        guard !resolvedValue.isEmpty else {
            return 1
        }

        for descendant in descendants where childMatches(value: resolvedValue, child: descendant, options: options) {
            return 1
        }
        return nil
    }

    private func siblingScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let siblings = context.siblings(for: entry).filter { sibling in
            guard let allowedKinds else {
                return true
            }
            return allowedKinds.contains(sibling.kind)
        }
        guard !siblings.isEmpty else {
            return nil
        }

        guard !resolvedValue.isEmpty else {
            return 1
        }

        for sibling in siblings where childMatches(value: resolvedValue, child: sibling, options: options) {
            return 1
        }
        return nil
    }

    private func parentSiblingScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
        guard !parentPath.isEmpty else {
            return nil
        }
        return siblingOfPathScore(
            path: parentPath,
            value: resolvedValue,
            allowedKinds: allowedKinds,
            options: options,
            context: context
        )
    }

    private func ancestorSiblingScore(
        value: String,
        allowedKinds: Set<FileKind>?,
        entry: FileEntry,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let resolvedValue = substituteSearchValue(value, entry: entry)
        for ancestor in ancestorPaths(for: entry) {
            if siblingOfPathScore(
                path: ancestor,
                value: resolvedValue,
                allowedKinds: allowedKinds,
                options: options,
                context: context
            ) != nil {
                return 1
            }
        }
        return nil
    }

    private func siblingOfPathScore(
        path: String,
        value: String,
        allowedKinds: Set<FileKind>?,
        options: SearchOptions,
        context: SearchContext
    ) -> Int? {
        let normalizedPath = SearchEngine.normalizedFolderPath(path)
        guard !normalizedPath.isEmpty else {
            return nil
        }

        let parentPath = parentPath(for: normalizedPath)
        let siblings = context.children(parentPath: parentPath).filter { sibling in
            guard sibling.path != normalizedPath else {
                return false
            }
            guard let allowedKinds else {
                return true
            }
            return allowedKinds.contains(sibling.kind)
        }
        guard !siblings.isEmpty else {
            return nil
        }

        guard !value.isEmpty else {
            return 1
        }

        for sibling in siblings where childMatches(value: value, child: sibling, options: options) {
            return 1
        }
        return nil
    }

    private func parentPath(for path: String) -> String {
        guard path != "/" else {
            return "/"
        }
        return SearchEngine.normalizedFolderPath(URL(fileURLWithPath: path).deletingLastPathComponent().path)
    }

    private func childMatches(value: String, child: FileEntry, options: SearchOptions) -> Bool {
        let candidates = shouldSearchPath(value, options: options)
            ? [child.name, child.path]
            : [child.name]

        if value.contains("*") || value.contains("?") {
            let normalizedPattern = SearchEngine.normalize(value, options: options)
            let regex = "^" + NSRegularExpression.escapedPattern(for: normalizedPattern)
                .replacingOccurrences(of: "\\*", with: ".*")
                .replacingOccurrences(of: "\\?", with: ".") + "$"
            return candidates.contains { candidate in
                let normalizedCandidate = SearchEngine.normalize(candidate, options: options)
                return matchesRegex(regex, in: normalizedCandidate, caseSensitive: true)
            }
        }

        return candidates.contains { contains(value, in: $0, options: options) }
    }

    private func wildcardCandidates(for pattern: String, entry: FileEntry, options: SearchOptions) -> [String] {
        if pattern.contains("/") || pattern.contains("\\") || options.matchPath {
            return [entry.name, entry.path]
        }
        return [entry.name]
    }

    private func regexPattern(_ pattern: String, options: SearchOptions) -> String {
        guard !options.diacriticSensitive else {
            return pattern
        }
        return pattern.folding(options: [.diacriticInsensitive], locale: .current)
    }

    private func regexCandidates(entry: FileEntry, options: SearchOptions) -> [String] {
        let candidates = [entry.name, entry.path]
        guard !options.diacriticSensitive else {
            return candidates
        }
        return candidates.map { $0.folding(options: [.diacriticInsensitive], locale: .current) }
    }

    private func shouldSearchPath(_ query: String, options: SearchOptions) -> Bool {
        options.matchPath || query.contains("/") || query.contains("\\")
    }

    private func startsWith(_ needle: String, in haystack: String, options: SearchOptions) -> Bool {
        let normalizedNeedle = SearchEngine.normalize(needle, options: options)
        let normalizedHaystack = SearchEngine.normalize(haystack, options: options)
        return normalizedHaystack.hasPrefix(normalizedNeedle)
    }

    private func endsWith(_ needle: String, in haystack: String, options: SearchOptions) -> Bool {
        let normalizedNeedle = SearchEngine.normalize(needle, options: options)
        let normalizedHaystack = SearchEngine.normalize(haystack, options: options)
        return normalizedHaystack.hasSuffix(normalizedNeedle)
    }

    private func contains(_ needle: String, in haystack: String, options: SearchOptions) -> Bool {
        let normalizedNeedle = SearchEngine.normalize(needle, options: options)
        let normalizedHaystack = SearchEngine.normalize(haystack, options: options)
        if options.wholeWordMatching {
            return containsWholeWord(normalizedNeedle, in: normalizedHaystack)
        }
        return normalizedHaystack.contains(normalizedNeedle)
    }

    private func containsWholeWord(_ needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty else {
            return true
        }

        var searchStart = haystack.startIndex
        while searchStart <= haystack.endIndex,
              let range = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            let hasLeftBoundary = range.lowerBound == haystack.startIndex ||
                isWordBoundary(haystack[haystack.index(before: range.lowerBound)])
            let hasRightBoundary = range.upperBound == haystack.endIndex ||
                isWordBoundary(haystack[range.upperBound])

            if hasLeftBoundary && hasRightBoundary {
                return true
            }
            searchStart = range.upperBound
        }

        return false
    }

    private func isWordBoundary(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.alphanumerics.contains(scalar) && scalar != "_"
        }
    }

    private func matchesRegex(_ pattern: String, in candidate: String, caseSensitive: Bool) -> Bool {
        do {
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            return regex.firstMatch(in: candidate, range: range) != nil
        } catch {
            return false
        }
    }
}

private struct FormulaExpression {
    private enum Kind {
        case comparison(FormulaValueExpression, ComparisonOperator, FormulaValueExpression)
        case exists(FormulaValueExpression)
        case contains(FormulaValueExpression, FormulaValueExpression)
        case startsWith(FormulaValueExpression, FormulaValueExpression)
        case endsWith(FormulaValueExpression, FormulaValueExpression)
    }

    private let kind: Kind

    func matches(entry: FileEntry, options: SearchOptions, context: SearchContext) -> Bool {
        switch kind {
        case let .comparison(lhs, op, rhs):
            guard let lhsValue = lhs.value(entry: entry, context: context),
                  let rhsValue = rhs.value(entry: entry, context: context) else {
                return false
            }
            return compare(lhsValue, op: op, rhs: rhsValue, options: options)
        case let .exists(expression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue else {
                return false
            }
            let normalizedPath = SearchEngine.normalizedFolderPath(value.replacingOccurrences(of: "\\", with: "/"))
            guard !normalizedPath.isEmpty else {
                return false
            }
            return context.entriesByPath[normalizedPath] != nil
        case let .contains(lhs, rhs):
            guard let lhsValue = lhs.value(entry: entry, context: context)?.stringValue,
                  let rhsValue = rhs.value(entry: entry, context: context)?.stringValue else {
                return false
            }
            return SearchEngine.normalize(lhsValue, options: options)
                .contains(SearchEngine.normalize(rhsValue, options: options))
        case let .startsWith(lhs, rhs):
            guard let lhsValue = lhs.value(entry: entry, context: context)?.stringValue,
                  let rhsValue = rhs.value(entry: entry, context: context)?.stringValue else {
                return false
            }
            return SearchEngine.normalize(lhsValue, options: options)
                .hasPrefix(SearchEngine.normalize(rhsValue, options: options))
        case let .endsWith(lhs, rhs):
            guard let lhsValue = lhs.value(entry: entry, context: context)?.stringValue,
                  let rhsValue = rhs.value(entry: entry, context: context)?.stringValue else {
                return false
            }
            return SearchEngine.normalize(lhsValue, options: options)
                .hasSuffix(SearchEngine.normalize(rhsValue, options: options))
        }
    }

    static func parse(_ rawValue: String) -> FormulaExpression? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let inner = unwrapFunction(value, named: "exists"),
           let expression = FormulaValueExpression.parse(inner) {
            return FormulaExpression(kind: .exists(expression))
        }

        guard value.contains("$") else {
            return nil
        }

        if let expressions = parseTwoArgumentFunction(value, named: "contains") {
            return FormulaExpression(kind: .contains(expressions.0, expressions.1))
        }

        if let expressions = parseTwoArgumentFunction(value, named: "startswith") {
            return FormulaExpression(kind: .startsWith(expressions.0, expressions.1))
        }

        if let expressions = parseTwoArgumentFunction(value, named: "endswith") {
            return FormulaExpression(kind: .endsWith(expressions.0, expressions.1))
        }

        let operators: [(String, ComparisonOperator)] = [
            ("==", .equal),
            ("!=", .notEqual),
            (">=", .greaterThanOrEqual),
            ("<=", .lessThanOrEqual),
            (">", .greaterThan),
            ("<", .lessThan)
        ]

        for (symbol, op) in operators {
            guard let range = topLevelRange(of: symbol, in: value) else {
                continue
            }

            let lhsText = String(value[..<range.lowerBound])
            let rhsText = String(value[range.upperBound...])
            guard let lhs = FormulaValueExpression.parse(lhsText),
                  let rhs = FormulaValueExpression.parse(rhsText) else {
                return nil
            }
            return FormulaExpression(kind: .comparison(lhs, op, rhs))
        }

        return nil
    }

    private static func parseTwoArgumentFunction(
        _ value: String,
        named name: String
    ) -> (FormulaValueExpression, FormulaValueExpression)? {
        guard let inner = unwrapFunction(value, named: name) else {
            return nil
        }

        let arguments = splitTopLevelArguments(inner)
        guard arguments.count == 2,
              let lhs = FormulaValueExpression.parse(arguments[0]),
              let rhs = FormulaValueExpression.parse(arguments[1]) else {
            return nil
        }
        return (lhs, rhs)
    }

    private func compare(
        _ lhs: FormulaValue,
        op: ComparisonOperator,
        rhs: FormulaValue,
        options: SearchOptions
    ) -> Bool {
        if let lhsNumber = lhs.numberValue, let rhsNumber = rhs.numberValue {
            return compareValues(lhsNumber, op: op, rhs: rhsNumber)
        }

        if case let .date(lhsDate) = lhs, case let .date(rhsDate) = rhs {
            return compareValues(lhsDate, op: op, rhs: rhsDate)
        }

        guard let lhsString = lhs.stringValue, let rhsString = rhs.stringValue else {
            return false
        }
        let normalizedLHS = SearchEngine.normalize(lhsString, options: options)
        let normalizedRHS = SearchEngine.normalize(rhsString, options: options)
        return compareValues(normalizedLHS, op: op, rhs: normalizedRHS)
    }

    private func compareValues<T: Comparable>(_ lhs: T, op: ComparisonOperator, rhs: T) -> Bool {
        switch op {
        case .equal:
            return lhs == rhs
        case .notEqual:
            return lhs != rhs
        case .lessThan:
            return lhs < rhs
        case .lessThanOrEqual:
            return lhs <= rhs
        case .greaterThan:
            return lhs > rhs
        case .greaterThanOrEqual:
            return lhs >= rhs
        }
    }
}

private indirect enum FormulaValueExpression {
    case string(String)
    case number(Double)
    case property(String, Int?)
    case upper(FormulaValueExpression)
    case lower(FormulaValueExpression)
    case trim(FormulaValueExpression)
    case length(FormulaValueExpression)
    case abs(FormulaValueExpression)
    case round(FormulaValueExpression)
    case year(FormulaValueExpression)
    case month(FormulaValueExpression)
    case day(FormulaValueExpression)
    case hour(FormulaValueExpression)
    case minute(FormulaValueExpression)
    case second(FormulaValueExpression)
    case left(FormulaValueExpression, FormulaValueExpression)
    case right(FormulaValueExpression, FormulaValueExpression)
    case mid(FormulaValueExpression, FormulaValueExpression, FormulaValueExpression?)
    case add(FormulaValueExpression, FormulaValueExpression)
    case subtract(FormulaValueExpression, FormulaValueExpression)
    case multiply(FormulaValueExpression, FormulaValueExpression)
    case divide(FormulaValueExpression, FormulaValueExpression)
    case modulo(FormulaValueExpression, FormulaValueExpression)

    func value(entry: FileEntry, context: SearchContext) -> FormulaValue? {
        switch self {
        case let .string(value):
            return .string(value)
        case let .number(value):
            return .number(value)
        case let .property(name, index):
            guard var value = propertyValue(name, entry: entry, context: context) else {
                return nil
            }
            if let index {
                guard let stringValue = value.stringValue,
                      index >= 0,
                      index < stringValue.count else {
                    return nil
                }
                let stringIndex = stringValue.index(stringValue.startIndex, offsetBy: index)
                value = .string(String(stringValue[stringIndex]))
            }
            return value
        case let .upper(expression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue else {
                return nil
            }
            return .string(value.uppercased())
        case let .lower(expression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue else {
                return nil
            }
            return .string(value.lowercased())
        case let .trim(expression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue else {
                return nil
            }
            return .string(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case let .length(expression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue else {
                return nil
            }
            return .number(Double(value.utf16.count))
        case let .abs(expression):
            guard let value = expression.value(entry: entry, context: context)?.numberValue else {
                return nil
            }
            return .number(Swift.abs(value))
        case let .round(expression):
            guard let value = expression.value(entry: entry, context: context)?.numberValue else {
                return nil
            }
            return .number(value.rounded())
        case let .year(expression):
            return dateComponent(.year, from: expression, entry: entry, context: context)
        case let .month(expression):
            return dateComponent(.month, from: expression, entry: entry, context: context)
        case let .day(expression):
            return dateComponent(.day, from: expression, entry: entry, context: context)
        case let .hour(expression):
            return dateComponent(.hour, from: expression, entry: entry, context: context)
        case let .minute(expression):
            return dateComponent(.minute, from: expression, entry: entry, context: context)
        case let .second(expression):
            return dateComponent(.second, from: expression, entry: entry, context: context)
        case let .left(expression, countExpression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue,
                  let count = countExpression.value(entry: entry, context: context)?.intValue else {
                return nil
            }
            let clampedCount = max(0, min(count, value.count))
            return .string(String(value.prefix(clampedCount)))
        case let .right(expression, countExpression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue,
                  let count = countExpression.value(entry: entry, context: context)?.intValue else {
                return nil
            }
            let clampedCount = max(0, min(count, value.count))
            return .string(String(value.suffix(clampedCount)))
        case let .mid(expression, startExpression, countExpression):
            guard let value = expression.value(entry: entry, context: context)?.stringValue,
                  let start = startExpression.value(entry: entry, context: context)?.intValue else {
                return nil
            }
            guard start >= 0, start < value.count else {
                return .string("")
            }
            let startIndex = value.index(value.startIndex, offsetBy: start)
            let tail = value[startIndex...]
            if let countExpression {
                guard let count = countExpression.value(entry: entry, context: context)?.intValue else {
                    return nil
                }
                return .string(String(tail.prefix(max(0, count))))
            }
            return .string(String(tail))
        case let .add(lhs, rhs):
            return numeric(lhs, rhs, entry: entry, context: context) { $0 + $1 }
        case let .subtract(lhs, rhs):
            return numeric(lhs, rhs, entry: entry, context: context) { $0 - $1 }
        case let .multiply(lhs, rhs):
            return numeric(lhs, rhs, entry: entry, context: context) { $0 * $1 }
        case let .divide(lhs, rhs):
            guard let lhsValue = lhs.value(entry: entry, context: context)?.numberValue,
                  let rhsValue = rhs.value(entry: entry, context: context)?.numberValue,
                  rhsValue != 0 else {
                return nil
            }
            return .number(lhsValue / rhsValue)
        case let .modulo(lhs, rhs):
            guard let lhsValue = lhs.value(entry: entry, context: context)?.numberValue,
                  let rhsValue = rhs.value(entry: entry, context: context)?.numberValue,
                  rhsValue != 0 else {
                return nil
            }
            return .number(lhsValue.truncatingRemainder(dividingBy: rhsValue))
        }
    }

    private func numeric(
        _ lhs: FormulaValueExpression,
        _ rhs: FormulaValueExpression,
        entry: FileEntry,
        context: SearchContext,
        operation: (Double, Double) -> Double
    ) -> FormulaValue? {
        guard let lhsValue = lhs.value(entry: entry, context: context)?.numberValue,
              let rhsValue = rhs.value(entry: entry, context: context)?.numberValue else {
            return nil
        }
        return .number(operation(lhsValue, rhsValue))
    }

    private func dateComponent(
        _ component: Calendar.Component,
        from expression: FormulaValueExpression,
        entry: FileEntry,
        context: SearchContext
    ) -> FormulaValue? {
        guard let value = expression.value(entry: entry, context: context)?.dateValue else {
            return nil
        }
        return .number(Double(Calendar.current.component(component, from: value)))
    }

    static func parse(_ rawValue: String) -> FormulaValueExpression? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        if let arithmetic = parseArithmetic(value, operators: [("+", FormulaValueExpression.add), ("-", FormulaValueExpression.subtract)]) {
            return arithmetic
        }

        if let arithmetic = parseArithmetic(
            value,
            operators: [
                ("*", FormulaValueExpression.multiply),
                ("/", FormulaValueExpression.divide),
                ("%", FormulaValueExpression.modulo)
            ]
        ) {
            return arithmetic
        }

        if let inner = unwrapFunction(value, named: "upper"), let expression = parse(inner) {
            return .upper(expression)
        }

        if let inner = unwrapFunction(value, named: "lower"), let expression = parse(inner) {
            return .lower(expression)
        }

        if let inner = unwrapFunction(value, named: "trim"), let expression = parse(inner) {
            return .trim(expression)
        }

        if let inner = unwrapFunction(value, named: "len"), let expression = parse(inner) {
            return .length(expression)
        }

        if let inner = unwrapFunction(value, named: "abs"), let expression = parse(inner) {
            return .abs(expression)
        }

        if let inner = unwrapFunction(value, named: "round"), let expression = parse(inner) {
            return .round(expression)
        }

        if let inner = unwrapFunction(value, named: "year"), let expression = parse(inner) {
            return .year(expression)
        }

        if let inner = unwrapFunction(value, named: "month"), let expression = parse(inner) {
            return .month(expression)
        }

        if let inner = unwrapFunction(value, named: "day"), let expression = parse(inner) {
            return .day(expression)
        }

        if let inner = unwrapFunction(value, named: "hour"), let expression = parse(inner) {
            return .hour(expression)
        }

        if let inner = unwrapFunction(value, named: "minute"), let expression = parse(inner) {
            return .minute(expression)
        }

        if let inner = unwrapFunction(value, named: "second"), let expression = parse(inner) {
            return .second(expression)
        }

        if let expression = parseLeftRight(value, named: "left", builder: FormulaValueExpression.left) {
            return expression
        }

        if let expression = parseLeftRight(value, named: "right", builder: FormulaValueExpression.right) {
            return expression
        }

        if let expression = parseMid(value) {
            return expression
        }

        if let property = parseProperty(value) {
            return property
        }

        if let number = Double(value) {
            return .number(number)
        }

        if isQuoted(value, quote: "'") || isQuoted(value, quote: "\"") {
            return .string(String(value.dropFirst().dropLast()))
        }

        return .string(value)
    }

    private static func parseArithmetic(
        _ value: String,
        operators: [(String, (FormulaValueExpression, FormulaValueExpression) -> FormulaValueExpression)]
    ) -> FormulaValueExpression? {
        for (symbol, builder) in operators {
            guard let range = topLevelArithmeticRange(of: symbol, in: value) else {
                continue
            }
            let lhsText = String(value[..<range.lowerBound])
            let rhsText = String(value[range.upperBound...])
            guard let lhs = parse(lhsText), let rhs = parse(rhsText) else {
                return nil
            }
            return builder(lhs, rhs)
        }
        return nil
    }

    private static func parseLeftRight(
        _ value: String,
        named name: String,
        builder: (FormulaValueExpression, FormulaValueExpression) -> FormulaValueExpression
    ) -> FormulaValueExpression? {
        guard let inner = unwrapFunction(value, named: name) else {
            return nil
        }

        let arguments = splitTopLevelArguments(inner)
        guard arguments.count == 2,
              let text = parse(arguments[0]),
              let count = parse(arguments[1]) else {
            return nil
        }
        return builder(text, count)
    }

    private static func parseMid(_ value: String) -> FormulaValueExpression? {
        guard let inner = unwrapFunction(value, named: "mid") ?? unwrapFunction(value, named: "substr") ?? unwrapFunction(value, named: "substring") else {
            return nil
        }

        let arguments = splitTopLevelArguments(inner)
        guard arguments.count == 2 || arguments.count == 3,
              let text = parse(arguments[0]),
              let start = parse(arguments[1]) else {
            return nil
        }
        let count = arguments.count == 3 ? parse(arguments[2]) : nil
        if arguments.count == 3 && count == nil {
            return nil
        }
        return .mid(text, start, count)
    }

    private static func parseProperty(_ value: String) -> FormulaValueExpression? {
        guard value.hasPrefix("$"),
              let colonIndex = value.firstIndex(of: ":") else {
            return nil
        }

        let name = String(value[value.index(after: value.startIndex)..<colonIndex])
        let suffix = value[value.index(after: colonIndex)...]
        guard name.isEmpty == false else {
            return nil
        }

        var index: Int?
        if !suffix.isEmpty {
            guard suffix.first == "[", suffix.last == "]" else {
                return nil
            }
            let indexText = suffix.dropFirst().dropLast()
            guard let parsedIndex = Int(indexText) else {
                return nil
            }
            index = parsedIndex
        }

        return .property(canonicalSearchFunctionName(name), index)
    }

    private func propertyValue(_ property: String, entry: FileEntry, context: SearchContext) -> FormulaValue? {
        switch canonicalSearchFunctionName(property) {
        case "name", "filename", "basename":
            return .string(entry.name)
        case "stem", "namepart":
            return .string(entry.namePart)
        case "extension", "ext":
            return .string(entry.extensionName)
        case "path", "fullpath", "pathandname", "pathname":
            return .string(SearchEngine.normalizedFolderPath(entry.path))
        case "parent", "parentpath", "parentfullpath":
            return .string(SearchEngine.normalizedFolderPath(entry.parent))
        case "parentname":
            let parentPath = SearchEngine.normalizedFolderPath(entry.parent)
            return .string(parentPath == "/" ? "/" : URL(fileURLWithPath: parentPath).lastPathComponent)
        case "size", "filesize":
            guard let byteSize = entry.byteSize else {
                return nil
            }
            return .number(Double(byteSize))
        case "len", "length", "namelen", "namelength", "basenamelen", "basenamelength":
            return .number(Double(entry.name.utf16.count))
        case "stemlen", "stemlength", "namepartlen", "namepartlength":
            return .number(Double(entry.namePart.utf16.count))
        case "extlen", "extlength", "extensionlen", "extensionlength":
            return .number(Double(entry.extensionName.utf16.count))
        case "pathlen", "pathlength", "fullpathlen", "fullpathlength":
            return .number(Double(entry.path.utf16.count))
        case "depth", "parents", "parentcount":
            return .number(Double(entry.depth))
        case "runcount", "runs":
            return .number(Double(entry.runCountValue))
        case "child", "children", "childcount", "childrencount":
            return .number(Double(context.childCount(for: entry)))
        case "childfilecount", "childfiles", "childrenfiles":
            return .number(Double(context.childFileCount(for: entry)))
        case "childfoldercount", "childfolders", "childrenfolders":
            return .number(Double(context.childFolderCount(for: entry)))
        case "descendant", "descendants", "descendantcount", "descendantscount":
            return .number(Double(context.descendantCount(for: entry)))
        case "descendantfilecount", "descendantfiles", "descendantsfiles":
            return .number(Double(context.descendantCount(for: entry, allowedKinds: [.file, .symlink, .other])))
        case "descendantfoldercount", "descendantfolders", "descendantsfolders":
            return .number(Double(context.descendantCount(for: entry, allowedKinds: [.folder, .package])))
        case "sibling", "siblings", "siblingcount", "siblingscount":
            return .number(Double(context.siblingCount(for: entry)))
        case "siblingfilecount", "siblingfiles", "siblingsfiles":
            return .number(Double(context.siblingFileCount(for: entry)))
        case "siblingfoldercount", "siblingfolders", "siblingsfolders":
            return .number(Double(context.siblingFolderCount(for: entry)))
        case "datemodified", "datemodifieddate", "dm", "date":
            guard let modifiedAt = entry.modifiedAt else {
                return nil
            }
            return .date(modifiedAt)
        case "datecreated", "datecreateddate", "dc":
            guard let createdAt = entry.createdAt else {
                return nil
            }
            return .date(createdAt)
        case "dateaccessed", "dateaccesseddate", "da":
            guard let accessedAt = entry.accessedAt else {
                return nil
            }
            return .date(accessedAt)
        case "daterun", "dr":
            guard let lastRunAt = entry.lastRunAt else {
                return nil
            }
            return .date(lastRunAt)
        case "recentchange", "rc", "dateindexed":
            return .date(entry.indexedAt)
        case "kind", "type":
            return .string(entry.kind.displayName)
        case "attributes", "attribute", "attrib", "attr":
            return .string(ResultExporter.attributeString(for: entry))
        default:
            return nil
        }
    }

    private static func isQuoted(_ value: String, quote: Character) -> Bool {
        value.count >= 2 && value.first == quote && value.last == quote
    }
}

private enum FormulaValue {
    case string(String)
    case number(Double)
    case date(Date)

    var stringValue: String? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .date:
            return nil
        }
    }

    var numberValue: Double? {
        switch self {
        case let .number(value):
            return value
        case let .string(value):
            return Double(value)
        case .date:
            return nil
        }
    }

    var dateValue: Date? {
        switch self {
        case let .date(value):
            return value
        case .string, .number:
            return nil
        }
    }

    var intValue: Int? {
        guard let numberValue else {
            return nil
        }
        return Int(numberValue)
    }
}

private func unwrapFunction(_ value: String, named name: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix(name.lowercased() + "("),
          trimmed.last == ")" else {
        return nil
    }

    let openIndex = trimmed.index(trimmed.startIndex, offsetBy: name.count)
    let innerStart = trimmed.index(after: openIndex)
    let innerEnd = trimmed.index(before: trimmed.endIndex)
    let inner = String(trimmed[innerStart..<innerEnd])
    return parenthesesAreBalanced(inner) ? inner : nil
}

private func parenthesesAreBalanced(_ value: String) -> Bool {
    var depth = 0
    var quote: Character?

    for character in value {
        if let currentQuote = quote {
            if character == currentQuote {
                quote = nil
            }
            continue
        }

        if character == "'" || character == "\"" {
            quote = character
            continue
        }

        if character == "(" {
            depth += 1
        } else if character == ")" {
            if depth == 0 {
                return false
            }
            depth -= 1
        }
    }

    return depth == 0 && quote == nil
}

private func splitTopLevelArguments(_ value: String) -> [String] {
    var arguments: [String] = []
    var current = ""
    var depth = 0
    var quote: Character?

    for character in value {
        if let currentQuote = quote {
            current.append(character)
            if character == currentQuote {
                quote = nil
            }
            continue
        }

        if character == "'" || character == "\"" {
            quote = character
            current.append(character)
            continue
        }

        if character == "(" || character == "[" {
            depth += 1
            current.append(character)
            continue
        }

        if character == ")" || character == "]" {
            depth = max(0, depth - 1)
            current.append(character)
            continue
        }

        if character == ",", depth == 0 {
            arguments.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
            current = ""
            continue
        }

        current.append(character)
    }

    arguments.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
    return arguments
}

private func topLevelArithmeticRange(of needle: String, in haystack: String) -> Range<String.Index>? {
    var index = haystack.startIndex
    var depth = 0
    var quote: Character?
    var result: Range<String.Index>?

    while index < haystack.endIndex {
        let character = haystack[index]

        if let currentQuote = quote {
            if character == currentQuote {
                quote = nil
            }
            index = haystack.index(after: index)
            continue
        }

        if character == "'" || character == "\"" {
            quote = character
            index = haystack.index(after: index)
            continue
        }

        if character == "(" || character == "[" {
            depth += 1
            index = haystack.index(after: index)
            continue
        }

        if character == ")" || character == "]" {
            depth = max(0, depth - 1)
            index = haystack.index(after: index)
            continue
        }

        if depth == 0, haystack[index...].hasPrefix(needle) {
            let range = index..<haystack.index(index, offsetBy: needle.count)
            if isArithmeticOperatorRange(range, in: haystack) {
                result = range
            }
            index = range.upperBound
            continue
        }

        index = haystack.index(after: index)
    }

    return result
}

private func isArithmeticOperatorRange(_ range: Range<String.Index>, in value: String) -> Bool {
    guard range.lowerBound > value.startIndex,
          range.upperBound < value.endIndex else {
        return false
    }

    let before = value[value.index(before: range.lowerBound)]
    let after = value[range.upperBound]

    if before.isLetter || after.isLetter || before == "$" || after == "$" ||
        after == ":" || before == "-" || before == "+" {
        return false
    }

    return true
}

private func topLevelRange(of needle: String, in haystack: String) -> Range<String.Index>? {
    var index = haystack.startIndex
    var depth = 0
    var quote: Character?

    while index < haystack.endIndex {
        let character = haystack[index]

        if let currentQuote = quote {
            if character == currentQuote {
                quote = nil
            }
            index = haystack.index(after: index)
            continue
        }

        if character == "'" || character == "\"" {
            quote = character
            index = haystack.index(after: index)
            continue
        }

        if character == "(" {
            depth += 1
            index = haystack.index(after: index)
            continue
        }

        if character == ")" {
            depth = max(0, depth - 1)
            index = haystack.index(after: index)
            continue
        }

        if depth == 0, haystack[index...].hasPrefix(needle) {
            return index..<haystack.index(index, offsetBy: needle.count)
        }

        index = haystack.index(after: index)
    }

    return nil
}

private enum SearchQueryParser {
    static func parse(_ rawQuery: String) -> ParsedSearch {
        var parser = ExpressionParser(tokens: tokenize(rawQuery))
        let expression = parser.parse()
        return ParsedSearch(
            expression: expression,
            warnings: parser.warnings,
            limitOverride: parser.limitOverride,
            offsetOverride: parser.offsetOverride,
            sortFieldOverride: parser.sortFieldOverride,
            sortDirectionOverride: parser.sortDirectionOverride
        )
    }

    private enum QueryToken: Equatable {
        case term(String)
        case and
        case or
        case not
        case openParen
        case closeParen
    }

    private struct ExpressionParser {
        let tokens: [QueryToken]
        var index = 0
        var warnings: [String] = []
        var limitOverride: Int?
        var offsetOverride: Int?
        var sortFieldOverride: SearchSortField?
        var sortDirectionOverride: SearchSortDirection?

        mutating func parse() -> SearchExpression? {
            let expression = parseOr()
            while index < tokens.count {
                warnings.append("Unexpected \(display(tokens[index]))")
                index += 1
            }
            return expression
        }

        private mutating func parseOr() -> SearchExpression? {
            var expressions: [SearchExpression] = []
            if let expression = parseAnd() {
                expressions.append(expression)
            }

            while match(.or) {
                guard let expression = parseAnd() else {
                    warnings.append("Missing right side of OR")
                    continue
                }
                expressions.append(expression)
            }

            return combined(expressions, as: .or)
        }

        private mutating func parseAnd() -> SearchExpression? {
            var expressions: [SearchExpression] = []

            while index < tokens.count {
                if peek(.or) || peek(.closeParen) {
                    break
                }

                if match(.and), peek(.or) || peek(.closeParen) || index >= tokens.count {
                    warnings.append("Missing right side of AND")
                    break
                }

                let previousIndex = index
                guard let expression = parseUnary() else {
                    if index > previousIndex {
                        continue
                    }
                    break
                }
                expressions.append(expression)
            }

            return combined(expressions, as: .and)
        }

        private mutating func parseUnary() -> SearchExpression? {
            var isNegated = false
            while match(.not) {
                isNegated.toggle()
            }

            let expression: SearchExpression?
            if case let .term(rawToken)? = current {
                index += 1
                expression = parseTerm(rawToken, isNegated: &isNegated)
            } else if match(.openParen) {
                expression = parseOr()
                if !match(.closeParen) {
                    warnings.append("Missing closing parenthesis")
                }
            } else {
                expression = nil
            }

            guard let expression else {
                return nil
            }
            return isNegated ? .not(expression) : expression
        }

        private mutating func parseTerm(_ rawToken: String, isNegated: inout Bool) -> SearchExpression? {
            var token = rawToken
            while token.hasPrefix("!") || token.hasPrefix("-") {
                isNegated.toggle()
                token.removeFirst()
            }

            guard !token.isEmpty else {
                return nil
            }

            if let countDirective = parseCountDirective(token) {
                if let limit = countDirective.limit {
                    limitOverride = limit
                }
                warnings.append(contentsOf: countDirective.warnings)
                return nil
            }

            if let offsetDirective = parseOffsetDirective(token) {
                if let offset = offsetDirective.offset {
                    offsetOverride = offset
                }
                warnings.append(contentsOf: offsetDirective.warnings)
                return nil
            }

            if let sortDirective = SearchQueryParser.parseSortDirective(token) {
                if let field = sortDirective.field {
                    sortFieldOverride = field
                }
                if let direction = sortDirective.direction {
                    sortDirectionOverride = direction
                }
                warnings.append(contentsOf: sortDirective.warnings)
                return nil
            }

            if let formula = FormulaExpression.parse(token) {
                return SearchExpression.term(SearchTerm(predicate: .formula(formula)))
            }

            if let subexpression = parseFunctionValueSubexpression(token) {
                return subexpression
            }

            let alternatives = functionValueAlternatives(for: token)
            let expressions = alternatives.map { alternative in
                let parsed = parsePredicate(alternative)
                warnings.append(contentsOf: parsed.warnings)
                return SearchExpression.term(SearchTerm(predicate: parsed.predicate))
            }
            return combined(expressions, as: .or)
        }

        private mutating func parseFunctionValueSubexpression(_ token: String) -> SearchExpression? {
            guard let colonIndex = token.firstIndex(of: ":") else {
                return nil
            }

            let rawFunction = token[..<colonIndex]
            let function = canonicalSearchFunctionName(rawFunction)
            guard supportsFunctionValueSubexpression(function: function) else {
                return nil
            }

            let rawValue = token[token.index(after: colonIndex)...]
            guard rawValue.count >= 2,
                  rawValue.first == "<",
                  rawValue.last == ">" else {
                return nil
            }

            let innerStart = rawValue.index(after: rawValue.startIndex)
            let innerEnd = rawValue.index(before: rawValue.endIndex)
            let inner = String(rawValue[innerStart..<innerEnd])
            guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return SearchExpression.term(SearchTerm(predicate: .always))
            }

            let prefixedTokens = SearchQueryParser.tokenize(inner).map { token -> QueryToken in
                switch token {
                case let .term(value):
                    return .term("\(rawFunction):\(value)")
                case .and:
                    return .and
                case .or:
                    return .or
                case .not:
                    return .not
                case .openParen:
                    return .openParen
                case .closeParen:
                    return .closeParen
                }
            }
            var parser = ExpressionParser(tokens: prefixedTokens)
            let expression = parser.parse()
            warnings.append(contentsOf: parser.warnings)
            return expression
        }

        private var current: QueryToken? {
            index < tokens.count ? tokens[index] : nil
        }

        private mutating func match(_ token: QueryToken) -> Bool {
            guard peek(token) else {
                return false
            }
            index += 1
            return true
        }

        private func peek(_ token: QueryToken) -> Bool {
            current == token
        }

        private func combined(
            _ expressions: [SearchExpression],
            as operatorKind: QueryOperator
        ) -> SearchExpression? {
            guard !expressions.isEmpty else {
                return nil
            }
            guard expressions.count > 1 else {
                return expressions[0]
            }
            switch operatorKind {
            case .and:
                return .and(expressions)
            case .or:
                return .or(expressions)
            }
        }

        private func display(_ token: QueryToken) -> String {
            switch token {
            case let .term(value):
                return value
            case .and:
                return "AND"
            case .or:
                return "OR"
            case .not:
                return "!"
            case .openParen:
                return "("
            case .closeParen:
                return ")"
            }
        }
    }

    private enum QueryOperator {
        case and
        case or
    }

    private struct CountDirective {
        let limit: Int?
        let warnings: [String]
    }

    private struct OffsetDirective {
        let offset: Int?
        let warnings: [String]
    }

    private struct SortDirective {
        let field: SearchSortField?
        let direction: SearchSortDirection?
        let warnings: [String]
    }

    private static func parseCountDirective(_ token: String) -> CountDirective? {
        guard let colonIndex = token.firstIndex(of: ":") else {
            return nil
        }

        let function = canonicalSearchFunctionName(token[..<colonIndex])
        guard function == "count" else {
            return nil
        }

        let value = token[token.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let limit = Int(value), limit > 0 else {
            return CountDirective(limit: nil, warnings: ["Could not parse \(token)"])
        }
        return CountDirective(limit: limit, warnings: [])
    }

    private static func parseOffsetDirective(_ token: String) -> OffsetDirective? {
        guard let colonIndex = token.firstIndex(of: ":") else {
            return nil
        }

        let function = canonicalSearchFunctionName(token[..<colonIndex])
        guard ["offset", "skip", "first"].contains(function) else {
            return nil
        }

        let value = token[token.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedValue = Int(value), parsedValue >= 0 else {
            return OffsetDirective(offset: nil, warnings: ["Could not parse \(token)"])
        }

        if function == "first" {
            guard parsedValue > 0 else {
                return OffsetDirective(offset: nil, warnings: ["Could not parse \(token)"])
            }
            return OffsetDirective(offset: parsedValue - 1, warnings: [])
        }

        return OffsetDirective(offset: parsedValue, warnings: [])
    }

    private static func isCountDirective(_ token: String) -> Bool {
        guard let colonIndex = token.firstIndex(of: ":") else {
            return false
        }
        return canonicalSearchFunctionName(token[..<colonIndex]) == "count"
    }

    private static func parseSortDirective(_ token: String) -> SortDirective? {
        guard let colonIndex = token.firstIndex(of: ":") else {
            return nil
        }

        let function = canonicalSearchFunctionName(token[..<colonIndex])
        guard function == "sort" || function == "ascending" || function == "asc" ||
            function == "descending" || function == "desc" else {
            return nil
        }

        let value = token[token.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let explicitDirection: SearchSortDirection?
        switch function {
        case "ascending", "asc":
            explicitDirection = .ascending
        case "descending", "desc":
            explicitDirection = .descending
        default:
            explicitDirection = nil
        }

        guard !value.isEmpty else {
            return SortDirective(field: nil, direction: explicitDirection, warnings: [])
        }

        guard let field = parseSortField(value) else {
            return SortDirective(field: nil, direction: explicitDirection, warnings: ["Could not parse \(token)"])
        }
        return SortDirective(field: field, direction: explicitDirection, warnings: [])
    }

    private static func parseSortField(_ value: String) -> SearchSortField? {
        SearchSortField.parse(value)
    }

    private static func functionValueAlternatives(for token: String) -> [String] {
        guard let colonIndex = token.firstIndex(of: ":") else {
            return [token]
        }

        let rawFunction = token[..<colonIndex]
        let function = canonicalSearchFunctionName(rawFunction)
        guard supportsSemicolonValueList(function: function) else {
            return [token]
        }

        let value = String(token[token.index(after: colonIndex)...])
        let parts = value.split(separator: ";", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count > 1, parts.allSatisfy({ !$0.isEmpty }) else {
            return [token]
        }

        return parts.map { "\(rawFunction):\($0)" }
    }

    private static func supportsSemicolonValueList(function: String) -> Bool {
        supportsSemicolonSearchFunctionValueList(function: function)
    }

    private static func tokenize(_ rawQuery: String) -> [QueryToken] {
        var tokens: [QueryToken] = []
        var current = ""
        var inQuotes = false
        var functionValueAngleDepth = 0
        var index = rawQuery.startIndex

        while index < rawQuery.endIndex {
            if let macro = searchLiteralMacro(at: index, in: rawQuery) {
                appendSearchLiteral(macro.literal, to: &current)
                index = macro.nextIndex
                continue
            }

            let character = rawQuery[index]
            index = rawQuery.index(after: index)

            if character == "\"" {
                inQuotes.toggle()
                continue
            }

            if character == "\\" {
                if index < rawQuery.endIndex {
                    current.append(rawQuery[index])
                    index = rawQuery.index(after: index)
                }
                continue
            }

            if inQuotes, let placeholder = quotedListSeparatorPlaceholder(for: character) {
                current.append(contentsOf: placeholder)
                continue
            }

            if !inQuotes, character == ">", functionValueAngleDepth > 0 {
                functionValueAngleDepth -= 1
                current.append(character)
                continue
            }

            if !inQuotes, functionValueAngleDepth > 0 {
                current.append(character)
                continue
            }

            if !inQuotes, character == "|" {
                if current.contains(":") {
                    current.append(character)
                } else {
                    appendCurrent(&current, to: &tokens)
                    tokens.append(.or)
                }
                continue
            }

            if !inQuotes, character == "(" {
                if shouldKeepOpeningParenthesisInCurrentTerm(current) {
                    current.append(character)
                } else {
                    appendNegationOnlyCurrent(&current, to: &tokens)
                    appendCurrent(&current, to: &tokens)
                    tokens.append(.openParen)
                }
                continue
            }

            if !inQuotes, character == ")" {
                if shouldKeepClosingParenthesisInCurrentTerm(current) {
                    current.append(character)
                } else {
                    appendCurrent(&current, to: &tokens)
                    tokens.append(.closeParen)
                }
                continue
            }

            if !inQuotes, character == "<" {
                if shouldKeepFormulaComparisonOperatorInCurrentTerm(current) {
                    current.append(character)
                    continue
                }
                if shouldKeepOpeningParenthesisInCurrentTerm(current) {
                    functionValueAngleDepth += 1
                    current.append(character)
                } else {
                    appendNegationOnlyCurrent(&current, to: &tokens)
                    appendCurrent(&current, to: &tokens)
                    tokens.append(.openParen)
                }
                continue
            }

            if !inQuotes, character == ">" {
                if shouldKeepFormulaComparisonOperatorInCurrentTerm(current) {
                    current.append(character)
                    continue
                }
                if shouldKeepClosingAngleBracketInCurrentTerm(current) {
                    current.append(character)
                } else {
                    appendCurrent(&current, to: &tokens)
                    tokens.append(.closeParen)
                }
                continue
            }

            if !inQuotes, character.isWhitespace {
                appendCurrent(&current, to: &tokens)
                continue
            }

            current.append(character)
        }

        appendCurrent(&current, to: &tokens)
        return tokens
    }

    private static func appendCurrent(_ current: inout String, to tokens: inout [QueryToken]) {
        guard !current.isEmpty else {
            return
        }
        if current.localizedCaseInsensitiveCompare("OR") == .orderedSame {
            tokens.append(.or)
        } else if current.localizedCaseInsensitiveCompare("AND") == .orderedSame {
            tokens.append(.and)
        } else {
            tokens.append(.term(current))
        }
        current = ""
    }

    private static func appendNegationOnlyCurrent(_ current: inout String, to tokens: inout [QueryToken]) {
        guard !current.isEmpty,
              current.allSatisfy({ $0 == "!" || $0 == "-" }) else {
            return
        }

        if current.count % 2 == 1 {
            tokens.append(.not)
        }
        current = ""
    }

    private static func shouldKeepOpeningParenthesisInCurrentTerm(_ current: String) -> Bool {
        let formulaCurrent = formulaFunctionStem(current)
        if current.contains(":") && !current.allSatisfy({ $0 == "!" || $0 == "-" }) {
            return true
        }

        if isInsideFormulaFunctionTerm(formulaCurrent) {
            return true
        }

        return formulaFunctionNames.contains(formulaCurrent.lowercased())
    }

    private static func shouldKeepClosingParenthesisInCurrentTerm(_ current: String) -> Bool {
        guard current.contains("(") else {
            return false
        }
        if current.contains(":") {
            return true
        }

        return isInsideFormulaFunctionTerm(formulaFunctionStem(current))
    }

    private static func shouldKeepClosingAngleBracketInCurrentTerm(_ current: String) -> Bool {
        guard current.contains(":") else {
            return false
        }
        if current.contains("<") || current.contains("(") {
            return true
        }
        guard current.hasSuffix(":") else {
            return false
        }
        let function = current.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map { canonicalSearchFunctionName($0.trimmingCharacters(in: CharacterSet(charactersIn: "!-"))) }
        switch function {
        case "size", "sz", "dm", "datemodified", "datemodifieddate", "date",
             "dc", "datecreated", "datecreateddate", "da", "dateaccessed",
             "dateaccesseddate", "dr", "daterun", "rc", "recentchange",
             "runcount", "runs", "track", "year", "fsi", "namefrequency", "extensionfrequency",
             "depth", "parents", "parentcount", "chars", "len", "length", "namelen",
             "namelength", "basenamelen", "basenamelength",
             "filenamelen", "filenamelength", "fullpathlen", "fullpathlength",
             "pathandnamelen", "pathandnamelength", "pathnamelen", "pathnamelength",
             "stemlen", "stemlength", "namepartlen",
             "namepartlength", "utf8len", "basenameutf8bytelength",
             "nameleninutf8bytes", "namelengthinutf8bytes",
             "nameutf8bytelength", "filenameleninutf8bytes",
             "filenamelengthinutf8bytes", "fullpathutf8bytelength",
             "fullpathlengthinutf8bytes", "pathlen", "pathlength", "extlen", "extlength",
             "extensionlen", "extensionlength", "pathpartlen", "pathpartlength",
             "locationlen", "locationlength", "childcount", "children", "childfilecount",
             "childfiles", "childfoldercount", "childfolders", "totalchildsize",
             "childda", "childdateaccessed", "childfileda", "childfiledateaccessed",
             "childfolderda", "childfolderdateaccessed", "childdc", "childdatecreated",
             "childfiledc", "childfiledatecreated", "childfolderdc",
             "childfolderdatecreated", "childdm", "childdatemodified", "childfiledm",
             "childfiledatemodified", "childfolderdm", "childfolderdatemodified",
             "childrc", "childdaterecentlychanged", "childfilerc",
             "childfiledaterecentlychanged", "childfolderrc",
             "childfolderdaterecentlychanged", "childdaterun", "childfiledaterun",
             "childfolderdaterun", "childruncount", "childfileruncount",
             "childfolderruncount", "childsize", "childfilesize", "childfoldersize",
             "descendantcount", "descendantfilecount", "descendantfoldercount",
             "parentdatecreated", "parentdc", "parentdatemodified", "parentdm",
             "parentsize",
             "width", "bitdepth",
             "height", "dimension", "dimensions", "aspect-ratio", "aspectratio",
             "siblingcount", "siblingfilecount", "siblingfoldercount":
            return true
        default:
            return false
        }
    }

    private static func shouldKeepFormulaComparisonOperatorInCurrentTerm(_ current: String) -> Bool {
        current.contains("$")
    }

    private static var formulaFunctionNames: Set<String> {
        [
            "upper", "lower", "trim", "len", "exists",
            "abs", "round", "year", "month", "day", "hour", "minute", "second",
            "contains", "startswith", "endswith",
            "left", "right", "mid", "substr", "substring"
        ]
    }

    private static func isInsideFormulaFunctionTerm(_ current: String) -> Bool {
        let lowercased = current.lowercased()
        return formulaFunctionNames.contains { lowercased.hasPrefix($0 + "(") }
    }

    private static func formulaFunctionStem(_ current: String) -> String {
        var value = current
        while value.hasPrefix("!") || value.hasPrefix("-") {
            value.removeFirst()
        }
        return value
    }

    private struct SearchModifierState {
        var optionOverrides = SearchOptionOverrides()
        var kindRestriction: Set<FileKind>?
        var forceRegex: Bool?
        var wildcardsEnabled: Bool?
        var wholeFilename = false

        mutating func restrictKinds(to kinds: Set<FileKind>) {
            if let kindRestriction {
                self.kindRestriction = kindRestriction.intersection(kinds)
            } else {
                self.kindRestriction = kinds
            }
        }
    }

    private static func parsePredicate(_ token: String) -> (predicate: SearchPredicate, warnings: [String]) {
        parsePredicate(token, state: SearchModifierState())
    }

    private static func parsePredicate(
        _ token: String,
        state: SearchModifierState
    ) -> (predicate: SearchPredicate, warnings: [String]) {
        guard let colonIndex = token.firstIndex(of: ":") else {
            return (finalize(plainPredicate(token, state: state), state: state), [])
        }

        let function = canonicalSearchFunctionName(token[..<colonIndex])
        let rawValue = String(token[token.index(after: colonIndex)...])
        let value = unescapeQuotedListSeparators(rawValue)

        if let modified = parseModifier(function: function, value: value, state: state) {
            return modified
        }

        let predicate: SearchPredicate
        let warnings: [String]
        switch function {
        case "ext", "extension":
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                predicate = .noExtension
            } else {
                let extensions = SearchEngine.parseExtensionList(rawValue)
                predicate = extensions.isEmpty ? .always : .extensionList(extensions)
            }
            warnings = []
        case "filelist":
            let values = SearchEngine.parseDelimitedList(rawValue)
            predicate = values.isEmpty ? .always : .fileList(values)
            warnings = []
        case "filelistfilename", "filelistname", "filelistpath":
            let values = SearchEngine.parseDelimitedList(rawValue)
            predicate = .fileListFilename(values)
            warnings = []
        case "frn":
            let values = SearchEngine.parseDelimitedList(rawValue)
            predicate = .fileReferenceNumber(values)
            warnings = []
        case "fsi":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .fileSystemIndex(filter)
            warnings = []
        case "album":
            predicate = .mediaAlbum(value)
            warnings = []
        case "artist":
            predicate = .mediaArtist(value)
            warnings = []
        case "comment":
            predicate = .mediaComment(value)
            warnings = []
        case "genre":
            predicate = .mediaGenre(value)
            warnings = []
        case "title":
            predicate = .mediaTitle(value)
            warnings = []
        case "track":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .mediaTrack(filter)
            warnings = []
        case "year":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .mediaYear(filter)
            warnings = []
        case "pathlist", "fullpathlist":
            let values = SearchEngine.parseDelimitedList(rawValue)
            predicate = values.isEmpty ? .always : .pathList(values)
            warnings = []
        case "fullpath", "pathandname", "pathname",
             "parsefullpath", "parsefilename", "parsepathandname", "parsepathname":
            predicate = value.isEmpty ? .always : .fullPath(value)
            warnings = []
        case "everything", "nop":
            predicate = .always
            warnings = []
        case "nothing":
            predicate = .never(token)
            warnings = []
        case "root":
            let parsed = parseBooleanPredicate(value, truePredicate: .root, falsePredicate: .never(token))
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "shell":
            guard let path = SearchEngine.knownShellFolderPath(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .shellFolder(path)
            warnings = []
        case "size", "sz":
            if let sizePredicate = SearchEngine.parseSizePredicate(value) {
                predicate = sizePredicate
                warnings = []
                break
            }
            guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: SearchEngine.parseByteSize) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .size(filter)
            warnings = []
        case "dm", "datemodified", "datemodifieddate", "date":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .dateModified(filter)
            warnings = []
        case "dc", "datecreated", "datecreateddate":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .dateCreated(filter)
            warnings = []
        case "da", "dateaccessed", "dateaccesseddate":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .dateAccessed(filter)
            warnings = []
        case "dr", "daterun":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .dateRun(filter)
            warnings = []
        case "rc", "recentchange":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .recentChange(filter)
            warnings = []
        case "runcount", "runs":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .runCount(filter)
            warnings = []
        case "namefrequency":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .nameFrequency(filter)
            warnings = []
        case "name", "filename", "basename":
            predicate = .name(value)
            warnings = []
        case "stem", "namepart":
            predicate = .namePart(value)
            warnings = []
        case "exists":
            predicate = value.isEmpty ? .always : .exists(value, nil)
            warnings = []
        case "fileexists":
            predicate = value.isEmpty ? .always : .exists(value, [.file, .symlink, .other])
            warnings = []
        case "folderexists":
            predicate = value.isEmpty ? .always : .exists(value, [.folder, .package])
            warnings = []
        case "pathpart", "pathparts", "pp", "location":
            predicate = value.isEmpty ? .always : .pathPart(value)
            warnings = []
        case "parent", "infolder", "nosubfolders":
            predicate = value.isEmpty ? .always : .parent(value)
            warnings = []
        case let parentPlusFunction where parseParentPlusDepthFunction(parentPlusFunction) != nil:
            guard let depth = parseParentPlusDepthFunction(parentPlusFunction) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = value.isEmpty ? .always : .parentPlusDepth(value, depth)
            warnings = []
        case let parentDepthFunction where parseParentExactDepthFunction(parentDepthFunction) != nil:
            guard let depth = parseParentExactDepthFunction(parentDepthFunction) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = value.isEmpty ? .always : .parentExactDepth(value, depth)
            warnings = []
        case "parentname":
            predicate = value.isEmpty ? .always : .parentName(value)
            warnings = []
        case "parentpath", "parentfullpath":
            predicate = value.isEmpty ? .always : .parentPath(value)
            warnings = []
        case "parentdatecreated", "parentdc":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .parentDateCreated(filter)
            warnings = []
        case "parentdatemodified", "parentdm":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .parentDateModified(filter)
            warnings = []
        case "parentsize":
            guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: SearchEngine.parseByteSize) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .parentSize(filter)
            warnings = []
        case "ancestor":
            predicate = value.isEmpty ? .always : .ancestor(value)
            warnings = []
        case "ancestorname":
            predicate = value.isEmpty ? .always : .ancestorName(value)
            warnings = []
        case "startwith", "startswith", "beginwith", "beginswith", "begin":
            predicate = value.isEmpty ? .always : .startsWith(value)
            warnings = []
        case "endwith", "endswith", "end":
            predicate = value.isEmpty ? .always : .endsWith(value)
            warnings = []
        case "depth", "parents", "parentcount":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .depth(filter)
            warnings = []
        case "chars":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .characterCount(filter)
            warnings = []
        case "len", "length", "namelen", "namelength",
             "basenamelen", "basenamelength":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .nameLength(filter)
            warnings = []
        case "stemlen", "stemlength", "namepartlen", "namepartlength":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .namePartLength(filter)
            warnings = []
        case "utf8len", "basenameutf8bytelength", "nameleninutf8bytes",
             "namelengthinutf8bytes", "nameutf8bytelength",
             "filenameleninutf8bytes", "filenamelengthinutf8bytes":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .nameUTF8Length(filter)
            warnings = []
        case "fullpathutf8bytelength", "fullpathlengthinutf8bytes":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .pathUTF8Length(filter)
            warnings = []
        case "filenamelen", "filenamelength", "fullpathlen", "fullpathlength",
             "pathandnamelen", "pathandnamelength", "pathnamelen", "pathnamelength",
             "pathlen", "pathlength":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .pathLength(filter)
            warnings = []
        case "pathpartlen", "pathpartlength", "locationlen", "locationlength":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .pathPartLength(filter)
            warnings = []
        case "extlen", "extlength", "extensionlen", "extensionlength":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .extensionLength(filter)
            warnings = []
        case "extensionfrequency":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .extensionFrequency(filter)
            warnings = []
        case "childcount", "children":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childCount(filter)
            warnings = []
        case "childfilecount", "childfiles":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childFileCount(filter)
            warnings = []
        case "childfoldercount", "childfolders":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childFolderCount(filter)
            warnings = []
        case "totalchildsize":
            guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: SearchEngine.parseByteSize) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .totalChildSize(filter)
            warnings = []
        case "child", "childname":
            predicate = .child(value, nil)
            warnings = []
        case "childfile", "childfilename", "childfilenames":
            predicate = .child(value, [.file, .symlink, .other])
            warnings = []
        case "childfolder", "childfoldername", "childfoldernames", "childdir", "childdirname", "childdirs", "childdirnames":
            predicate = .child(value, [.folder, .package])
            warnings = []
        case "childattr", "childattrib", "childattribute", "childattributes":
            guard let filter = AttributeFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childAttributes(filter, nil)
            warnings = []
        case "childfileattr", "childfileattrib", "childfileattribute", "childfileattributes":
            guard let filter = AttributeFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childAttributes(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderattr", "childfolderattrib", "childfolderattribute", "childfolderattributes":
            guard let filter = AttributeFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childAttributes(filter, [.folder, .package])
            warnings = []
        case "childda", "childdateaccessed":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateAccessed(filter, nil)
            warnings = []
        case "childfileda", "childfiledateaccessed":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateAccessed(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderda", "childfolderdateaccessed":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateAccessed(filter, [.folder, .package])
            warnings = []
        case "childdc", "childdatecreated":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateCreated(filter, nil)
            warnings = []
        case "childfiledc", "childfiledatecreated":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateCreated(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderdc", "childfolderdatecreated":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateCreated(filter, [.folder, .package])
            warnings = []
        case "childdm", "childdatemodified":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateModified(filter, nil)
            warnings = []
        case "childfiledm", "childfiledatemodified":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateModified(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderdm", "childfolderdatemodified":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateModified(filter, [.folder, .package])
            warnings = []
        case "childrc", "childdaterecentlychanged":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childRecentChange(filter, nil)
            warnings = []
        case "childfilerc", "childfiledaterecentlychanged":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childRecentChange(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderrc", "childfolderdaterecentlychanged":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childRecentChange(filter, [.folder, .package])
            warnings = []
        case "childdaterun":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateRun(filter, nil)
            warnings = []
        case "childfiledaterun":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateRun(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderdaterun":
            guard let filter = DateFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childDateRun(filter, [.folder, .package])
            warnings = []
        case "childruncount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childRunCount(filter, nil)
            warnings = []
        case "childfileruncount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childRunCount(filter, [.file, .symlink, .other])
            warnings = []
        case "childfolderruncount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childRunCount(filter, [.folder, .package])
            warnings = []
        case "childsize":
            guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: SearchEngine.parseByteSize) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childSize(filter, nil)
            warnings = []
        case "childfilesize":
            guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: SearchEngine.parseByteSize) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childSize(filter, [.file, .symlink, .other])
            warnings = []
        case "childfoldersize":
            guard let filter = ComparisonFilter<Int64>.parse(value, valueParser: SearchEngine.parseByteSize) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .childSize(filter, [.folder, .package])
            warnings = []
        case "childfilelist":
            let values = SearchEngine.parseDelimitedList(rawValue)
            predicate = values.isEmpty ? .always : .childFileList(values)
            warnings = []
        case "descendant", "descendantname":
            predicate = .descendant(value, nil)
            warnings = []
        case "descendantfile", "descendantfilename", "descendantfilenames":
            predicate = .descendant(value, [.file, .symlink, .other])
            warnings = []
        case "descendantfolder", "descendantfoldername", "descendantfoldernames", "descendantdir", "descendantdirname", "descendantdirs", "descendantdirnames":
            predicate = .descendant(value, [.folder, .package])
            warnings = []
        case "descendantcount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .descendantCount(filter, nil)
            warnings = []
        case "descendantfilecount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .descendantCount(filter, [.file, .symlink, .other])
            warnings = []
        case "descendantfoldercount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .descendantCount(filter, [.folder, .package])
            warnings = []
        case "ancestorattr", "ancestorattrib", "ancestorattribute", "ancestorattributes":
            guard let filter = AttributeFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .ancestorAttributes(filter)
            warnings = []
        case "ancestorchild":
            predicate = .ancestorChild(value, nil)
            warnings = []
        case "ancestorchildfile":
            predicate = .ancestorChild(value, [.file, .symlink, .other])
            warnings = []
        case "ancestorchildfolder":
            predicate = .ancestorChild(value, [.folder, .package])
            warnings = []
        case "parentchild", "parentchildname":
            predicate = .parentChild(value, nil)
            warnings = []
        case "parentchildfile", "parentchildfilename":
            predicate = .parentChild(value, [.file, .symlink, .other])
            warnings = []
        case "parentchildfolder", "parentchildfoldername", "parentchilddir", "parentchilddirname":
            predicate = .parentChild(value, [.folder, .package])
            warnings = []
        case "sibling", "siblingname":
            predicate = .sibling(value, nil)
            warnings = []
        case "siblingfile", "siblingfiles":
            predicate = .sibling(value, [.file, .symlink, .other])
            warnings = []
        case "siblingfolder", "siblingfolders", "siblingdir", "siblingdirs":
            predicate = .sibling(value, [.folder, .package])
            warnings = []
        case "siblingcount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .siblingCount(filter)
            warnings = []
        case "siblingfilecount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .siblingFileCount(filter)
            warnings = []
        case "siblingfoldercount":
            guard let filter = ComparisonFilter<Int>.parse(value.isEmpty ? ">0" : value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .siblingFolderCount(filter)
            warnings = []
        case "parentsibling", "parentsiblingname":
            predicate = .parentSibling(value, nil)
            warnings = []
        case "parentsiblingfile", "parentsiblingfilename":
            predicate = .parentSibling(value, [.file, .symlink, .other])
            warnings = []
        case "parentsiblingfolder", "parentsiblingfoldername", "parentsiblingdir", "parentsiblingdirname":
            predicate = .parentSibling(value, [.folder, .package])
            warnings = []
        case "ancestorsibling", "ancestorsiblingname":
            predicate = .ancestorSibling(value, nil)
            warnings = []
        case "ancestorsiblingfile", "ancestorsiblingfilename":
            predicate = .ancestorSibling(value, [.file, .symlink, .other])
            warnings = []
        case "ancestorsiblingfolder", "ancestorsiblingfoldername", "ancestorsiblingdir", "ancestorsiblingdirname":
            predicate = .ancestorSibling(value, [.folder, .package])
            warnings = []
        case "width":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .imageWidth(filter)
            warnings = []
        case "height":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .imageHeight(filter)
            warnings = []
        case "bitdepth":
            guard let filter = ComparisonFilter<Int>.parse(value, valueParser: { Int($0) }) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .imageBitDepth(filter)
            warnings = []
        case "dimension", "dimensions":
            guard let filter = DimensionsFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .imageDimensions(filter)
            warnings = []
        case "orientation":
            guard let filter = ImageOrientationFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .imageOrientation(filter)
            warnings = []
        case "aspect-ratio", "aspectratio":
            guard let filter = AspectRatioFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .imageAspectRatio(filter)
            warnings = []
        case "empty":
            let parsed = parseBooleanPredicate(value, truePredicate: .empty, falsePredicate: .notEmpty)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "dupe", "dupename":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateName, falsePredicate: .uniqueName)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "namepartdupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateNamePart, falsePredicate: .uniqueNamePart)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "pathdupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicatePathPart, falsePredicate: .uniquePathPart)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "sizedupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateSize, falsePredicate: .uniqueSize)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "dcdupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateCreatedDate, falsePredicate: .uniqueCreatedDate)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "dmdupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateModifiedDate, falsePredicate: .uniqueModifiedDate)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "dadupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateAccessedDate, falsePredicate: .uniqueAccessedDate)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "attribdupe", "attrdupe":
            let parsed = parseBooleanPredicate(value, truePredicate: .duplicateAttributes, falsePredicate: .uniqueAttributes)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "type", "kind", "category":
            guard let category = FileCategory.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .category(category)
            warnings = []
        case "image", "images", "pic", "pics", "picture", "pictures", "photo", "photos":
            let parsed = parseCategoryShortcut(token: token, value: value, category: .image)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "audio", "audios", "music":
            let parsed = parseCategoryShortcut(token: token, value: value, category: .audio)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "video", "videos", "movie", "movies":
            let parsed = parseCategoryShortcut(token: token, value: value, category: .video)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "doc", "docs", "document", "documents":
            let parsed = parseCategoryShortcut(token: token, value: value, category: .document)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "zip", "zips", "compressed", "compress", "archive", "archives":
            let parsed = parseCategoryShortcut(token: token, value: value, category: .compressed)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "exe", "exec", "executable", "executables", "app", "apps", "application", "applications":
            let parsed = parseCategoryShortcut(token: token, value: value, category: .executable)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "attrib", "attr", "attribute", "attributes":
            guard let filter = AttributeFilter.parse(value) else {
                return (finalize(.never(token), state: state), ["Could not parse \(token)"])
            }
            predicate = .attributes(filter)
            warnings = []
        case "hidden":
            let parsed = parseAttributeBooleanPredicate(value, attribute: .hidden)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "readonly", "read-only":
            let parsed = parseAttributeBooleanPredicate(value, attribute: .readonly)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "system":
            let parsed = parseAttributeBooleanPredicate(value, attribute: .system)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "symlink", "link":
            let parsed = parseAttributeBooleanPredicate(value, attribute: .symlink)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "package":
            let parsed = parseAttributeBooleanPredicate(value, attribute: .package)
            return (finalize(parsed.predicate, state: state), parsed.warnings)
        case "content":
            predicate = value.isEmpty ? .always : .content(value, nil)
            warnings = []
        case "ansicontent":
            predicate = value.isEmpty ? .always : .content(value, .ansi)
            warnings = []
        case "utf8content":
            predicate = value.isEmpty ? .always : .content(value, .utf8)
            warnings = []
        case "utf16content":
            predicate = value.isEmpty ? .always : .content(value, .utf16LittleEndian)
            warnings = []
        case "utf16becontent":
            predicate = value.isEmpty ? .always : .content(value, .utf16BigEndian)
            warnings = []
        default:
            predicate = plainPredicate(token, state: state)
            warnings = []
        }

        return (finalize(predicate, state: state), warnings)
    }

    private static func parseModifier(
        function: String,
        value: String,
        state: SearchModifierState
    ) -> (predicate: SearchPredicate, warnings: [String])? {
        var next = state

        switch function {
        case "ascii", "utf8", "noascii":
            break
        case "case":
            next.optionOverrides.caseSensitive = true
        case "nocase":
            next.optionOverrides.caseSensitive = false
        case "diacritics":
            next.optionOverrides.diacriticSensitive = true
        case "nodiacritics":
            next.optionOverrides.diacriticSensitive = false
        case "path":
            next.optionOverrides.matchPath = true
        case "nopath":
            next.optionOverrides.matchPath = false
        case "wholeword", "ww":
            next.optionOverrides.wholeWordMatching = true
        case "nowholeword", "noww":
            next.optionOverrides.wholeWordMatching = false
        case "regex":
            guard !value.isEmpty else {
                return (finalize(.always, state: state), [])
            }
            next.forceRegex = true
            next.optionOverrides.regexMatching = true
        case "noregex":
            next.forceRegex = false
            next.optionOverrides.regexMatching = false
        case "wildcards":
            next.wildcardsEnabled = true
        case "nowildcards":
            next.wildcardsEnabled = false
        case "wfn", "wholefilename", "exact":
            next.wholeFilename = true
        case "nowfn", "nowholefilename":
            next.wholeFilename = false
        case "file", "files":
            if value.isEmpty {
                return (finalize(.kind([.file, .symlink, .package]), state: state), [])
            }
            next.restrictKinds(to: [.file, .symlink, .package])
        case "folder", "folders", "dir", "dirs":
            if value.isEmpty {
                return (finalize(.kind([.folder]), state: state), [])
            }
            next.restrictKinds(to: [.folder])
        case "nofileonly", "nofolderonly":
            break
        default:
            return nil
        }

        guard !value.isEmpty else {
            return (finalize(.always, state: state), [])
        }
        return parsePredicate(value, state: next)
    }

    private static func plainPredicate(_ token: String, state: SearchModifierState) -> SearchPredicate {
        let value = unescapeQuotedListSeparators(token)
        if state.forceRegex == true {
            return .regex(value)
        }
        if state.wholeFilename {
            return .wholeFilename(value)
        }
        if state.wildcardsEnabled != false, value.contains("*") || value.contains("?") {
            return .wildcard(value)
        }
        return .text(value)
    }

    private static func finalize(_ predicate: SearchPredicate, state: SearchModifierState) -> SearchPredicate {
        let scoped = state.optionOverrides.isEmpty
            ? predicate
            : SearchPredicate.withOptions(state.optionOverrides, predicate)

        guard let kindRestriction = state.kindRestriction else {
            return scoped
        }
        return .and([.kind(kindRestriction), scoped])
    }

    private static func parseCategoryShortcut(
        token: String,
        value: String,
        category: FileCategory
    ) -> (predicate: SearchPredicate, warnings: [String]) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (.category(category), [])
        }
        return (.never(token), ["Could not parse \(token)"])
    }

    private static func parseBooleanPredicate(
        _ value: String,
        truePredicate: SearchPredicate,
        falsePredicate: SearchPredicate
    ) -> (predicate: SearchPredicate, warnings: [String]) {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "1", "true", "yes", "on":
            return (truePredicate, [])
        case "0", "false", "no", "off":
            return (falsePredicate, [])
        default:
            return (truePredicate, [])
        }
    }

    private static func parseAttributeBooleanPredicate(
        _ value: String,
        attribute: FileAttributes
    ) -> (predicate: SearchPredicate, warnings: [String]) {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "1", "true", "yes", "on":
            return (.attributes(AttributeFilter(required: attribute, excluded: [])), [])
        case "0", "false", "no", "off":
            return (.attributes(AttributeFilter(required: [], excluded: attribute)), [])
        default:
            return (.attributes(AttributeFilter(required: attribute, excluded: [])), [])
        }
    }

}

private enum ComparisonOperator {
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual

    var candidateOperator: SearchCandidateComparisonOperator {
        switch self {
        case .equal:
            return .equal
        case .notEqual:
            return .notEqual
        case .lessThan:
            return .lessThan
        case .lessThanOrEqual:
            return .lessThanOrEqual
        case .greaterThan:
            return .greaterThan
        case .greaterThanOrEqual:
            return .greaterThanOrEqual
        }
    }
}

private struct ImageDimensions: Comparable {
    let width: Int
    let height: Int

    var aspectRatio: Double {
        Double(width) / Double(height)
    }

    static func < (lhs: ImageDimensions, rhs: ImageDimensions) -> Bool {
        if lhs.width == rhs.width {
            return lhs.height < rhs.height
        }
        return lhs.width < rhs.width
    }
}

private struct DimensionsFilter {
    private enum Kind {
        case exact(ImageDimensions)
        case range(lower: ImageDimensions?, upper: ImageDimensions?)
    }

    private let kind: Kind

    func matches(_ candidate: ImageDimensions) -> Bool {
        switch kind {
        case let .exact(dimensions):
            return candidate == dimensions
        case let .range(lower, upper):
            if let lower, candidate.width < lower.width || candidate.height < lower.height {
                return false
            }
            if let upper, candidate.width > upper.width || candidate.height > upper.height {
                return false
            }
            return true
        }
    }

    static func parse(_ rawValue: String) -> DimensionsFilter? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = value.range(of: "..") {
            let lowerText = value[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let upperText = value[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = lowerText.isEmpty ? nil : parseDimensions(String(lowerText))
            let upper = upperText.isEmpty ? nil : parseDimensions(String(upperText))
            if (!lowerText.isEmpty && lower == nil) || (!upperText.isEmpty && upper == nil) {
                return nil
            }
            guard lower != nil || upper != nil else {
                return nil
            }
            return DimensionsFilter(kind: .range(lower: lower, upper: upper))
        }

        guard let dimensions = parseDimensions(value) else {
            return nil
        }
        return DimensionsFilter(kind: .exact(dimensions))
    }

    private static func parseDimensions(_ value: String) -> ImageDimensions? {
        let parts = value.split(whereSeparator: { $0 == "x" || $0 == "X" })
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]),
              width > 0,
              height > 0 else {
            return nil
        }
        return ImageDimensions(width: width, height: height)
    }
}

private enum ImageOrientationFilter {
    case landscape
    case portrait
    case square

    func matches(_ dimensions: ImageDimensions) -> Bool {
        switch self {
        case .landscape:
            return dimensions.width > dimensions.height
        case .portrait:
            return dimensions.height > dimensions.width
        case .square:
            return dimensions.width == dimensions.height
        }
    }

    static func parse(_ value: String) -> ImageOrientationFilter? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "landscape", "wide":
            return .landscape
        case "portrait", "tall":
            return .portrait
        case "square":
            return .square
        default:
            return nil
        }
    }
}

private struct AspectRatioFilter {
    private enum Kind {
        case orientation(ImageOrientationFilter)
        case comparison(ComparisonOperator, Double)
        case range(lower: Double?, upper: Double?)
    }

    private let kind: Kind

    func matches(_ dimensions: ImageDimensions) -> Bool {
        switch kind {
        case let .orientation(filter):
            return filter.matches(dimensions)
        case let .comparison(op, value):
            return compare(dimensions.aspectRatio, op: op, value: value)
        case let .range(lower, upper):
            let ratio = dimensions.aspectRatio
            if let lower, ratio < lower && !isNearlyEqual(ratio, lower) {
                return false
            }
            if let upper, ratio > upper && !isNearlyEqual(ratio, upper) {
                return false
            }
            return true
        }
    }

    static func parse(_ rawValue: String) -> AspectRatioFilter? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let orientation = ImageOrientationFilter.parse(value) {
            return AspectRatioFilter(kind: .orientation(orientation))
        }

        if let range = parseRange(value) {
            return range
        }

        let pairs: [(String, ComparisonOperator)] = [
            ("!=", .notEqual),
            ("==", .equal),
            (">=", .greaterThanOrEqual),
            ("<=", .lessThanOrEqual),
            ("!", .notEqual),
            (">", .greaterThan),
            ("<", .lessThan),
            ("=", .equal)
        ]

        for (prefix, op) in pairs where value.hasPrefix(prefix) {
            let valueString = String(value.dropFirst(prefix.count))
            guard let ratio = parseRatio(valueString) else {
                return nil
            }
            return AspectRatioFilter(kind: .comparison(op, ratio))
        }

        guard let ratio = parseRatio(value) else {
            return nil
        }
        return AspectRatioFilter(kind: .comparison(.equal, ratio))
    }

    private func compare(_ ratio: Double, op: ComparisonOperator, value: Double) -> Bool {
        switch op {
        case .equal:
            return isNearlyEqual(ratio, value)
        case .notEqual:
            return !isNearlyEqual(ratio, value)
        case .lessThan:
            return ratio < value && !isNearlyEqual(ratio, value)
        case .lessThanOrEqual:
            return ratio < value || isNearlyEqual(ratio, value)
        case .greaterThan:
            return ratio > value && !isNearlyEqual(ratio, value)
        case .greaterThanOrEqual:
            return ratio > value || isNearlyEqual(ratio, value)
        }
    }

    private static func parseRange(_ value: String) -> AspectRatioFilter? {
        guard let range = value.range(of: "..") else {
            return nil
        }

        let lowerText = value[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let upperText = value[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        var lower = lowerText.isEmpty ? nil : parseRatio(String(lowerText))
        var upper = upperText.isEmpty ? nil : parseRatio(String(upperText))

        if (!lowerText.isEmpty && lower == nil) || (!upperText.isEmpty && upper == nil) {
            return nil
        }
        guard lower != nil || upper != nil else {
            return nil
        }

        if let lowerValue = lower, let upperValue = upper, lowerValue > upperValue {
            lower = upperValue
            upper = lowerValue
        }

        return AspectRatioFilter(kind: .range(lower: lower, upper: upper))
    }

    private static func parseRatio(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators: [Character] = [":", "/"]
        if let separatorIndex = trimmed.firstIndex(where: { separators.contains($0) }) {
            let numeratorText = trimmed[..<separatorIndex]
            let denominatorText = trimmed[trimmed.index(after: separatorIndex)...]
            guard let numerator = Double(numeratorText),
                  let denominator = Double(denominatorText),
                  numerator > 0,
                  denominator > 0 else {
                return nil
            }
            return numerator / denominator
        }

        guard let ratio = Double(trimmed), ratio > 0 else {
            return nil
        }
        return ratio
    }

    private func isNearlyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= max(0.000_001, abs(rhs) * 0.000_001)
    }
}

private enum FileCategory {
    case file
    case folder
    case package
    case symlink
    case image
    case audio
    case video
    case document
    case compressed
    case executable

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg"
    ]
    private static let audioExtensions: Set<String> = [
        "mp3", "m4a", "wav", "aiff", "flac", "ogg"
    ]
    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "avi", "webm"
    ]
    private static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "pages", "txt", "md", "rtf", "xls", "xlsx", "csv", "ppt", "pptx"
    ]
    private static let compressedExtensions: Set<String> = [
        "zip", "7z", "rar", "tar", "gz", "tgz", "bz2", "xz", "lz", "lzma", "zst", "cab", "iso"
    ]
    private static let executableExtensions: Set<String> = [
        "app", "command", "tool", "sh", "bash", "zsh", "fish", "py", "rb", "pl", "js", "jar",
        "exe", "com", "bat", "cmd", "msi", "pkg"
    ]

    var candidateExtensions: Set<String> {
        switch self {
        case .image:
            return Self.imageExtensions
        case .audio:
            return Self.audioExtensions
        case .video:
            return Self.videoExtensions
        case .document:
            return Self.documentExtensions
        case .compressed:
            return Self.compressedExtensions
        case .executable:
            return Self.executableExtensions
        case .file, .folder, .package, .symlink:
            return []
        }
    }

    var candidateKinds: Set<FileKind> {
        switch self {
        case .file:
            return [.file, .symlink, .package]
        case .folder:
            return [.folder]
        case .package:
            return [.package]
        case .symlink:
            return [.symlink]
        case .image, .audio, .video, .document, .compressed:
            return [.file]
        case .executable:
            return [.file, .package]
        }
    }

    static func parse(_ rawValue: String) -> FileCategory? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "file", "files":
            return .file
        case "folder", "folders", "dir", "dirs", "directory", "directories":
            return .folder
        case "package", "packages":
            return .package
        case "link", "links", "symlink", "symlinks":
            return .symlink
        case "image", "images", "pic", "pics", "picture", "pictures", "photo", "photos":
            return .image
        case "audio", "music":
            return .audio
        case "video", "videos", "movie", "movies":
            return .video
        case "doc", "docs", "document", "documents":
            return .document
        case "zip", "zips", "compressed", "compress", "archive", "archives":
            return .compressed
        case "exe", "exec", "executable", "executables", "app", "apps", "application", "applications":
            return .executable
        default:
            return nil
        }
    }

    func matches(_ entry: FileEntry) -> Bool {
        switch self {
        case .file:
            return [.file, .symlink, .package].contains(entry.kind)
        case .folder:
            return entry.kind == .folder
        case .package:
            return entry.kind == .package || entry.attributes.contains(.package)
        case .symlink:
            return entry.kind == .symlink || entry.attributes.contains(.symlink)
        case .image:
            return entry.kind == .file && Self.imageExtensions.contains(entry.extensionName.lowercased())
        case .audio:
            return entry.kind == .file && Self.audioExtensions.contains(entry.extensionName.lowercased())
        case .video:
            return entry.kind == .file && Self.videoExtensions.contains(entry.extensionName.lowercased())
        case .document:
            return entry.kind == .file && Self.documentExtensions.contains(entry.extensionName.lowercased())
        case .compressed:
            return entry.kind == .file && Self.compressedExtensions.contains(entry.extensionName.lowercased())
        case .executable:
            if entry.kind == .package || entry.attributes.contains(.package) {
                return true
            }
            return entry.kind == .file && Self.executableExtensions.contains(entry.extensionName.lowercased())
        }
    }
}

private struct AttributeFilter {
    let required: FileAttributes
    let excluded: FileAttributes

    func matches(_ attributes: FileAttributes) -> Bool {
        attributes.isSuperset(of: required) && attributes.intersection(excluded).isEmpty
    }

    static func parse(_ rawValue: String) -> AttributeFilter? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        var required: FileAttributes = []
        var excluded: FileAttributes = []
        var isExcluding = false

        for character in value {
            if character == "!" || character == "-" {
                isExcluding = true
                continue
            }

            if character == "," || character == ";" || character == "|" || character.isWhitespace {
                isExcluding = false
                continue
            }

            guard let attribute = attribute(for: character) else {
                return nil
            }

            if isExcluding {
                excluded.insert(attribute)
            } else {
                required.insert(attribute)
            }
        }

        guard !required.isEmpty || !excluded.isEmpty else {
            return nil
        }

        return AttributeFilter(required: required, excluded: excluded)
    }

    private static func attribute(for character: Character) -> FileAttributes? {
        switch character.uppercased() {
        case "A":
            return .archive
        case "C":
            return .compressed
        case "D":
            return .directory
        case "E":
            return .encrypted
        case "F":
            return .file
        case "H":
            return .hidden
        case "I":
            return .notContentIndexed
        case "L":
            return .symlink
        case "N":
            return .normal
        case "O":
            return .offline
        case "P":
            return .sparse
        case "R":
            return .readonly
        case "S":
            return .system
        case "T":
            return .temporary
        default:
            return nil
        }
    }
}

private struct ComparisonFilter<Value: Comparable> {
    private enum Kind {
        case comparison(ComparisonOperator, Value)
        case range(lower: Value?, upper: Value?)
    }

    private let kind: Kind

    static func comparison(_ op: ComparisonOperator, _ value: Value) -> ComparisonFilter<Value> {
        ComparisonFilter(kind: .comparison(op, value))
    }

    static func range(lower: Value?, upper: Value?) -> ComparisonFilter<Value> {
        ComparisonFilter(kind: .range(lower: lower, upper: upper))
    }

    func matches(_ candidate: Value) -> Bool {
        switch kind {
        case let .comparison(op, value):
            return compare(candidate, op: op, value: value)
        case let .range(lower, upper):
            if let lower, candidate < lower {
                return false
            }
            if let upper, candidate > upper {
                return false
            }
            return true
        }
    }

    func comparisons() -> [(ComparisonOperator, Value)] {
        switch kind {
        case let .comparison(op, value):
            return [(op, value)]
        case let .range(lower, upper):
            var comparisons: [(ComparisonOperator, Value)] = []
            if let lower {
                comparisons.append((.greaterThanOrEqual, lower))
            }
            if let upper {
                comparisons.append((.lessThanOrEqual, upper))
            }
            return comparisons
        }
    }

    func candidateFilters(field: SearchCandidateNumericField) -> [SearchCandidateNumericFilter] where Value == Int64 {
        comparisons().map { op, value in
            let candidateOperator = op.candidateOperator
            return SearchCandidateNumericFilter(
                field: field,
                op: candidateOperator,
                value: value
            )
        }
    }

    private func compare(_ candidate: Value, op: ComparisonOperator, value: Value) -> Bool {
        switch op {
        case .equal:
            return candidate == value
        case .notEqual:
            return candidate != value
        case .lessThan:
            return candidate < value
        case .lessThanOrEqual:
            return candidate <= value
        case .greaterThan:
            return candidate > value
        case .greaterThanOrEqual:
            return candidate >= value
        }
    }

    static func parse(_ rawValue: String, valueParser: (String) -> Value?) -> ComparisonFilter<Value>? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = parseRange(trimmed, valueParser: valueParser) {
            return range
        }

        let pairs: [(String, ComparisonOperator)] = [
            ("!=", .notEqual),
            ("==", .equal),
            (">=", .greaterThanOrEqual),
            ("<=", .lessThanOrEqual),
            ("!", .notEqual),
            (">", .greaterThan),
            ("<", .lessThan),
            ("=", .equal)
        ]

        for (prefix, op) in pairs where trimmed.hasPrefix(prefix) {
            let valueString = String(trimmed.dropFirst(prefix.count))
            guard let value = valueParser(valueString) else {
                return nil
            }
            return ComparisonFilter(kind: .comparison(op, value))
        }

        guard let value = valueParser(trimmed) else {
            return nil
        }
        return ComparisonFilter(kind: .comparison(.equal, value))
    }

    private static func parseRange(
        _ value: String,
        valueParser: (String) -> Value?
    ) -> ComparisonFilter<Value>? {
        guard let range = value.range(of: "..") else {
            return nil
        }

        let lowerText = value[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let upperText = value[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = lowerText.isEmpty ? nil : valueParser(String(lowerText))
        let upper = upperText.isEmpty ? nil : valueParser(String(upperText))

        if (!lowerText.isEmpty && lower == nil) || (!upperText.isEmpty && upper == nil) {
            return nil
        }
        guard lower != nil || upper != nil else {
            return nil
        }

        return ComparisonFilter(kind: .range(lower: lower, upper: upper))
    }
}

private struct DateWildcardFilter {
    private let pattern: String

    func matches(_ date: Date) -> Bool {
        formattedCandidates(for: date).contains { candidate in
            wildcardMatch(pattern: pattern, candidate: candidate)
        }
    }

    static func parse(_ value: String) -> DateWildcardFilter? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("*") || trimmed.contains("?") else {
            return nil
        }
        return DateWildcardFilter(pattern: trimmed)
    }

    private func formattedCandidates(for date: Date) -> [String] {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy-MM",
            "yyyy",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd'T'HHmm",
            "yyyyMMddHHmmss",
            "yyyyMMddHHmm",
            "yyyyMMdd",
            "yyyyMM",
            "MM/dd/yyyy",
            "MM-dd-yyyy"
        ]
        return formats.map {
            let formatter = makeFormatter($0)
            return formatter.string(from: date).lowercased()
        }
    }

    private func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private func wildcardMatch(pattern: String, candidate: String) -> Bool {
        let regex = "^" + pattern.reduce(into: "") { partialResult, character in
            switch character {
            case "*":
                partialResult += ".*"
            case "?":
                partialResult += "."
            default:
                partialResult += NSRegularExpression.escapedPattern(for: String(character))
            }
        } + "$"

        do {
            let expression = try NSRegularExpression(pattern: regex)
            let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            return expression.firstMatch(in: candidate, range: range) != nil
        } catch {
            return false
        }
    }
}

private struct DateFilter {
    let start: Date?
    let end: Date?
    let comparison: ComparisonFilter<Date>?
    let wildcard: DateWildcardFilter?
    let matchUnknown: Bool

    init(
        start: Date?,
        end: Date?,
        comparison: ComparisonFilter<Date>?,
        wildcard: DateWildcardFilter? = nil,
        matchUnknown: Bool = false
    ) {
        self.start = start
        self.end = end
        self.comparison = comparison
        self.wildcard = wildcard
        self.matchUnknown = matchUnknown
    }

    func matches(_ candidate: Date?) -> Bool {
        guard let candidate else {
            return matchUnknown
        }
        return matches(candidate)
    }

    func matches(_ candidate: Date) -> Bool {
        if matchUnknown {
            return false
        }

        if let wildcard {
            return wildcard.matches(candidate)
        }

        if let comparison {
            return comparison.matches(candidate)
        }

        if let start, candidate < start {
            return false
        }

        if let end, candidate >= end {
            return false
        }

        return true
    }

    func candidateFilters(field: SearchCandidateDateField) -> [SearchCandidateDateFilter] {
        if wildcard != nil || matchUnknown {
            return []
        }

        if let comparison {
            return comparison.comparisons().map { op, value in
                let candidateOperator = op.candidateOperator
                return SearchCandidateDateFilter(
                    field: field,
                    op: candidateOperator,
                    value: value
                )
            }
        }

        var filters: [SearchCandidateDateFilter] = []
        if let start {
            filters.append(SearchCandidateDateFilter(field: field, op: .greaterThanOrEqual, value: start))
        }
        if let end {
            filters.append(SearchCandidateDateFilter(field: field, op: .lessThan, value: end))
        }
        return filters
    }

    static func parse(_ rawValue: String) -> DateFilter? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let calendar = Calendar.current
        let now = Date()

        switch value {
        case "today":
            let start = calendar.startOfDay(for: now)
            return DateFilter(start: start, end: calendar.date(byAdding: .day, value: 1, to: start), comparison: nil)
        case "yesterday":
            guard let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
                return nil
            }
            return DateFilter(start: start, end: calendar.startOfDay(for: now), comparison: nil)
        case "unknown":
            return DateFilter(start: nil, end: nil, comparison: nil, matchUnknown: true)
        case "thisweek", "currentweek":
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "lastweek", "pastweek", "prevweek", "previousweek":
            guard let interval = previousInterval(of: .weekOfYear, for: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "comingweek", "nextweek":
            guard let interval = nextInterval(of: .weekOfYear, for: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "thismonth", "currentmonth":
            guard let interval = calendar.dateInterval(of: .month, for: now) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "lastmonth", "pastmonth", "prevmonth", "previousmonth":
            guard let interval = previousInterval(of: .month, for: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "comingmonth", "nextmonth":
            guard let interval = nextInterval(of: .month, for: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "thisyear", "currentyear":
            guard let interval = calendar.dateInterval(of: .year, for: now) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "lastyear", "pastyear", "prevyear", "previousyear":
            guard let interval = previousInterval(of: .year, for: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "comingyear", "nextyear":
            guard let interval = nextInterval(of: .year, for: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "thisquarter", "currentquarter", "thisqtr", "currentqtr":
            guard let interval = quarterInterval(containing: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "lastquarter", "lastqtr", "pastquarter", "pastqtr", "prevquarter", "previousquarter":
            guard let interval = previousQuarterInterval(containing: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "comingquarter", "comingqtr", "nextquarter", "nextqtr":
            guard let interval = nextQuarterInterval(containing: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        case "mtd":
            guard let interval = calendar.dateInterval(of: .month, for: now) else {
                return nil
            }
            return DateFilter(start: interval.start, end: now, comparison: nil)
        case "ytd":
            guard let interval = calendar.dateInterval(of: .year, for: now) else {
                return nil
            }
            return DateFilter(start: interval.start, end: now, comparison: nil)
        case "qtd":
            guard let interval = quarterInterval(containing: now, calendar: calendar) else {
                return nil
            }
            return DateFilter(start: interval.start, end: now, comparison: nil)
        default:
            break
        }

        if let interval = monthNameInterval(value, now: now, calendar: calendar) {
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        }

        if let interval = weekdayNameInterval(value, now: now, calendar: calendar) {
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        }

        if let wildcard = DateWildcardFilter.parse(value) {
            return DateFilter(start: nil, end: nil, comparison: nil, wildcard: wildcard)
        }

        if let interval = parseRelativeDateInterval(value, now: now, calendar: calendar) {
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        }

        if let interval = parseAbsoluteDateInterval(value, calendar: calendar) {
            return DateFilter(start: interval.start, end: interval.end, comparison: nil)
        }

        if let comparison = ComparisonFilter<Date>.parse(value, valueParser: parseComparisonDate) {
            return DateFilter(start: nil, end: nil, comparison: comparison)
        }

        return nil
    }

    private static func parseRelativeDateInterval(_ value: String, now: Date, calendar: Calendar) -> DateInterval? {
        enum Direction {
            case past
            case future
        }

        let prefixes: [(String, Direction)] = [
            ("previous", .past),
            ("coming", .future),
            ("last", .past),
            ("past", .past),
            ("prev", .past),
            ("next", .future)
        ]

        var remaining = Substring(value)
        var direction = Direction.past
        for (prefix, parsedDirection) in prefixes where value.hasPrefix(prefix) {
            remaining = value.dropFirst(prefix.count)
            direction = parsedDirection
            break
        }

        guard !remaining.isEmpty else {
            return nil
        }

        let numberString = remaining.prefix(while: \.isNumber)
        let unit = remaining.dropFirst(numberString.count)
        let amount: Int
        if numberString.isEmpty {
            amount = 1
        } else if let parsedAmount = Int(numberString) {
            amount = parsedAmount
        } else {
            return nil
        }
        guard amount > 0 else {
            return nil
        }

        let component: Calendar.Component
        switch unit {
        case "sec", "secs", "second", "seconds":
            component = .second
        case "min", "mins", "minute", "minutes":
            component = .minute
        case "hour", "hours", "hr", "hrs":
            component = .hour
        case "day", "days":
            component = .day
        case "week", "weeks":
            component = .weekOfYear
        case "month", "months":
            component = .month
        case "year", "years", "yr", "yrs":
            component = .year
        default:
            return nil
        }

        switch direction {
        case .past:
            guard let start = calendar.date(byAdding: component, value: -amount, to: now) else {
                return nil
            }
            return DateInterval(start: start, end: now)
        case .future:
            guard let end = calendar.date(byAdding: component, value: amount, to: now) else {
                return nil
            }
            return DateInterval(start: now, end: end)
        }
    }

    private static func previousInterval(
        of component: Calendar.Component,
        for date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        guard let current = calendar.dateInterval(of: component, for: date),
              let start = calendar.date(byAdding: component, value: -1, to: current.start) else {
            return nil
        }
        return DateInterval(start: start, end: current.start)
    }

    private static func nextInterval(
        of component: Calendar.Component,
        for date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        guard let current = calendar.dateInterval(of: component, for: date),
              let end = calendar.date(byAdding: component, value: 1, to: current.end) else {
            return nil
        }
        return DateInterval(start: current.end, end: end)
    }

    private static func monthNameInterval(_ value: String, now: Date, calendar: Calendar) -> DateInterval? {
        let months: [String: Int] = [
            "january": 1, "jan": 1,
            "february": 2, "feb": 2,
            "march": 3, "mar": 3,
            "april": 4, "apr": 4,
            "may": 5,
            "june": 6, "jun": 6,
            "july": 7, "jul": 7,
            "august": 8, "aug": 8,
            "september": 9, "sep": 9, "sept": 9,
            "october": 10, "oct": 10,
            "november": 11, "nov": 11,
            "december": 12, "dec": 12
        ]
        guard let month = months[value],
              let year = calendar.dateComponents([.year], from: now).year,
              let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private static func weekdayNameInterval(_ value: String, now: Date, calendar: Calendar) -> DateInterval? {
        let weekdays: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thur": 5, "thurs": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7
        ]
        guard let weekday = weekdays[value],
              let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return nil
        }

        let weekStartWeekday = calendar.component(.weekday, from: week.start)
        let offset = (weekday - weekStartWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: offset, to: week.start),
              let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private static func parseAbsoluteDateInterval(_ value: String, calendar: Calendar) -> DateInterval? {
        if value.count == 4,
           let year = Int(value),
           let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
           let end = calendar.date(byAdding: .year, value: 1, to: start) {
            return DateInterval(start: start, end: end)
        }

        if let monthInterval = parseYearMonthInterval(value, calendar: calendar) {
            return monthInterval
        }

        if let timedInterval = parseTimedDateInterval(value, calendar: calendar) {
            return timedInterval
        }

        if let date = parseAbsoluteDate(value) {
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }

        return nil
    }

    private static func parseYearMonthInterval(_ value: String, calendar: Calendar) -> DateInterval? {
        if value.count == 6,
           value.allSatisfy(\.isNumber) {
            let yearText = value.prefix(4)
            let monthText = value.dropFirst(4)
            guard let year = Int(yearText),
                  let month = Int(monthText),
                  (1...12).contains(month),
                  let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }

        let separator: Character
        if value.contains("-") {
            separator = "-"
        } else if value.contains("/") {
            separator = "/"
        } else {
            return nil
        }

        let parts = value.split(separator: separator)
        guard parts.count == 2 else {
            return nil
        }

        let yearText: Substring
        let monthText: Substring
        if parts[0].count == 4 {
            yearText = parts[0]
            monthText = parts[1]
        } else if parts[1].count == 4 {
            yearText = parts[1]
            monthText = parts[0]
        } else {
            return nil
        }

        guard let year = Int(yearText),
              let month = Int(monthText),
              (1...12).contains(month),
              let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private static func parseTimedDateInterval(_ value: String, calendar: Calendar) -> DateInterval? {
        let formats: [(String, Calendar.Component)] = [
            ("yyyy-MM-dd'T'HH:mm:ss", .second),
            ("yyyy-MM-dd'T'HH:mm", .minute),
            ("yyyy-MM-dd't'HH:mm:ss", .second),
            ("yyyy-MM-dd't'HH:mm", .minute),
            ("yyyy-MM-dd HH:mm:ss", .second),
            ("yyyy-MM-dd HH:mm", .minute),
            ("yyyy/MM/dd HH:mm:ss", .second),
            ("yyyy/MM/dd HH:mm", .minute),
            ("yyyyMMdd'T'HHmmss", .second),
            ("yyyyMMdd'T'HHmm", .minute),
            ("yyyyMMdd't'HHmmss", .second),
            ("yyyyMMdd't'HHmm", .minute),
            ("yyyyMMddHHmmss", .second),
            ("yyyyMMddHHmm", .minute)
        ]

        for (format, component) in formats {
            let formatter = makeFormatter(format)
            guard let start = formatter.date(from: value),
                  let end = calendar.date(byAdding: component, value: 1, to: start) else {
                continue
            }
            return DateInterval(start: start, end: end)
        }

        return nil
    }

    private static func parseComparisonDate(_ value: String) -> Date? {
        let calendar = Calendar.current
        if let interval = parseAbsoluteDateInterval(value, calendar: calendar) {
            return interval.start
        }
        return parseAbsoluteDate(value)
    }

    private static func quarterInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year,
              let month = components.month else {
            return nil
        }

        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        guard let start = calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1)),
              let end = calendar.date(byAdding: .month, value: 3, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private static func previousQuarterInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard let current = quarterInterval(containing: date, calendar: calendar),
              let start = calendar.date(byAdding: .month, value: -3, to: current.start) else {
            return nil
        }
        return DateInterval(start: start, end: current.start)
    }

    private static func nextQuarterInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard let current = quarterInterval(containing: date, calendar: calendar),
              let end = calendar.date(byAdding: .month, value: 3, to: current.end) else {
            return nil
        }
        return DateInterval(start: current.end, end: end)
    }

    private static func parseAbsoluteDate(_ value: String) -> Date? {
        let formatters: [DateFormatter] = [
            makeFormatter("yyyyMMdd"),
            makeFormatter("yyyy-MM-dd"),
            makeFormatter("yyyy/MM/dd"),
            makeFormatter("MM/dd/yyyy"),
            makeFormatter("MM-dd-yyyy")
        ]

        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}

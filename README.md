# MacThing

MacThing is a native macOS app for Everything-style file-name search. It
indexes a chosen folder, keeps a path-keyed index in memory, persists it in a
SQLite database, monitors file-system changes, and filters names and paths as
you type.

## Why This Exists

Everything itself is a Windows file-name search tool. macOS has Spotlight and a
few third-party alternatives, but there is still room for a focused, lightweight
tool that feels instant, stays local, and makes external or noisy folders easy to
search.

## Download

The current packaged release is available from GitHub:

- [MacThing 0.1.2 DMG](https://github.com/sioaeko/MacThing/releases/download/v0.1.2/MacThing-0.1.2.dmg)

## Everything-Like Behavior Implemented

- Native SwiftUI app.
- Recursive folder indexing with common cache, system, source-control, and
  developer build noise skipped.
- Profile-scoped index exclusion rules can skip hidden files, path prefixes,
  name wildcard patterns, and file extensions before entries reach memory or
  SQLite.
- Path-keyed in-memory index.
- SQLite database saved under Application Support. New roots and volumes use
  profile-scoped databases under `Profiles/<profile-id>/MacThing.db`.
- Legacy `MacThing.db` is migrated into the first active profile when needed.
- SQLite WAL mode and an FTS5 side table for name/path catalog data.
- Simple searches on large indexes use SQLite FTS candidate seeding plus
  substring fallback candidates before the Everything-style ranker validates
  results. Enabled file-list sources stay in the candidate set even when SQLite
  pruning is active.
- SQLite candidate seeding also applies supported structured filters such as
  extension, kind/category, file size, dates, and file attributes when they are
  combined with text terms.
- File-name, path, wildcard, regex, and compact fuzzy matching. Wildcard and
  regex searches honor the same case/diacritic matching options as text search.
- Match path, fuzzy, regex, case-sensitive, whole-word, and diacritic-sensitive
  matching options.
- Everything-style query operators: AND by spaces or explicit `AND`, OR with
  `|` or `OR`, negation with `!` or `-`, quoted terms with spaces, and
  grouped expressions such as `<invoice | receipt> pdf` or
  `(invoice | receipt) pdf`.
- Everything-style literal macros: `quot:`, `apos:`, `amp:`, `lt:`, `gt:`,
  decimal unicode `#<n>:` and hex unicode `#x<n>:` are treated as literal
  search characters.
- Everything-style search commands run on Enter: `/close`, `/closeall`, `/quit`
  or `/exit`, `/rebuild` or `/reindex`, `/update [path]`, `/help`,
  `about:`, `about:home`, and `about:options`.
- Function value sub-expressions are supported for text-like search functions,
  such as `name:<project notes>` or `content:<invoice|receipt>`.
- Text-like search functions support current-entry property substitution such
  as `stem:.$extension:`, `file-exists:$stem:.jpg`, `parent-name:$parent-name:`,
  `name:$size:`, and `stem:$kind:`.
- Formula-style property comparisons support core Everything examples such as
  `$date-modified:==$date-created:`, `UPPER($name:)>=N`,
  `$name:[1]=='o'`, and `len($stem:)%3==0`, plus `EXISTS()`,
  `CONTAINS()`, `STARTSWITH()`, `ENDSWITH()`, `LEFT()`, `RIGHT()`,
  `MID()`, `TRIM()`, `ABS()`, `ROUND()`, date component functions, and
  basic `+`/`-`/`*`/`/`/`%` arithmetic. Formula properties include common
  aliases for parent name/path, depth, lengths, attributes, dates, size, and
  child/descendant/sibling counts.
- Everything-style per-term modifiers: `case:`, `nocase:`, `diacritics:`,
  `nodiacritics:`, `path:`, `nopath:`, `wholeword:`/`ww:`,
  `nowholeword:`/`noww:`, `regex:`, `noregex:`, `wildcards:`,
  `nowildcards:`, `file:<term>`, `folder:<term>`, and
  `exact:`/`wholefilename:`.
- Numeric comparison functions support Everything-style ranges such as
  `size:2mb..10mb`, `len:3..12`, `runcount:1..5`, and
  `width:800..1920`; size constants include `empty`, `tiny`, `small`,
  `medium`, `large`, `huge`, `gigantic`, and `unknown`.
- Date functions support Everything-style constants and intervals such as
  `today`, `yesterday`, month/weekday names, `2days`, `mtd`, `qtd`, `ytd`,
  `thisweek`, `lastweek`, `pastweek`, `nextweek`, `lastmonth`, `nextmonth`,
  `lastquarter`, `nextquarter`, `lastyear`, `next2hours`, `unknown`, `2024`,
  `2024-05`, `05/2024`, `20240502`, `2024-05-02T12:00`, and wildcard dates
  such as `2024-05-*`.
- Comparison functions support `=`, `==`, `!=`, `!`, `<`, `<=`, `>`, and
  `>=`, and many function values accept semicolon OR lists such as
  `stem:launch;notes` or `type:image;audio`.
- Quoted function values preserve list separators as literal text, so searches
  such as `name:"Semi;Colon.txt"` and `filelist:"Pipe|Name.txt"` behave like
  Everything escaped lists.
- Search function names accept Everything-style dashed or dashless spellings,
  such as `date-modified:`/`datemodified:` and `aspect-ratio:`/`aspectratio:`.
- Query directives include `count:<max>`, `offset:<n>`, `skip:<n>`,
  `first:<1-based-position>`, `sort:<field>`, `ascending:<field>`,
  and `descending:<field>`; sort fields accept aliases such as `name`, `path`,
  `extension`, `size`, `dm`, `dc`, `da`, `run-count`, and `date-run`.
- `shell:<name>` maps common Everything known-folder names to macOS locations,
  such as `shell:desktop`, `shell:downloads`, `shell:documents`, `shell:applications`,
  and `shell:trash`, including indexed descendants.
- Search functions: `file:`, `folder:`, `ext:jpg;png`, `ext:` for files without
  extensions, `everything:`, `nop:`, `nothing:`, `size:>1mb`/`sz:>1mb`/`size:large`,
  `dm:today`/`date:today`/`date-modified-date:today`, `dm:yesterday`,
  `dm:lastweek`/`dm:nextweek`/`dm:last2hours`/`dm:unknown`, `dc:`/`date-created-date:`, `da:`/`date-accessed-date:`,
  `dr:`, `rc:`,
  `count:<max>`, `runcount:>1`, `name:`/`basename:`, `name-frequency:`,
  `stem:`/`namepart:`, `full-path:`/`path-and-name:`/`parse-path-name:`,
  `path-list:`/`full-path-list:`,
  `path-part:`/`location:`/`pp:`, `path-dupe:`,
  `parent:<path>`, `parent-name:`, `parent-path:`/`parent-full-path:`, `infolder:<path>`,
  `nosubfolders:<path>`, `parent+0:`-`parent+9:`,
  `parent-depth1:`-`parent-depth9:`, `parent-dc:`/`parent-date-created:`,
  `parent-dm:`/`parent-date-modified:`, `parent-size:`,
  `ancestor:<path>`, `ancestor-name:`,
  `shell:<name>`,
  `ancestor-attr:`, `ancestor-child:<name>`, `ancestor-child-file:<name>`,
  `ancestor-child-folder:<name>`, `parent-child:<name>`,
  `parent-child-file:<name>`, `parent-child-folder:<name>`,
  `parent-sibling:<name>`, `ancestor-sibling:<name>`,
  `startwith:`, `endwith:`,
  `depth:`/`parents:`/`parent-count:`,
  `chars:`, `len:`/`basename-len:`, `filename-len:`/`path-len:`,
  `stem-len:`, `utf8-len:`,
  `full-path-utf8-byte-length:`, `path-part-len:`/`location-len:`,
  `ext-len:`, `extension-frequency:`, `child:<name>`, `child-file:<name>`,
  `child-folder:<name>`, `childcount:`, `childfilecount:`,
  `childfoldercount:`, `child-attr:`, `child-file-attr:`,
  `child-folder-attr:`, `child-dc:`/`child-dm:`/`child-da:`/`child-rc:`,
  `child-date-run:`, `child-run-count:`, `child-size:`,
  `child-file-size:`, `child-folder-size:`, `child-file-list:`,
  `total-child-size:`, `descendant:<name>`,
  `descendant-file:<name>`, `descendant-folder:<name>`,
  `descendant-count:`, `descendant-file-count:`, `descendant-folder-count:`,
  `sibling:<name>`,
  `sibling-file:<name>`, `sibling-folder:<name>`, `sibling-count:`, `sibling-file-count:`,
  `sibling-folder-count:`, `empty:`, `dupe:`, `namepartdupe:`, `sizedupe:`,
  `attribdupe:`, `dadupe:`, `dcdupe:`, `dmdupe:`, `type:image`,
  `kind:folder`, `width:`, `height:`, `bit-depth:`/`bitdepth:`,
  `dimension:`/`dimensions:`, `orientation:landscape|portrait|square`,
  `aspect-ratio:`/`aspectratio:`,
  `title:<text>`, `artist:<text>`, `album:<text>`, `comment:<text>`,
  `genre:<text>`, `track:<number|comparison>`, `year:<number|comparison>`,
  `type:compressed`, `type:executable`,
  `filelist:<name|path|wildcard|...>`, `filelistfilename:<source>`,
  `frn:<file-id|volume-id:file-id>`, `fsi:<index>`,
  `exists:`/`file-exists:`/`folder-exists:`,
  `root:`, `image:`/`pic:`/`pics:`, `audio:`/`audios:`, `video:`,
  `document:`/`docs:`, `zip:`/`zips:`/`archives:`, `exe:`/`apps:`,
  `attrib:acdehilnoprst`/`attribute:h`,
  `hidden:`, `readonly:`, `system:`, `symlink:`, `package:`, `content:<text>`, `utf8content:<text>`,
  `utf16content:<text>`, `utf16becontent:<text>`, and `ansicontent:<text>`.
- Indexed metadata includes name, path, extension, kind, size, created date,
  modified date, accessed date, indexed date, run count, date run, and file
  attributes.
- New scans store filesystem identity metadata from inode/device IDs so
  rename/move updates can preserve per-result state such as run count and date
  run.
- Clickable result headers sort by name, path, kind, size, and modified date.
- Sort menu exposes all supported sort fields, including relevance, extension,
  created date, accessed date, indexed date, run count, date run, and
  attributes.
- Column menu can show or hide result columns such as extension, created date,
  accessed date, indexed date, run count, date run, and attributes.
- Filter bar for all, files, folders, images, audio, video, and documents.
- Mounted volume menu can refresh and index a selected local or external volume
  root.
- Mounted network volumes exposed by macOS under `/Volumes` can be indexed from
  the same volume menu. Initial scans work like local volumes, while live change
  detection depends on the network file system/server and may need manual
  reindexing when stale.
- Index profile menu can add the current root, switch between saved roots, and
  remove inactive profiles.
- Multiple enabled index profiles are searched together, so separate roots or
  volumes can behave like one Everything-style searchable catalog while the
  active profile remains the live monitored/reindexed target.
- FSEvents monitors watch every enabled index profile root, preserve event
  flags, apply changed-path subtree updates to the matching profile database,
  scan parent folders for rename/remove events, and fall back to profile-scoped
  full refreshes for dropped or broad changes.
- Index profiles track the last seen FSEvents event ID while running, but app
  launch resumes monitoring from the current event stream so old backlog does
  not trigger a full refresh on every start.
- Diagnostics menu checks common protected locations and opens Full Disk Access
  settings when indexing appears incomplete.
- Run count is updated when opening a result.
- Search settings such as root, query, filter, sort, and matching options are
  persisted between launches.
- Bookmarks save and restore query, filter, sort, and matching options.
- Search history records recent stable queries and can be reapplied or cleared
  from the toolbar or menu bar extra.
- User filters save a reusable query expression and can be reapplied from the
  toolbar or menu bar extra.
- Global Option+Space hotkey opens a compact floating search palette.
- Global hotkey can be switched between Option Space, Control Option Space,
  Command Option Space, or disabled.
- The compact palette supports type-to-search, result selection, Enter to open,
  and Escape to dismiss.
- Menu bar extra provides quick search, show window, reindex, index status, and
  quit actions.
- Bundled app builds can toggle launch-at-login from the menu bar extra.
- Layered app icon source is stored as an Apple Icon Composer `.icon` document
  and exported into the release bundle during packaging.
- Visible results can be exported to CSV. Core exporters also produce TXT and
  EFU-like file-list output.
- EFU-like file lists are stored as separate sources for offline/NAS/media
  catalog search, and can be enabled, disabled, refreshed, or removed without
  rewriting the local disk index.
- `content:<text>` explicitly searches small UTF-8, UTF-16, and Windows-1252
  text files as a slower secondary path; encoding-specific forms include
  `utf8content:`, `utf16content:`, `utf16becontent:`, and `ansicontent:`.
- Local read-only HTTP query service:
  - `GET http://127.0.0.1:16245/api/status`
  - `GET http://127.0.0.1:16245/api/search?q=swift&limit=100&offset=0`
  - Search accepts `sort`, `order`, `matchPath`, `fuzzy`, `case`,
    `regex`, `wholeWord`, `diacritics`, `limit`, `offset`, `format`, and `columns`
    query parameters.
  - `format` supports `json`, `csv`, `txt`, and `efu`.
  - Example:
    `GET http://127.0.0.1:16245/api/search?q=swift%20count%3A50&offset=50&sort=name&order=asc&format=csv&columns=name,path`
- `MacThingCLI` provides an external command-line client for the local query
  service, similar in spirit to Everything command-line search tooling.
- Recent files shown when the search box is empty.
- Open, reveal in Finder, and copy path actions.
- Dependency-free Swift Package.

## Run

```sh
swift run MacThing
```

With MacThing running, query it from the command line:

```sh
swift run MacThingCLI -- status
swift run MacThingCLI -- search swift --limit 20 --format csv --columns name,path
swift run MacThingCLI -- search swift -n 20 -o 20 --sort name
swift run MacThingCLI -- search swift -sort dm -order desc -csv
```

## Package

Build a release app bundle, generate the bundled icon, ad-hoc sign the app, and
create a compressed DMG:

```sh
chmod +x Scripts/package-mac.sh
Scripts/package-mac.sh
```

Packaging requires Apple's Icon Composer because the app icon is exported from
`Assets/MacThing.icon` with `ictool`. Install or mount Icon Composer, or point
the script at the tool explicitly:

```sh
ICTOOL="/Applications/Icon Composer.app/Contents/Executables/ictool" Scripts/package-mac.sh
```

The packaged outputs are written to:

- `dist/MacThing.app`
- `dist/MacThing-0.1.2.dmg`

Override release metadata when needed:

```sh
VERSION=0.2.0 BUILD_NUMBER=7 BUNDLE_ID=com.example.MacThing Scripts/package-mac.sh
```

## Verify

```sh
swift build
swift run MacThingSelfTest
```

`swift test` is not used because this local Command Line Tools setup does not
expose XCTest or Swift Testing modules. `MacThingSelfTest` exercises the core
ranking behavior through a normal executable target instead.

## Roadmap

1. Add inode-aware rename/move pairing for even tighter FSEvents updates.
2. Push more Everything query functions into SQLite candidate pruning for large
   indexes while preserving substring-search correctness.
3. Add hardened Developer ID signing, notarization, and a first-run onboarding
   checklist for release builds.
4. Add deeper permission diagnostics with per-location read probes and guided
   remediation.
5. Add per-file-list scheduling, remote refresh, and conflict diagnostics.
6. Add configurable HTTP auth and CORS policy for non-default integrations.

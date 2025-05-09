import Foundation
import Fuse
import SQLiteORM

// MARK: – Models

struct TMTask: Initializable {
  var uuid = ""
  var trashed = 0
  var title: String? = nil
  var notes: String? = nil
  var project: String? = nil
  var area: String? = nil

  var leavesTombstone = 0
  var creationDate = 0.0
  var userModificationDate = 0.0
  var type = 0
  var status = 0
  var stopDate: Double? = nil
  var notesSync = 0
  var cachedTags: String? = nil
  var start = 0
  var startDate = 0
  var startBucket: Int? = nil
  var reminderTime: Int? = nil
  var lastReminderInteractionDate: Int? = nil
  var deadline: Int? = nil
  var deadlineSuppressionDate: Int? = nil
  var t2_deadlineOffset: Int? = nil
  var index: Int? = nil
  var todayIndex: Int? = nil
  var todayIndexReferenceDate: Int? = nil
  var heading: String? = nil
  var contact: String? = nil
  var untrashedLeafActionsCount = 0
  var openUntrashedLeafActionsCount = 0
  var checklistItemsCount = 0
  var openChecklistItemsCount = 0
  var rt1_repeatingTemplate: String? = nil
  var rt1_recurrenceRule: String? = nil
  var rt1_instanceCreationStartDate: Int? = nil
  var rt1_instanceCreationPaused: Int? = nil
  var rt1_instanceCreationCount: Int? = nil
  var rt1_afterCompletionReferenceDate: Int? = nil
  var rt1_nextInstanceStartDate: Int? = nil
  var experimental: String? = nil
  var repeater: String? = nil
  var repeaterMigrationDate: Int? = nil

  init() {}
}

struct TMArea: Initializable {
  var uuid = ""
  var title = ""
  var visible: Int? = nil
  var index: Int? = nil
  var cachedTags: String? = nil
  var experimental: String? = nil
  init() {}
}

/// Alfred JSON item
struct AlfredItem: Codable {
  let title: String
  let subtitle: String
  let arg: String
  let valid: Bool
  let score: Double?
  let matchedField: String?
  let positions: [Int]?
}

// MARK: – Helpers

/// Read THINGS_DATABASE from a local prefs.plist
func databasePathFromPrefs() -> String? {
  let fm = FileManager.default
  guard
    let data = fm.contents(atPath: "prefs.plist"),
    let plist = try? PropertyListSerialization
      .propertyList(from: data, options: [], format: nil)
      as? [String: Any],
    let db = plist["THINGS_DATABASE"] as? String
  else { return nil }
  return db
}

/// Fallback: scan ~/Library/Group Containers/.../ThingsData*/
func discoverThingsDatabase() -> String? {
  let home = NSHomeDirectory()
  let base =
    home
    + "/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac"
  guard
    let subs = try? FileManager.default.contentsOfDirectory(atPath: base)
  else { return nil }
  for d in subs where d.hasPrefix("ThingsData") {
    let candidate =
      base
      + "/\(d)/Things Database.thingsdatabase/main.sqlite"
    if FileManager.default.fileExists(atPath: candidate) {
      return candidate
    }
  }
  return nil
}

/// Build your ORM storage
func makeStorage(dbPath: String) throws -> Storage {
  let taskTable = Table<TMTask>(
    name: "TMTask",
    columns:
      // primary key
      Column(
        name: "uuid",
        keyPath: \TMTask.uuid,
        constraints: primaryKey(), notNull()),
    Column(
      name: "trashed",
      keyPath: \TMTask.trashed,
      constraints: notNull()),
    Column(
      name: "title",
      keyPath: \TMTask.title),
    Column(
      name: "notes",
      keyPath: \TMTask.notes),
    Column(
      name: "project",
      keyPath: \TMTask.project),
    Column(
      name: "area",
      keyPath: \TMTask.area),

    Column(
      name: "leavesTombstone",
      keyPath: \TMTask.leavesTombstone,
      constraints: notNull()),
    Column(
      name: "creationDate",
      keyPath: \TMTask.creationDate,
      constraints: notNull()),
    Column(
      name: "userModificationDate",
      keyPath: \TMTask.userModificationDate,
      constraints: notNull()),
    Column(
      name: "type",
      keyPath: \TMTask.type,
      constraints: notNull()),
    Column(
      name: "status",
      keyPath: \TMTask.status,
      constraints: notNull()),
    Column(
      name: "stopDate",
      keyPath: \TMTask.stopDate),
    Column(
      name: "notesSync",
      keyPath: \TMTask.notesSync,
      constraints: notNull()),
    Column(
      name: "cachedTags",
      keyPath: \TMTask.cachedTags),
    Column(
      name: "start",
      keyPath: \TMTask.start,
      constraints: notNull()),
    Column(
      name: "startDate",
      keyPath: \TMTask.startDate,
      constraints: notNull()),
    Column(
      name: "startBucket",
      keyPath: \TMTask.startBucket),
    Column(
      name: "reminderTime",
      keyPath: \TMTask.reminderTime),
    Column(
      name: "lastReminderInteractionDate",
      keyPath: \TMTask.lastReminderInteractionDate),
    Column(
      name: "deadline",
      keyPath: \TMTask.deadline),
    Column(
      name: "deadlineSuppressionDate",
      keyPath: \TMTask.deadlineSuppressionDate),
    Column(
      name: "t2_deadlineOffset",
      keyPath: \TMTask.t2_deadlineOffset),
    Column(
      name: "index",
      keyPath: \TMTask.index),
    Column(
      name: "todayIndex",
      keyPath: \TMTask.todayIndex),
    Column(
      name: "todayIndexReferenceDate",
      keyPath: \TMTask.todayIndexReferenceDate),
    Column(
      name: "heading",
      keyPath: \TMTask.heading),
    Column(
      name: "contact",
      keyPath: \TMTask.contact),
    Column(
      name: "untrashedLeafActionsCount",
      keyPath: \TMTask.untrashedLeafActionsCount,
      constraints: notNull()),
    Column(
      name: "openUntrashedLeafActionsCount",
      keyPath: \TMTask.openUntrashedLeafActionsCount,
      constraints: notNull()),
    Column(
      name: "checklistItemsCount",
      keyPath: \TMTask.checklistItemsCount,
      constraints: notNull()),
    Column(
      name: "openChecklistItemsCount",
      keyPath: \TMTask.openChecklistItemsCount,
      constraints: notNull()),
    Column(
      name: "rt1_repeatingTemplate",
      keyPath: \TMTask.rt1_repeatingTemplate),
    Column(
      name: "rt1_recurrenceRule",
      keyPath: \TMTask.rt1_recurrenceRule),
    Column(
      name: "rt1_instanceCreationStartDate",
      keyPath: \TMTask.rt1_instanceCreationStartDate),
    Column(
      name: "rt1_instanceCreationPaused",
      keyPath: \TMTask.rt1_instanceCreationPaused),
    Column(
      name: "rt1_instanceCreationCount",
      keyPath: \TMTask.rt1_instanceCreationCount),
    Column(
      name: "rt1_afterCompletionReferenceDate",
      keyPath: \TMTask.rt1_afterCompletionReferenceDate),
    Column(
      name: "rt1_nextInstanceStartDate",
      keyPath: \TMTask.rt1_nextInstanceStartDate),
    Column(
      name: "experimental",
      keyPath: \TMTask.experimental),
    Column(
      name: "repeater",
      keyPath: \TMTask.repeater),
    Column(
      name: "repeaterMigrationDate",
      keyPath: \TMTask.repeaterMigrationDate)
  )

  let areaTable = Table<TMArea>(
    name: "TMArea",
    columns:
      Column(
        name: "uuid", keyPath: \TMArea.uuid,
        constraints: primaryKey(), notNull()),
    Column(name: "title", keyPath: \TMArea.title, constraints: notNull()),
    Column(name: "visible", keyPath: \TMArea.visible),
    Column(name: "index", keyPath: \TMArea.index),

    Column(name: "cachedTags", keyPath: \TMArea.cachedTags),
    Column(name: "experimental", keyPath: \TMArea.experimental)
  )

  return try Storage(
    filename: dbPath,
    tables: taskTable, areaTable
  )
}

// MARK: – Main

func main() {
  // 1) query arg
  let query = CommandLine.arguments
    .dropFirst()
    .joined(separator: " ")
    .trimmingCharacters(in: .whitespacesAndNewlines)

  guard !query.isEmpty else {
    print("{\"items\":[]}")
    return
  }

  // 2) locate DB
  let env = ProcessInfo.processInfo.environment
  let dbPath =
    env["THINGS_DATABASE"]
    ?? databasePathFromPrefs()
    ?? discoverThingsDatabase()
  guard let path = dbPath else {
    let item = AlfredItem(
      title: "Could not locate Things database",
      subtitle: "",
      arg: "",
      valid: false,
      score: nil,
      matchedField: nil,
      positions: nil
    )
    print(
      String(
        data: try! JSONEncoder().encode(["items": [item]]),
        encoding: .utf8)!)
    return
  }

  // 3) open storage
  let storage: Storage
  do { storage = try makeStorage(dbPath: path) } catch {
    let item = AlfredItem(
      title: "Failed to open DB",
      subtitle: error.localizedDescription,
      arg: "",
      valid: false,
      score: nil,
      matchedField: nil,
      positions: nil
    )
    print(
      String(
        data: try! JSONEncoder().encode(["items": [item]]),
        encoding: .utf8)!)
    return
  }

  // 4) fetch *all* tasks & areas, then filter in-memory
  let allTasks: [TMTask]
  let allAreas: [TMArea]
  do {
    allTasks = try storage.getAll()  // → [TMTask]
    allAreas = try storage.getAll()  // → [TMArea]
  } catch {
    let item = AlfredItem(
      title: "Failed to query DB",
      subtitle: error.localizedDescription,
      arg: "",
      valid: false,
      score: nil,
      matchedField: nil,
      positions: nil
    )
    print(
      String(
        data: try! JSONEncoder().encode(["items": [item]]),
        encoding: .utf8)!)
    return
  }

  // 5) only non-trashed tasks
  let rawTasks = allTasks.filter { $0.trashed == 0 }

  // 6) build uuid→title maps for project/area lookups
  let taskMap = Dictionary(
    uniqueKeysWithValues:
      allTasks.map { ($0.uuid, $0.title) }
  )
  let areaMap = Dictionary(
    uniqueKeysWithValues:
      allAreas.map { ($0.uuid, $0.title) }
  )

  // 7) build subtitleMap
  var subtitleMap = [String: String]()
  for t in rawTasks {
    if let pid = t.project, let pt = taskMap[pid] {
      subtitleMap[t.uuid] = pt
    } else if let aid = t.area, let at = areaMap[aid] {
      subtitleMap[t.uuid] = at
    } else {
      subtitleMap[t.uuid] = ""
    }
  }

  // 8) flatten title+notes into searchable slots
  struct Slot { let uuid, field, text: String }
  var slots = [Slot]()
  for t in rawTasks {
    if !(t.title?.isEmpty == nil) {
      slots.append(.init(uuid: t.uuid, field: "title", text: t.title!))
    }
    if let n = t.notes, !n.isEmpty {
      slots.append(.init(uuid: t.uuid, field: "notes", text: n))
    }
  }

  // 9) fuzzy-search with Fuse
  let fuse = Fuse()
  let maxResults = Int(env["MAX_RESULTS"] ?? "50") ?? 50
  var hits = [(uuid: String, field: String, positions: [Int], score: Double)]()

  for s in slots {
    if let result = fuse.search(query, in: s.text) {
      // result.ranges is [ClosedRange<Int>]
      let positions = result.ranges.flatMap { Array($0) }
      hits.append(
        (
          uuid: s.uuid,
          field: s.field,
          positions: positions,
          score: result.score
        ))
    }
  }

  // 10) sort (lower Fuse.score is better) & unique by uuid
  hits.sort { $0.score < $1.score }
  var seen = Set<String>()
  var items = [AlfredItem]()

  for h in hits where items.count < maxResults {
    guard !seen.contains(h.uuid),
      let rec = rawTasks.first(where: { $0.uuid == h.uuid })
    else { continue }
    seen.insert(h.uuid)
    let arg = "things:///show?id=\(h.uuid)"
    items.append(
      .init(
        title: rec.title!,
        subtitle: subtitleMap[h.uuid] ?? "",
        arg: arg,
        valid: !arg.isEmpty,
        score: h.score,
        matchedField: h.field,
        positions: h.positions
      ))
  }

  // 11) output
  let data = try! JSONEncoder().encode(["items": items])
  print(String(data: data, encoding: .utf8)!)
}
main()

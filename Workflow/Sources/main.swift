import Foundation
import Fuse
import SQLite

// MARK: – Models

struct TMTask {
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

struct TMArea {
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

// MARK: – Main

func loadAllTasksAndAreas(from dbPath: String)
  throws -> (tasks: [TMTask], areas: [TMArea])
{
  // 1) open the DB
  let db = try Connection(dbPath)

  // 2) prepare the two Table handles
  let taskTable = Table("TMTask")
  let areaTable = Table("TMArea")

  // 3) declare only the columns you actually need...
  //    — TASK columns
  let tUUID = Expression<String>("uuid")
  let tTrashed = Expression<Int>("trashed")
  let tTitle = Expression<String?>("title")
  let tNotes = Expression<String?>("notes")
  let tProject = Expression<String?>("project")
  let tAreaFK = Expression<String?>("area")
  //    …add any other TMTask columns you care about…

  //    — AREA columns
  let aUUID = Expression<String>("uuid")
  let aTitle = Expression<String>("title")
  let aVisible = Expression<Int?>("visible")
  let aIndex = Expression<Int?>("index")
  let aCachedTags = Expression<String?>("cachedTags")
  let aExperimental = Expression<String?>("experimental")
  //    …add any other TMArea columns you care about…

  // 4) fetch ALL TASKS
  let allTasks: [TMTask] =
    try db
    .prepare(taskTable)
    .map { row in
      var t = TMTask()
      t.uuid = row[tUUID]
      t.trashed = row[tTrashed]
      t.title = row[tTitle]
      t.notes = row[tNotes]
      t.project = row[tProject]
      t.area = row[tAreaFK]
      // …assign any other fields you need…
      return t
    }

  // 5) fetch ALL AREAS
  let allAreas: [TMArea] =
    try db
    .prepare(areaTable)
    .map { row in
      var a = TMArea()
      a.uuid = row[aUUID]
      a.title = row[aTitle]
      a.visible = row[aVisible]
      a.index = row[aIndex]
      a.cachedTags = row[aCachedTags]
      a.experimental = row[aExperimental]
      // …assign any other fields you need…
      return a
    }

  return (allTasks, allAreas)
}

func main() async throws {
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
    )
    print(
      String(
        data: try! JSONEncoder().encode(["items": [item]]),
        encoding: .utf8)!)
    return
  }

  let allTasks: [TMTask]
  let allAreas: [TMArea]

  do {
    (allTasks, allAreas) = try loadAllTasksAndAreas(from: path)
    // now you can filter `allTasks` or `allAreas` in‐memory as before
  } catch {
    let item = AlfredItem(
      title: "DB Error",
      subtitle: error.localizedDescription,
      arg: "",
      valid: false
    )
    print(
      String(
        data: try! JSONEncoder().encode(["items": [item]]),
        encoding: .utf8
      )!
    )
    return
  }

  // 5) only non-trashed tasks
  let rawTasks = allTasks.filter { $0.trashed == 0 }

  // 6) Build uuid→title maps concurrently
  async let taskMapResult = Dictionary(
    uniqueKeysWithValues: allTasks.map { ($0.uuid, $0.title) }
  )
  async let areaMapResult = Dictionary(
    uniqueKeysWithValues: allAreas.map { ($0.uuid, $0.title) }
  )

  let (taskMap, areaMap) = await (taskMapResult, areaMapResult)

  // 7) Build subtitleMap more efficiently
  let subtitleMap = rawTasks.reduce(into: [String: String]()) { map, task in
    if let pid = task.project, let pt = taskMap[pid] {
      map[task.uuid] = pt
    } else if let aid = task.area, let at = areaMap[aid] {
      map[task.uuid] = at
    } else {
      map[task.uuid] = ""
    }
  }

  // 7.1) If fuzzy search disabled, just spit out the result
  if env["WITH_FUZZY"] == "0" {
    let items = rawTasks.map { task -> AlfredItem in
      let title = task.title ?? ""
      let subtitle = subtitleMap[task.uuid] ?? ""
      let arg = "things:///show?id=\(task.uuid)"
      return AlfredItem(
        title: title,
        subtitle: subtitle,
        arg: arg,
        valid: !arg.isEmpty
      )
    }
    let data = try! JSONEncoder().encode(["items": items])
    print(String(data: data, encoding: .utf8)!)
    return
  }

  // 8) Flatten title+notes into searchable slots
  struct Slot { let uuid, field, text: String }
  let slots = await withTaskGroup(of: [Slot].self) { group in
    // Split tasks into chunks for parallel processing
    let chunkSize = max(1, rawTasks.count / ProcessInfo.processInfo.processorCount)
    let chunks = stride(from: 0, to: rawTasks.count, by: chunkSize).map {
      Array(rawTasks[$0..<min($0 + chunkSize, rawTasks.count)])
    }

    for chunk in chunks {
      group.addTask {
        var chunkSlots = [Slot]()
        for t in chunk {
          if let title = t.title, !title.isEmpty {
            chunkSlots.append(.init(uuid: t.uuid, field: "title", text: title))
          }
          if let notes = t.notes, !notes.isEmpty {
            chunkSlots.append(.init(uuid: t.uuid, field: "notes", text: notes))
          }
        }
        return chunkSlots
      }
    }

    // Combine results
    var allSlots = [Slot]()
    for await chunkResult in group {
      allSlots.append(contentsOf: chunkResult)
    }
    return allSlots
  }

  // 9) Fuzzy-search with Fuse using concurrency
  let maxResults = Int(env["MAX_RESULTS"] ?? "50") ?? 50

  let hits = await withTaskGroup(
    of: [(uuid: String, field: String, positions: [Int], score: Double)].self
  ) { group in
    // split slots into roughly equal chunks
    let processorCount = ProcessInfo.processInfo.processorCount
    let chunkSize = max(1, slots.count / processorCount)
    let chunks = stride(from: 0, to: slots.count, by: chunkSize).map {
      Array(slots[$0..<min($0 + chunkSize, slots.count)])
    }

    for chunk in chunks {
      group.addTask {
        // each task gets its own Fuse
        let localFuse = Fuse()
        var chunkHits = [(uuid: String, field: String, positions: [Int], score: Double)]()
        for s in chunk {
          if let result = localFuse.search(query, in: s.text) {
            let positions = result.ranges.flatMap { Array($0) }
            chunkHits.append(
              (
                uuid: s.uuid,
                field: s.field,
                positions: positions,
                score: result.score
              ))
          }
        }
        return chunkHits
      }
    }

    var allHits = [(uuid: String, field: String, positions: [Int], score: Double)]()
    for await chunkResult in group {
      allHits.append(contentsOf: chunkResult)
    }
    return allHits
  }

  // 10) Sort and filter results
  let sortedHits = hits.sorted { $0.score < $1.score }
  var seen = Set<String>()
  var items = [AlfredItem]()

  for hit in sortedHits where items.count < maxResults {
    guard !seen.contains(hit.uuid),
      let rec = rawTasks.first(where: { $0.uuid == hit.uuid })
    else {
      continue
    }

    seen.insert(hit.uuid)
    guard let title = rec.title else { continue }

    let arg = "things:///show?id=\(hit.uuid)"
    items.append(
      .init(
        title: title,
        subtitle: subtitleMap[hit.uuid] ?? "",
        arg: arg,
        valid: !arg.isEmpty
      )
    )
  }
  // 11) output
  let data = try! JSONEncoder().encode(["items": items])
  print(String(data: data, encoding: .utf8)!)
}
try await main()

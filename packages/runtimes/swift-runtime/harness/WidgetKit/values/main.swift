import Foundation
#if !OURS
import WidgetKit
#endif

let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
for f in families {
    print("family", "\(f)", f.rawValue, f.description, f.debugDescription)
}
for n in -1...4 {
    if let f = WidgetFamily(rawValue: n) { print("family-raw", n, "\(f)") } else { print("family-raw", n, "none") }
}

let modes: [WidgetRenderingMode] = [.fullColor, .accented, .vibrant]
for m in modes { print("rendering", m.description) }
print("rendering-equal", WidgetRenderingMode.accented == WidgetRenderingMode.accented, WidgetRenderingMode.fullColor == WidgetRenderingMode.vibrant)

let accented: [WidgetAccentedRenderingMode] = [.accented, .desaturated, .accentedDesaturated, .fullColor]
print("accented-equal", accented.map { a in accented.map { a == $0 } })


let date = Date(timeIntervalSince1970: 1_000)
print("reload", TimelineReloadPolicy.atEnd == TimelineReloadPolicy.atEnd, TimelineReloadPolicy.never == TimelineReloadPolicy.atEnd,
      TimelineReloadPolicy.after(date) == TimelineReloadPolicy.after(date), TimelineReloadPolicy.after(date) == TimelineReloadPolicy.after(date + 1))

struct Entry: TimelineEntry {
    let date: Date
}
let timeline = Timeline(entries: [Entry(date: date), Entry(date: date + 60)], policy: .after(date + 120))
print("timeline", timeline.entries.count, timeline.entries.map { $0.date.timeIntervalSince1970 }, timeline.policy == .after(date + 120))
let empty = Timeline<Entry>(entries: [], policy: .never)
print("timeline-empty", empty.entries.count, empty.policy == .never)

let relevance = TimelineEntryRelevance(score: 0.5, duration: 60)
print("relevance", relevance.score, relevance.duration)
print("entry-default-relevance", Entry(date: date).relevance == nil)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let encoded = try! encoder.encode(relevance)
print("relevance-json", String(data: encoded, encoding: .utf8)!)
print("relevance-decode", (try? JSONDecoder().decode(TimelineEntryRelevance.self, from: encoded)) == relevance)
print("relevance-equal", relevance == TimelineEntryRelevance(score: 0.5, duration: 60), relevance == TimelineEntryRelevance(score: 0.5, duration: 61))
print("relevance-set", Set([relevance, TimelineEntryRelevance(score: 0.5, duration: 60)]).count)
print("accented-set", Set(accented).count)
print("reload-after-round-trip", TimelineReloadPolicy.after(date) == TimelineReloadPolicy.after(Date(timeIntervalSince1970: 1_000)))

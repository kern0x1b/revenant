for (name, body) in table {
    let lines: [String]
    do {
        lines = try body()
    } catch {
        print("\(name)\tTHREW \(error)")
        continue
    }
    if lines.isEmpty {
        print("\(name)\t(nothing)")
    } else {
        for line in lines {
            print("\(name)\t\(line)")
        }
    }
}
print("cases \(table.count)")

//
//  main.swift
//
//  Runs the table and writes it out: one line per thing a subscriber was given, prefixed
//  with the case's name. The file this prints is compared with the file the same source
//  prints against the host's own Combine, and a difference on any line is a difference
//  in what a caller of the two would see.
//


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

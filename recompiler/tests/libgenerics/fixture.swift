import Foundation

@inline(never) func line(_ text: String) {
    print(text)
    fflush(nil)
}

@inline(never) func report(_ name: String, _ passed: Bool) {
    line((passed ? "ok " : "FAIL ") + name)
}

@objc(LibGenerics) public final class LibGenerics: NSObject {
    @objc public func stepDictionary() {
        var names = [String: String]()
        names["a"] = "alpha"
        names["b"] = "beta"
        report("dictionary.string", names.count == 2 && names["b"] == "beta")
    }

    @objc public func stepDictionaryAny() {
        var bag = [String: Any]()
        bag["count"] = 3
        bag["name"] = "x"
        bag["list"] = [1, 2, 3]
        report("dictionary.any", bag.count == 3 && (bag["count"] as? Int) == 3 && (bag["name"] as? String) == "x" && (bag["list"] as? [Int])?.count == 3)
    }

    @objc public func stepClosures() {
        var makers = [() -> Int]()
        for index in 1...3 {
            makers.append { index * 10 }
        }
        report("closures.array", makers.count == 3 && makers[2]() == 30)
    }

    @objc public func stepNested() {
        var grid = [[Int]]()
        for row in 0..<4 {
            grid.append(Array(0...row))
        }
        report("array.nested", grid.count == 4 && grid[3] == [0, 1, 2, 3] && grid.joined().reduce(0, +) == 10)
    }

    @objc public func stepSubstring() {
        let text = "alpha,beta,gamma,delta"
        var pieces = [Substring]()
        for chunk in text.split(separator: ",") {
            pieces.append(chunk)
        }
        pieces.append(text.dropFirst(6))
        report("substring.split", pieces.count == 5 && pieces[1] == "beta" && pieces[4] == "beta,gamma,delta")
    }

    @objc public func stepStress() {
        var numbers = [Int]()
        var words = [String]()
        var slices = [Substring]()
        var table = [String: Int]()
        let text = "0123456789"
        for index in 0..<10000 {
            numbers.append(index)
            words.append(String(index))
            slices.append(text.dropFirst(index % 10))
            table[words[index]] = index
        }
        var sum = 0
        for number in numbers {
            sum &+= number
        }
        let tail = slices[9999] == "9"
        report("stress.append", numbers.count == 10000 && sum == 49995000 && words[9999] == "9999" && slices.count == 10000 && tail && table.count == 10000 && table["4242"] == 4242)
    }
}

//
//  KumykLayoutTests.swift
//  KumykCoreTests
//
//  KumykLayout.swift: the three letter rows, the one departure from the
//  Russian iOS layout (checked against the pinned transcription of that
//  layout, Fixtures/agisight/rus-3-rows.yaml), every long-press mapping,
//  the digraph assignment of the pinned Kumyk mapping
//  (kum_key_mapping_ext.json), the alphabet, and the evidence the design
//  rests on, measured again from the shipped dictionary.
//

import XCTest
import SQLite3
import UIKit
@testable import KumykCore
@testable import GeneralKeyboard

final class KumykLayoutTests: KumykTestCase {

    private var spec: LayoutStyleSpec { KeyboardDefinition.current.layout.spec(for: .standard) }

    private func characters(_ row: [KeyCap]) -> [String] {
        row.compactMap { if case .character(let c) = $0 { return c } else { return nil } }
    }

    private var letterKeys: [String] { spec.letterRows.flatMap(characters) }

    // MARK: - Minimal readers for the pinned files

    private func file(_ name: String) throws -> String {
        try RepoPaths.text(RepoPaths.upstream.appendingPathComponent(name))
    }

    /// Rows of one layer of `iOS: primary:` as key tokens; `\s{…}`
    /// specials (shift, backspace, spacers) are dropped.
    private func russianLayer(_ name: String) throws -> [[String]] {
        let lines = try file("rus-3-rows.yaml").components(separatedBy: "\n")
        guard let primary = lines.firstIndex(of: "  primary:"),
              let start = lines[primary...].firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "\(name): |" }) else {
            XCTFail("layer \(name) not found"); return []
        }
        let indent = lines[start].prefix(while: { $0 == " " }).count
        var rows: [[String]] = []
        for line in lines[(start + 1)...] {
            let lineIndent = line.prefix(while: { $0 == " " }).count
            if line.trimmingCharacters(in: .whitespaces).isEmpty || lineIndent <= indent { break }
            rows.append(line.split(separator: " ").map(String.init).filter { !$0.hasPrefix("\\s{") })
        }
        return rows
    }

    // MARK: - Letter rows

    func testLetterRows() {
        XCTAssertEqual(spec.letterRows.map(characters), [
            ["й", "ц", "у", "к", "е", "н", "г", "ш", "ъ", "з", "х"],
            ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
            ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
        ])
        XCTAssertEqual(spec.letterRows.count, 3)
        // Shift and backspace frame the third row
        XCTAssertEqual(spec.letterRows[2].first, .shift)
        XCTAssertEqual(spec.letterRows[2].last, .backspace)
        // No letter twice, no row wider than the Russian keyboard's 11 keys
        XCTAssertEqual(Set(letterKeys).count, letterKeys.count)
        XCTAssertEqual(spec.letterRows.map { characters($0).count }, [11, 11, 9])
        // Every key is one lowercase Cyrillic character
        for key in letterKeys {
            XCTAssertEqual(key.unicodeScalars.count, 1, key)
            XCTAssertTrue(Kumyk.isPlainCyrillic(key), key)
            XCTAssertEqual(key, key.lowercased(), key)
        }
    }

    /// The layout is the Russian iOS layout with exactly one key changed:
    /// «ъ» where the Russian keyboard has «щ».
    func testOnlyOneKeyDiffersFromTheRussianLayout() throws {
        let russian = try russianLayer("default")
        XCTAssertEqual(russian.map(\.count), [11, 11, 9])
        let kumyk = spec.letterRows.map(characters)
        var differences: [(String, String)] = []
        for (r, row) in russian.enumerated() {
            for (i, key) in row.enumerated() where kumyk[r][i] != key {
                differences.append((key, kumyk[r][i]))
            }
        }
        XCTAssertEqual(differences.count, 1)
        XCTAssertEqual(differences.first?.0, "щ")
        XCTAssertEqual(differences.first?.1, "ъ")
        // «ъ» sits in the top row two keys right of «г»
        XCTAssertEqual(kumyk[0].firstIndex(of: "ъ"), 8)
        XCTAssertEqual(kumyk[0].firstIndex(of: "г"), 6)
        XCTAssertEqual(kumyk[0].firstIndex(of: "к"), 3)
    }

    /// The shift layer the engine derives equals the Russian shift layer
    /// with the same one change.
    func testShiftLayer() throws {
        let upstream = try russianLayer("shift")
        let shifted = spec.letterRows.map { row in
            characters(row).map { KeyboardLayout.label(for: .character($0), shifted: true, capsLock: false) }
        }
        XCTAssertEqual(shifted, upstream.map { $0.map { $0 == "Щ" ? "Ъ" : $0 } })
    }

    // MARK: - Number and symbol pages

    /// The pages of the Russian iOS keyboard, unchanged. The transcription
    /// writes the typographic “ and ’; the keyboard types the plain " and '
    /// like the sibling keyboards and offers the typographic ones on a
    /// long press.
    func testNumberAndSymbolPagesAreTheRussianOnes() throws {
        func plain(_ rows: [[String]]) -> [[String]] {
            rows.map { $0.map { $0 == "“" ? "\"" : $0 == "’" ? "'" : $0 } }
        }
        XCTAssertEqual(spec.numberRows.map(characters), plain(try russianLayer("symbols-1")))
        XCTAssertEqual(spec.symbolRows.map(characters), plain(try russianLayer("symbols-2")))
        XCTAssertEqual(spec.numberRows[2].first, .symbols)
        XCTAssertEqual(spec.symbolRows[2].first, .numbers)
        XCTAssertEqual(spec.numberRows[2].last, .backspace)
    }

    // MARK: - Long press

    func testLongPressMappings() {
        let letters: [String: [String]] = [
            "г": ["гъ", "гь"],
            "к": ["къ"],
            "н": ["нг"],
            "о": ["оь"],
            "у": ["уь"],
            "е": ["ё"],
            "ш": ["щ"],
            "ь": ["ъ"],
        ]
        for (key, alternates) in letters {
            XCTAssertEqual(spec.callouts[key], alternates, key)
        }
        // No other letter key has a long press
        let letterCalloutKeys = spec.callouts.keys.filter { $0.first!.isLetter }
        XCTAssertEqual(Set(letterCalloutKeys), Set(letters.keys))
        // Every long-press base is a key of the layout, and no option
        // repeats its base key or another option
        let allKeys = Set((spec.letterRows + spec.numberRows + spec.symbolRows).flatMap(characters))
        for (key, alternates) in spec.callouts {
            XCTAssertTrue(allKeys.contains(key), "\(key) is not a key")
            XCTAssertFalse(alternates.contains(key), key)
            XCTAssertEqual(Set(alternates).count, alternates.count, key)
        }
    }

    /// Each digraph option is exactly two plain Cyrillic characters that
    /// start with its base key: a sequence, never a single code point, a
    /// Latin lookalike or a palochka.
    func testDigraphOptionsAreCyrillicSequences() {
        var offered: [String] = []
        for (key, alternates) in KumykLayout.digraphCallouts {
            for option in alternates {
                XCTAssertEqual(option.unicodeScalars.count, 2, option)
                XCTAssertEqual(option.count, 2, option)
                XCTAssertTrue(option.hasPrefix(key), option)
                XCTAssertTrue(Kumyk.isPlainCyrillic(option), option)
                XCTAssertEqual(option, option.precomposedStringWithCanonicalMapping, option)
                offered.append(option)
            }
        }
        XCTAssertEqual(offered.sorted(), Kumyk.digraphs.sorted())
        XCTAssertEqual(Array("гъ".unicodeScalars).map(\.value), [0x0433, 0x044A])
        XCTAssertEqual(Array("гь".unicodeScalars).map(\.value), [0x0433, 0x044C])
        XCTAssertEqual(Array("къ".unicodeScalars).map(\.value), [0x043A, 0x044A])
        XCTAssertEqual(Array("нг".unicodeScalars).map(\.value), [0x043D, 0x0433])
        XCTAssertEqual(Array("оь".unicodeScalars).map(\.value), [0x043E, 0x044C])
        XCTAssertEqual(Array("уь".unicodeScalars).map(\.value), [0x0443, 0x044C])
    }

    /// The digraphs sit under the same Russian keys, in the same order, as
    /// in the Kumyk mapping of Agisight/rf-keyboard-corpora.
    func testDigraphAssignmentMatchesThePinnedKumykMapping() throws {
        let data = try Data(contentsOf: RepoPaths.upstream.appendingPathComponent("kum_key_mapping_ext.json"))
        let upstream = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String]])
        XCTAssertEqual(upstream.count, 5)
        var lowercased: [String: [String]] = [:]
        for (key, values) in upstream { lowercased[key.lowercased()] = values.map { $0.lowercased() } }
        XCTAssertEqual(KumykLayout.digraphCallouts, lowercased)
    }

    /// The symbol alternates are those of the Russian iOS keyboard.
    func testSymbolLongPressesAreTheRussianOnes() throws {
        var upstream: [String: [String]] = [:]
        for line in try file("rus-longpress.yaml").components(separatedBy: "\n") {
            guard let colon = line.range(of: ": ") else { continue }
            func unquote(_ s: Substring) -> String {
                let t = s.trimmingCharacters(in: .whitespaces)
                if t.count >= 2, let f = t.first, f == t.last, f == "'" || f == "\"" {
                    return String(t.dropFirst().dropLast())
                }
                return t
            }
            upstream[unquote(line[..<colon.lowerBound])] =
                unquote(line[colon.upperBound...]).split(separator: " ").map(String.init)
        }
        // Letters are Kumyk's own (е → ё is shared; ь → ъ is kept too)
        XCTAssertEqual(upstream["е"], spec.callouts["е"])
        XCTAssertEqual(upstream["ь"], spec.callouts["ь"])
        for key in ["0", "₽", "#", ".", "%", "=", "-", "/", "&", "?", "!"] {
            XCTAssertEqual(spec.callouts[key], upstream[key], key)
        }
        // The quote alternates sit on this layout's ' and " keys; the
        // popup never repeats its base key
        XCTAssertEqual(spec.callouts["'"], upstream["’"]?.filter { $0 != "'" })
        XCTAssertEqual(spec.callouts["\""], upstream["“"]?.filter { $0 != "\"" })
    }

    // MARK: - Alphabet

    /// All 39 letters of the Kumyk alphabet (the 33 Russian letters and
    /// the six digraphs) can be typed: from the keys, or one long press
    /// away.
    func testWholeAlphabetIsTypeable() {
        let alphabet = ["а", "б", "в", "г", "гъ", "гь", "д", "е", "ё", "ж", "з", "и", "й", "к", "къ",
                        "л", "м", "н", "нг", "о", "оь", "п", "р", "с", "т", "у", "уь", "ф", "х", "ц",
                        "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я"]
        XCTAssertEqual(alphabet.count, 39)
        let keys = Set(letterKeys)
        let longPress = Set(spec.callouts.filter { keys.contains($0.key) }.flatMap(\.value))
        for letter in alphabet {
            let fromKeys = letter.allSatisfy { keys.contains(String($0)) }
            XCTAssertTrue(fromKeys || longPress.contains(letter), "\(letter) cannot be typed")
        }
        // Every digraph both ways: key by key, and as one long press
        for digraph in Kumyk.digraphs {
            XCTAssertTrue(digraph.allSatisfy { keys.contains(String($0)) }, digraph)
            XCTAssertTrue(longPress.contains(digraph), digraph)
        }
        // The only letters without a key of their own
        let russian = Set("абвгдеёжзийклмнопрстуфхцчшщъыьэюя".map(String.init))
        XCTAssertEqual(russian.subtracting(keys), ["ё", "щ"])
        XCTAssertTrue(longPress.isSuperset(of: ["ё", "щ"]))
    }

    // MARK: - The evidence, from the shipped dictionary

    /// The layout rests on measured frequencies (docs/LAYOUT.md). The
    /// claims are checked against the shipped dictionary, so a future
    /// dictionary that no longer supports them fails here.
    func testCorpusFrequenciesSupportTheLayout() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var characters: [Character: Int] = [:]
        var pairs: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = Array(String(cString: sqlite3_column_text(stmt, 0)))
            let count = Int(sqlite3_column_int64(stmt, 1)) / 10
            guard count > 0 else { continue }
            for (i, ch) in word.enumerated() where ch != "-" {
                characters[ch, default: 0] += count
                if i > 0 { pairs[String([word[i - 1], ch]), default: 0] += count }
            }
        }
        sqlite3_finalize(stmt)
        let total = Double(characters.values.reduce(0, +))
        func share(_ ch: Character) -> Double { 100 * Double(characters[ch] ?? 0) / total }

        // «ъ» is a frequent letter, «щ» a very rare one
        XCTAssertEqual(share("ъ"), 3.84, accuracy: 0.05)
        XCTAssertLessThan(share("щ"), 0.02)
        XCTAssertGreaterThan(share("ъ"), share("у"))
        XCTAssertGreaterThan(share("ъ"), share("к"))
        // …and almost always part of «къ» or «гъ»
        let hard = Double(characters["ъ"]!)
        XCTAssertGreaterThan(Double(pairs["къ"]! + pairs["гъ"]!) / hard, 0.97)
        // Long-press order under «г»: «гъ» before «гь»
        XCTAssertGreaterThan(pairs["гъ"]!, 2 * pairs["гь"]!)
        // Digraph frequency order
        XCTAssertGreaterThan(pairs["къ"]!, pairs["гъ"]!)
        XCTAssertGreaterThan(pairs["гь"]!, pairs["нг"]!)
        XCTAssertGreaterThan(pairs["нг"]!, pairs["оь"]!)
        XCTAssertGreaterThan(pairs["оь"]!, pairs["уь"]!)
        // «ё» stays on a long press: more frequent than ц and ф, but an
        // order of magnitude below «ъ»
        XCTAssertEqual(share("ё"), 0.56, accuracy: 0.03)
        XCTAssertLessThan(share("ц"), 0.15)
        XCTAssertLessThan(share("ф"), 0.15)
    }
}

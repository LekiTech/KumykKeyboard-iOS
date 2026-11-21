//
//  DictionaryTests.swift
//  KumykCoreTests
//
//  The SHIPPED artifacts (KumykKeyboardExtension/kumyk_words.sqlite and
//  kumyk_bigrams.sqlite, built by scripts/build_dictionary.py) through the
//  engine's readers: metadata, counts, the canonical form of every lookup
//  key, prefix suggestions ranked by frequency, next words from real
//  bigrams, and the cleanup merges. The figures are those of cleanup
//  version 1 (docs/DICTIONARY.md).
//

import XCTest
import SQLite3
@testable import KumykCore
@testable import GeneralKeyboard

final class DictionaryTests: KumykTestCase {

    private var words: WordSuggestions!
    private var bigrams: StaticBigrams!

    override func setUpWithError() throws {
        try super.setUpWithError()
        words = try XCTUnwrap(WordSuggestions(databaseURL: RepoPaths.wordsArtifact))
        bigrams = try XCTUnwrap(StaticBigrams(databaseURL: RepoPaths.bigramsArtifact))
    }

    private func meta(_ url: URL) throws -> [String: String] {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT key, value FROM meta", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var values: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            values[String(cString: sqlite3_column_text(stmt, 0))] = String(cString: sqlite3_column_text(stmt, 1))
        }
        return values
    }

    func testArtifactMetadata() throws {
        let w = try XCTUnwrap(words.metadata)
        XCTAssertEqual(w.artifact, "kumyk_words")
        XCTAssertEqual(w.schemaVersion, 1)
        XCTAssertEqual(w.contentVersion, 1)
        XCTAssertEqual(w.normalizationVersion, Normalization.version)
        XCTAssertEqual(w.minReaderSchema, 1)
        XCTAssertEqual(w.rowCount, 38956)
        let b = try XCTUnwrap(bigrams.metadata)
        XCTAssertEqual(b.artifact, "kumyk_bigrams")
        XCTAssertEqual(b.rowCount, 43995)
        XCTAssertEqual(b.normalizationVersion, Normalization.version)
        XCTAssertFalse(bigrams.isEmpty)
        // Both artifacts name the profile they are canonical under
        for url in [RepoPaths.wordsArtifact, RepoPaths.bigramsArtifact] {
            let values = try meta(url)
            XCTAssertEqual(values["normalization_profile"], KeyboardDefinition.current.normalization.id)
            XCTAssertEqual(values["language"], "kum")
            XCTAssertEqual(values["cleanup_version"], "1")
        }
    }

    /// Every stored key is already canonical (lowercase, NFC), valid under
    /// the token contract and written with Kumyk letters only, and every
    /// bigram word is a row of the words artifact, so a lookup never
    /// misses by representation.
    func testEveryRowIsCanonicalAndValid() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var all = Set<String>()
        var minScore = Int.max
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            minScore = min(minScore, Int(sqlite3_column_int64(stmt, 1)))
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
            XCTAssertTrue(Kumyk.isPlainCyrillic(word.replacingOccurrences(of: "-", with: "")), word)
            all.insert(word)
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(all.count, 38956)
        XCTAssertGreaterThanOrEqual(minScore, 1)

        var bdb: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.bigramsArtifact.path, &bdb, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(bdb) }
        XCTAssertEqual(sqlite3_prepare_v2(bdb, "SELECT prev, word, weight FROM bigrams", -1, &stmt, nil), SQLITE_OK)
        var pairs = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let prev = String(cString: sqlite3_column_text(stmt, 0))
            let word = String(cString: sqlite3_column_text(stmt, 1))
            XCTAssertTrue(all.contains(prev), prev)
            XCTAssertTrue(all.contains(word), word)
            XCTAssertGreaterThanOrEqual(sqlite3_column_int64(stmt, 2), 2)
            pairs += 1
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(pairs, 43995)
    }

    /// Frequency ranks the prefix candidates, for prefixes that end inside
    /// or right after each digraph.
    func testPrefixSuggestionsAreRankedByFrequency() {
        XCTAssertEqual(words.suggestions(for: "къ"), ["къумукъ", "къайры", "къаршы"])
        XCTAssertEqual(words.suggestions(for: "къум"), ["къумукъ", "къумукъланы", "къумукълар"])
        XCTAssertEqual(words.suggestions(for: "гь"), ["гьар", "гьали", "гьакъында"])
        XCTAssertEqual(words.suggestions(for: "оь"), ["оьзюню", "оьзге", "оьзлени"])
        XCTAssertEqual(words.suggestions(for: "уь"), ["уьч", "уьлкени", "уьстюнде"])
        XCTAssertEqual(words.suggestions(for: "сонг"), ["сонг", "сонггъу", "сонггъа"])
        XCTAssertEqual(words.suggestions(for: "бол"), ["болгъан", "болуп", "бола"])
        XCTAssertEqual(words.suggestions(for: "ё"), ["ёкъ", "ёлдаш", "ёл"])
        XCTAssertEqual(words.suggestions(for: "халкъ"), ["халкъ", "халкъны", "халкъара"])
        XCTAssertEqual(words.suggestions(for: "ъъъ"), [])
    }

    /// A prefix in capitals, with a Latin lookalike or in decomposed
    /// Unicode reaches the same rows.
    func testPrefixLookupNormalizes() {
        let canonical = words.suggestions(for: "къум")
        XCTAssertEqual(words.suggestions(for: "Къум"), canonical)
        XCTAssertEqual(words.suggestions(for: "КЪУМ"), canonical)
        XCTAssertEqual(words.suggestions(for: "къyм"), canonical)                   // Latin y
        XCTAssertEqual(words.suggestions(for: "е\u{0308}"), words.suggestions(for: "ё"))
        XCTAssertTrue(words.contains("Къумукъ"))
        XCTAssertTrue(words.contains("ГЬАКЪЫНДА"))
        XCTAssertTrue(words.contains("оьзюню"))
        // ё and е are different letters: «ёл» road, «ел» wind
        XCTAssertNotEqual(words.suggestions(for: "ёл"), words.suggestions(for: "ел"))
        XCTAssertTrue(words.contains("ёл"))
        XCTAssertTrue(words.contains("ел"))
    }

    /// The cleanup merged the mechanical artifacts into their attested
    /// forms and invented nothing.
    func testMergedArtifactsAreGone() {
        // S1: OCR «кь» for «къ»
        XCTAssertFalse(words.contains("халкь"))
        XCTAssertTrue(words.contains("халкъ"))
        // S2: two signs in a row
        XCTAssertFalse(words.contains("кьъаршы"))
        XCTAssertTrue(words.contains("къаршы"))
        // H1: the hyphen the frequency list stripped
        XCTAssertFalse(words.contains("айрыайры"))
        XCTAssertTrue(words.contains("айры-айры"))
        XCTAssertFalse(words.contains("бирбир"))
        XCTAssertTrue(words.contains("бир-бир"))
        XCTAssertFalse(words.contains("санктпетербург"))
        XCTAssertTrue(words.contains("санкт-петербург"))
        // Not merged: the joined spelling is the usual one in running text
        XCTAssertTrue(words.contains("гьажимурат"))
        XCTAssertTrue(words.contains("гьажи-мурат"))
        // Not merged: the repaired form is not attested, or two are
        XCTAssertTrue(words.contains("вкь"))
        XCTAssertFalse(words.contains("вкъ"))
        XCTAssertTrue(words.contains("огьъар"))
        // A hyphenated word is offered from the part before the hyphen
        XCTAssertEqual(words.suggestions(for: "бир-"), ["бир-бир", "бир-бирине", "бир-бирде"])
    }

    func testNextWordsComeFromRealBigrams() {
        XCTAssertEqual(bigrams.nextWords(after: "бары"), ["да", "халкъ", "дазатны"])
        XCTAssertEqual(bigrams.nextWords(after: "гьар"), ["тюрлю", "гюн", "заман"])
        XCTAssertEqual(bigrams.nextWords(after: "ондан"), ["къайры", "сонг", "да"])
        XCTAssertEqual(bigrams.nextWords(after: "бир"), ["де", "нече", "зат"])
        XCTAssertEqual(bigrams.nextWords(after: "ана"), ["тиллени", "тилин", "тилден"])
        XCTAssertEqual(bigrams.nextWords(after: "ГьаР"), ["тюрлю", "гюн", "заман"])
        XCTAssertEqual(bigrams.nextWords(after: "ъъъ"), [])
        // Static context reorders dictionary candidates among themselves
        let weights = bigrams.weights(after: "гьар", candidates: ["йыл", "тюрлю", "ъъъ"])
        XCTAssertEqual(weights, ["тюрлю": 470, "йыл": 46])
    }

    func testRandomIdleWordsComeFromTheDictionary() {
        let idle = words.randomWords(3)
        XCTAssertEqual(idle.count, 3)
        for word in idle { XCTAssertTrue(words.contains(word), word) }
    }
}

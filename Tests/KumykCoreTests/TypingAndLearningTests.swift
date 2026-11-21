//
//  TypingAndLearningTests.swift
//  KumykCoreTests
//
//  The keyboard model built exactly as the extension builds it (its own
//  UserDefaults, its own learned store), fed through a mock host: the keys
//  and the long-press options insert Kumyk digraphs as Cyrillic sequences
//  in lowercase, title case and uppercase, typed and picked words are
//  learned and come back, settings persist. The bundled artifacts are not
//  in the test bundle, so the model's dictionary tier is empty here; the
//  dictionary itself is covered by DictionaryTests. Every word is a real
//  word of the Kumyk dictionary.
//

import XCTest
import UIKit
@testable import KumykCore
@testable import GeneralKeyboard

final class TypingAndLearningTests: KumykTestCase {

    private static let persistedKeys = [
        "layoutStyle", "recentEmojis",
        "set_wordSuggestions", "set_nextWordSuggestions", "set_autoSpaceAfterSuggestion",
        "set_doubleSpacePeriod", "set_spaceCursor", "set_spaceLabel",
        "set_learnSpeed", "set_calloutDelay", "set_theme",
    ]

    override func setUp() {
        super.setUp()
        for key in Self.persistedKeys { UserDefaults.standard.removeObject(forKey: key) }
        // Empty the learned store IN PLACE; never delete learned.sqlite
        // while a model may still hold it open.
        LearnedWords()?.reset()
    }

    @MainActor
    private func type(_ text: String, into model: KeyboardModel, proxy: MockTextDocumentProxy) {
        for ch in text {
            model.handleKey(ch == " " ? .space : .character(String(ch)), proxy: proxy)
            model.updateSuggestions(proxy: proxy)
        }
    }

    /// What the keyboard does when a suggestion is tapped: the typed
    /// prefix is replaced by the word and a space, and the model is told.
    @MainActor
    private func pick(_ word: String, in model: KeyboardModel, proxy: MockTextDocumentProxy) {
        let previous = model.previousWord(proxy: proxy)
        for _ in 0..<model.wordPrefix(proxy: proxy).count { proxy.deleteBackward() }
        proxy.insertText(word + " ")
        model.recordPickedSuggestion(word, previous: previous, insertedSpace: true)
        model.updateSuggestions(proxy: proxy)
    }

    // MARK: - Rows

    @MainActor
    func testKeyboardShowsThreeLetterRowsAndTheBottomRow() {
        let model = KeyboardModel()
        let rows = model.rows(needsGlobe: true)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].count, 11)
        XCTAssertEqual(rows[1].count, 11)
        XCTAssertEqual(rows[2].count, 11)   // shift, nine letters, backspace
        XCTAssertEqual(rows[0][8], .character("ъ"))
        XCTAssertEqual(rows[3], [.numbers, .settings, .emoji, .globe, .space, .return])
        XCTAssertEqual(model.rows(needsGlobe: false)[3], [.numbers, .settings, .emoji, .space, .return])
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Keys and digraphs

    @MainActor
    func testEveryLetterKeyInsertsItsLetter() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let letters = "йцукенгшъзхфывапролджэячсмитьбю"
        for ch in letters { model.handleKey(.character(String(ch)), proxy: proxy) }
        XCTAssertEqual(proxy.before, letters)
        XCTAssertFalse(proxy.before.contains(where: Kumyk.palochkas.contains))
    }

    /// The six digraphs typed key by key, as Cyrillic sequences.
    @MainActor
    func testDigraphsTypedKeyByKey() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("гъ гь къ нг оь уь", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "гъ гь къ нг оь уь")
        XCTAssertEqual(Array("къ".unicodeScalars).map(\.value), [0x043A, 0x044A])
        XCTAssertTrue(Kumyk.isPlainCyrillic(proxy.before.replacingOccurrences(of: " ", with: "")))
    }

    /// A long-press option inserts the complete digraph; the result is the
    /// same string as typing its two keys.
    @MainActor
    func testLongPressOptionsInsertWholeDigraphs() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        for option in ["гъ", "гь", "къ", "нг", "оь", "уь", "ё", "щ", "ъ"] {
            model.handleKey(.character(option), proxy: proxy)
        }
        XCTAssertEqual(proxy.before, "гъгькънгоьуьёщъ")
        XCTAssertEqual(Array(proxy.before.unicodeScalars).count, 15)
        XCTAssertTrue(Kumyk.isPlainCyrillic(proxy.before))

        let typed = MockTextDocumentProxy()
        for ch in "гъгькънгоьуь" { model.handleKey(.character(String(ch)), proxy: typed) }
        XCTAssertEqual(Array(typed.before.unicodeScalars), Array("гъгькънгоьуь".unicodeScalars))
        XCTAssertTrue(proxy.before.hasPrefix(typed.before))
    }

    /// Shift capitalizes the first letter of a digraph («Гъ», «Оь»), Caps
    /// Lock all of it («ГЪ», «ОЬ»), for long-press options and plain keys
    /// alike.
    @MainActor
    func testShiftAndCapsLockOnDigraphs() {
        let model = KeyboardModel()
        let titleCase = ["гъ": "Гъ", "гь": "Гь", "къ": "Къ", "нг": "Нг", "оь": "Оь", "уь": "Уь", "ё": "Ё", "щ": "Щ"]
        let upperCase = ["гъ": "ГЪ", "гь": "ГЬ", "къ": "КЪ", "нг": "НГ", "оь": "ОЬ", "уь": "УЬ", "ё": "Ё", "щ": "Щ"]
        for (option, expected) in titleCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .once
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .off)
            // The key label previews exactly what a tap inserts
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: false), expected)
        }
        for (option, expected) in upperCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .capsLock
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .capsLock)
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: true), expected)
        }
        // Key by key: Shift, к, ъ → «Къ»; Caps Lock, к, ъ → «КЪ»
        let proxy = MockTextDocumentProxy()
        model.shiftState = .once
        type("къумукъ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Къумукъ")
        proxy.before = ""
        model.shiftState = .capsLock
        type("къумукъ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КЪУМУКЪ")
        model.shiftState = .off
    }

    @MainActor
    func testSentenceStartShiftsAndSpaceBehaviour() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        XCTAssertEqual(model.shiftState, .once)   // new field: auto-capitalized
        type("оьзю", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Оьзю")
        model.handleKey(.space, proxy: proxy)
        XCTAssertEqual(proxy.before, "Оьзю ")
        XCTAssertEqual(model.composedWord, "")
        // A long-press digraph at the start of a sentence is title case
        let fresh = MockTextDocumentProxy()
        let again = KeyboardModel()
        again.handleKey(.character("гь"), proxy: fresh)
        type("ар", into: again, proxy: fresh)
        XCTAssertEqual(fresh.before, "Гьар")
    }

    // MARK: - Learning

    @MainActor
    func testTypedWordIsLearnedAndSuggested() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("къумукъча ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "къумукъча ")
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("къумукъча"))
        XCTAssertTrue(store.isRecognized("Къумукъча"))
        XCTAssertTrue(store.isRecognized("КЪУМУКЪЧА"))
        XCTAssertEqual(store.topWords(limit: 5), ["къумукъча"])
        // Suggested back while typing its prefix. The bar leads with the
        // typed prefix as a quoted literal (it is not a word of its own),
        // the learned word follows.
        type("къум", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["къум", "къумукъча"])
        XCTAssertTrue(model.isLearnedSuggestion("къумукъча"))
        XCTAssertEqual(model.savedWords(), ["къумукъча"])
    }

    /// A capitalized prefix capitalizes the suggestion's first letter only:
    /// «Къ…» is a title-case digraph, not an all-caps prefix.
    @MainActor
    func testSuggestionFollowsTheCaseOfADigraphPrefix() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("гьакъында оьзюню ", into: model, proxy: proxy)
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("гьа", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Гьа")
        XCTAssertTrue(model.suggestions.contains("Гьакъында"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .capsLock
        type("оьз", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ОЬЗ")
        XCTAssertTrue(model.suggestions.contains("ОЬЗЮНЮ"), "\(model.suggestions)")
        model.shiftState = .off
    }

    /// Tapping a suggestion replaces the prefix with the whole word, with
    /// its digraphs intact, and adds the space.
    @MainActor
    func testAcceptedSuggestionInsertsTheWholeWord() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("гьакъында ", into: model, proxy: proxy)
        type("гьа", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["гьа", "гьакъында"])
        pick("гьакъында", in: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "гьакъында гьакъында ")
        XCTAssertEqual(model.composedWord, "")
        // The pick itself counts as a stronger use than typing
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("гьакъында"))
        // Sentence punctuation right after a picked word swallows the
        // automatic space
        model.handleKey(.character("."), proxy: proxy)
        XCTAssertEqual(proxy.before, "гьакъында гьакъында.")
    }

    @MainActor
    func testLearnedWordsSurviveANewModel() {
        do {
            let model = KeyboardModel()
            let proxy = MockTextDocumentProxy()
            model.shiftState = .off
            type("халкъны оьзюню ", into: model, proxy: proxy)
        }
        // A new keyboard controller (new model, same container)
        let again = KeyboardModel()
        let proxy = MockTextDocumentProxy(before: "халкъны ")
        again.shiftState = .off
        again.syncComposedWord(proxy: proxy)
        XCTAssertEqual(again.savedWords().sorted(), ["оьзюню", "халкъны"])
        type("оьз", into: again, proxy: proxy)
        XCTAssertEqual(again.suggestions, ["оьз", "оьзюню"])
    }

    @MainActor
    func testPersonalBigramPredictsTheNextWord() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        // A pair seen twice is confident enough to predict (minPairUses)
        type("ана тил ", into: model, proxy: proxy)
        type("ана тил ", into: model, proxy: proxy)
        // After the first word and a space, its learned follower leads the bar
        type("ана ", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions.first, "тил")
    }

    @MainActor
    func testDeletingALearnedWordRemovesIt() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("уьлкени сонггъу ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords().sorted(), ["сонггъу", "уьлкени"])
        model.deleteLearnedWord("уьлкени", proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["сонггъу"])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("уьлкени"))
        model.resetLearnedWords(proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("сонггъу"))
    }

    /// A lone digraph or a lone letter is not a word; the store refuses it.
    @MainActor
    func testSingleLettersAndLoneDigraphsAreNotLearned() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("гъ къ оь а ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertFalse(store.isRecognized("къ"))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsPersistAcrossModels() {
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .fast)
        XCTAssertEqual(model.settings.theme, .system)
        model.updateSettings {
            $0.theme = .dark
            $0.learnSpeed = .conservative
            $0.calloutDelay = .long
            $0.nextWordSuggestions = false
        }
        let again = KeyboardModel()
        XCTAssertEqual(again.settings.theme, .dark)
        XCTAssertEqual(again.settings.learnSpeed, .conservative)
        XCTAssertEqual(again.settings.calloutDelay, .long)
        XCTAssertFalse(again.settings.nextWordSuggestions)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "set_theme"), "dark")
        XCTAssertEqual(model.layoutStyle, .standard)
    }
}

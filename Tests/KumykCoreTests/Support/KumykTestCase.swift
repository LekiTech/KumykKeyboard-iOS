//
//  KumykTestCase.swift
//  KumykCoreTests
//
//  Base class for every test that touches the engine: installs the Kumyk
//  definition before the engine's statics capture it, exactly as the
//  extension's principal class does. Also the repository paths the tests
//  read (the shipped artifacts, the pinned upstream files, the project).
//

import XCTest
import UIKit
@testable import KumykCore
@testable import GeneralKeyboard

class KumykTestCase: XCTestCase {
    override class func setUp() {
        super.setUp()
        KeyboardDefinition.install(KumykDefinition.definition)
    }
}

enum RepoPaths {
    /// The repository root, from this file's location
    /// (Tests/KumykCoreTests/Support/KumykTestCase.swift).
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Support
        .deletingLastPathComponent()   // KumykCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repository root

    static let extensionFolder = root.appendingPathComponent("KumykKeyboard/KumykKeyboardExtension")
    static let wordsArtifact = extensionFolder.appendingPathComponent("kumyk_words.sqlite")
    static let bigramsArtifact = extensionFolder.appendingPathComponent("kumyk_bigrams.sqlite")
    static let upstream = root.appendingPathComponent("Tests/KumykCoreTests/Fixtures/agisight")
    static let project = root.appendingPathComponent("KumykKeyboard/KumykKeyboard.xcodeproj/project.pbxproj")

    static func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

/// The six digraph letters of the Kumyk alphabet and the characters that
/// must never appear in Kumyk text produced by this keyboard.
enum Kumyk {
    static let digraphs = ["гъ", "гь", "къ", "нг", "оь", "уь"]
    /// Ӏ U+04C0 and ӏ U+04CF: Avar, Lezgi and Dargwa letters, not Kumyk.
    static let palochkas: Set<Character> = ["\u{04C0}", "\u{04CF}"]

    static func isPlainCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451 }
    }
}

/// A minimal host text field: the context before the cursor is all the
/// suggestion and capitalization logic reads (same as General Keyboard's
/// test double).
final class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
    var before: String
    init(before: String = "") { self.before = before }

    var documentContextBeforeInput: String? { before }
    var documentContextAfterInput: String? { nil }
    var selectedText: String? { nil }
    var documentInputMode: UITextInputMode? { nil }
    var documentIdentifier: UUID { UUID() }
    var hasText: Bool { !before.isEmpty }
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var returnKeyType: UIReturnKeyType = .default

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) { before += text }
    func deleteBackward() { if !before.isEmpty { before.removeLast() } }
}

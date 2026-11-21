//
//  KumykDefinitionTests.swift
//  KumykCoreTests
//
//  The Kumyk KeyboardDefinition: its own identity (never another product's),
//  the persisted contract, a normalization profile without the palochka
//  convention of the sibling keyboards, and the project's two-target,
//  two-identity setup (Debug for the developer's team, Release for
//  distribution).
//

import XCTest
import UIKit
@testable import KumykCore
@testable import GeneralKeyboard

final class KumykDefinitionTests: KumykTestCase {

    private var d: KeyboardDefinition { KeyboardDefinition.current }

    func testIdentityAndArtifacts() {
        XCTAssertEqual(d.validationErrors(), [])
        XCTAssertEqual(d.id, "org.lekitech.kumykkeyboard.KumykKeyboardExtension")
        XCTAssertEqual(KumykIdentity.releaseAppGroupID, "group.org.lekitech.kumykkeyboard")
        XCTAssertEqual(KumykIdentity.debugAppGroupID, "group.org.lekitech.kumykkeyboard.dev")
        // Tests build in Debug
        XCTAssertEqual(d.data.appGroupID, KumykIdentity.debugAppGroupID)
        XCTAssertEqual(WordSuggestions.artifactName, "kumyk_words")
        XCTAssertEqual(StaticBigrams.artifactName, "kumyk_bigrams")
        XCTAssertEqual(d.data.diagnosticsSubsystem, "KumykKeyboardExtension")
    }

    func testNeverReusesAnotherProductsIdentity() {
        let taken = ["lezgi", "avar", "dargwa", "vadivian", "generalkeyboard", "reference"]
        for value in [d.id, d.data.appGroupID, KumykIdentity.releaseAppGroupID,
                      d.data.wordsArtifact, d.data.bigramsArtifact, d.normalization.id] {
            for other in taken {
                XCTAssertFalse(value.lowercased().contains(other), "\(value) contains \(other)")
            }
        }
    }

    // MARK: - Normalization

    /// Kumyk has its own profile: no palochka, so nothing is ever repaired
    /// into one, and «ъ» «ь» are the only digraph tails.
    func testNormalizationProfileIsKumyksOwn() {
        let n = d.normalization
        XCTAssertEqual(n.id, "kumyk-cyrillic")
        XCTAssertEqual(n.version, 1)
        XCTAssertNotEqual(n, .dagestanianCyrillicV1)
        XCTAssertNil(n.palochka)
        XCTAssertTrue(n.palochkaLookalikes.isEmpty)
        XCTAssertEqual(n.digraphTails, ["ъ", "ь"])
        XCTAssertTrue(n.rejectsASCIILetters)
        XCTAssertEqual(n.homoglyphs, NormalizationProfile.dagestanianCyrillicV1.homoglyphs)
        XCTAssertNil(d.text.visiblePalochka)
        XCTAssertTrue(d.text.caseNeutral.isEmpty)
        XCTAssertNil(Normalization.palochka)
        XCTAssertEqual(Normalization.version, 1)
    }

    func testCanonicalFormOfKumykWords() {
        XCTAssertEqual(Normalization.canonical("Къумукъ"), "къумукъ")
        XCTAssertEqual(Normalization.canonical("  ГЬАР\n"), "гьар")
        XCTAssertEqual(Normalization.canonical("ОЬЗЮНЮ"), "оьзюню")
        // NFC: «й» and «ё» typed as a base letter plus a combining mark
        XCTAssertEqual(Normalization.canonical("и\u{0306}ыл"), "йыл")
        XCTAssertEqual(Normalization.canonical("е\u{0308}л"), "ёл")
        XCTAssertEqual(Array(Normalization.canonical("е\u{0308}л").unicodeScalars).count, 2)
        // Latin twins inside a Cyrillic word are repaired (а, о, р here)
        XCTAssertEqual(Normalization.canonical("бaр"), "бар")
        XCTAssertEqual(Normalization.canonical("бoлгъaн"), "болгъан")
        // ё and е, э and е are different Kumyk letters and stay apart
        XCTAssertNotEqual(Normalization.canonical("ёл"), Normalization.canonical("ел"))
        XCTAssertNotEqual(Normalization.canonical("эл"), Normalization.canonical("ел"))
        for word in ["къумукъ", "гьакъында", "сонг", "оьзюню", "уьч", "ёкъ", "бир-бир"] {
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
        }
    }

    /// The palochka convention of Avar, Lezgi and Dargwa is off: a Latin
    /// I, l or i next to Cyrillic letters is never turned into ӏ, and such
    /// a token is not a valid word.
    func testNoPalochkaRepair() {
        for lookalike in ["I", "l", "i", "1", "|"] {
            let canonical = Normalization.canonical("к" + lookalike + "ала")
            XCTAssertFalse(canonical.contains(where: Kumyk.palochkas.contains), canonical)
        }
        XCTAssertEqual(Normalization.canonical("кIала"), "кiала")
        XCTAssertFalse(Normalization.isValidToken(Normalization.canonical("кIала")))
        XCTAssertFalse(Normalization.isValidToken(Normalization.canonical("кlала")))
    }

    /// «гъ», «гь», «къ», «оь», «уь» are one letter each for the engine;
    /// «нг» is two, because «г» is a letter of its own.
    func testLetterCountOfDigraphs() {
        for digraph in ["гъ", "гь", "къ", "оь", "уь"] {
            XCTAssertEqual(Normalization.letterCount(digraph), 1, digraph)
            XCTAssertFalse(Normalization.isValidToken(digraph), digraph)
        }
        XCTAssertEqual(Normalization.letterCount("нг"), 2)
        XCTAssertEqual(Normalization.letterCount("къумукъ"), 5)   // къ у м у къ
        XCTAssertEqual(Normalization.letterCount("сонг"), 4)
        XCTAssertTrue(Normalization.isValidToken("ёкъ"))
        XCTAssertTrue(Normalization.isValidToken("уьй"))
    }

    // MARK: - Layout capabilities and strings

    func testLayoutCapabilities() {
        XCTAssertEqual(d.layout.styles.map(\.id.rawValue), ["standard"])
        XCTAssertEqual(d.layout.defaultStyle.rawValue, "standard")
        XCTAssertEqual(d.layout.persistenceKey, "layoutStyle")
        XCTAssertFalse(d.layout.showsSelector)
        XCTAssertFalse(d.layout.showsQuickSwitch)
        XCTAssertEqual(d.layout.gridModel, .nativeCells)
        XCTAssertEqual(d.layout.resolve(nil).rawValue, "standard")
        XCTAssertEqual(d.layout.resolve("classic").rawValue, "standard")
        XCTAssertEqual(d.layout.spec(for: .standard).bottomRowAfterSpace, [])
    }

    /// Nothing the user reads or types carries a palochka or a Latin letter
    /// posing as a Kumyk one.
    func testUserFacingTextHasNoPalochka() {
        let s = d.strings
        var texts: [String] = [
            s.deleteWordQuestion("къумукъ"), s.no, s.delete, s.emojiRecents, s.back, s.close,
            s.settingsCaption, s.settingsTitle, s.pageInput, s.pageTheme, s.pageDictionary,
            s.pageAbout, s.sectionLayout, s.sectionSuggestions, s.sectionKeys, s.sectionLearning,
            s.sectionLongPress, s.sectionTheme, s.wordSuggestions, s.nextWordSuggestion,
            s.autoSpace, s.doubleSpacePeriod, s.spaceCursor, s.spaceCornerToggle,
            s.spaceCornerToggleSubtitle, s.learnFast, s.learnNormal, s.learnSlow, s.learnUses(3),
            s.calloutShort, s.calloutNormal, s.calloutLong, s.calloutDuration(0.3), s.themeSystem,
            s.themeLight, s.themeDark, s.learnedWordsCaption, s.noWordsYet, s.deleteAll,
            s.deleteAllQuestion, s.aboutInitial, s.aboutTitle, s.aboutByline("1.0.0"),
            d.keys.space, d.keys.spaceCornerLabel, d.keys.keyboardName, d.keys.lettersKey,
            d.keys.lettersKeyShifted, d.keys.emojiPageLettersKey,
        ]
        texts += d.keys.returnLabels.values
        texts += d.emojiCategoryTitles.values
        let spec = d.layout.spec(for: .standard)
        texts += [spec.settingsTitle, spec.settingsSubtitle]
        for (key, alternates) in spec.callouts { texts += [key] + alternates }
        for text in texts {
            XCTAssertFalse(text.contains(where: Kumyk.palochkas.contains), "\(text) contains a palochka")
        }
        XCTAssertEqual(d.keys.keyboardName, "Къумукъ тил")
        XCTAssertEqual(d.keys.spaceCornerLabel, "КЪУМ")
        XCTAssertTrue(Kumyk.isPlainCyrillic(d.keys.keyboardName.replacingOccurrences(of: " ", with: "")))
    }

    func testRussianFallbackFormatting() {
        let s = d.strings
        XCTAssertEqual(s.learnUses(1), "1 раз")
        XCTAssertEqual(s.learnUses(3), "3 раза")
        XCTAssertEqual(s.learnUses(5), "5 раз")
        XCTAssertEqual(s.learnUses(12), "12 раз")
        XCTAssertEqual(s.learnUses(22), "22 раза")
        XCTAssertEqual(s.calloutDuration(0.2), "0,2 с")
        XCTAssertEqual(s.calloutDuration(0.45), "0,45 с")
        XCTAssertEqual(s.aboutByline("1.0.0"), "Версия 1.0.0 · LekiTech")
    }

    // MARK: - Project

    /// Two targets, no sticker or messenger targets; Debug signs with the
    /// developer's team under `.dev` identifiers, Release carries the App
    /// Store identifiers and no team (the distribution team adds its own).
    func testProjectTargetsAndSigning() throws {
        let pbx = try RepoPaths.text(RepoPaths.project)
        XCTAssertEqual(pbx.components(separatedBy: "isa = PBXNativeTarget;").count - 1, 2)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.application\"").count - 1, 1)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.app-extension\"").count - 1, 1)
        for banned in ["sticker", "Sticker", "messages", "telegram", "whatsapp", "instagram",
                       "Lezgi", "lezgi", "Avar", "avar", "Dargwa", "dargwa", "vadivian"] {
            XCTAssertFalse(pbx.contains(banned), "project mentions \(banned)")
        }
        let bundleIDs = Set(pbx.matches(of: /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(bundleIDs, [
            "org.lekitech.kumykkeyboard.dev", "org.lekitech.kumykkeyboard.dev.KumykKeyboardExtension",
            "org.lekitech.kumykkeyboard", "org.lekitech.kumykkeyboard.KumykKeyboardExtension",
        ])
        let groups = Set(pbx.matches(of: /KUMYK_APP_GROUP_ID = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(groups, [KumykIdentity.debugAppGroupID, KumykIdentity.releaseAppGroupID])
        let teams = pbx.matches(of: /\bDEVELOPMENT_TEAM = ([^;]+);/).map { String($0.1) }
        XCTAssertEqual(teams.sorted(), ["\"\"", "\"\"", "RC94H8KQYA", "RC94H8KQYA"])
        XCTAssertTrue(pbx.contains("relativePath = \"../../GeneralKeyboard-iOS\";"))

        for file in ["KumykKeyboard/KumykKeyboard/KumykKeyboard.entitlements",
                     "KumykKeyboard/KumykKeyboardExtension/KumykKeyboardExtension.entitlements"] {
            let plist = try RepoPaths.text(RepoPaths.root.appendingPathComponent(file))
            XCTAssertTrue(plist.contains("<string>$(KUMYK_APP_GROUP_ID)</string>"), file)
        }
        let info = try RepoPaths.text(RepoPaths.extensionFolder.appendingPathComponent("Info.plist"))
        XCTAssertTrue(info.contains("<string>kum</string>"))
        XCTAssertTrue(info.contains("<key>RequestsOpenAccess</key>\n\t\t\t<false/>"))
    }
}

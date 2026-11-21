//
//  KumykDefinition.swift
//  KumykKeyboardExtension
//
//  The Kumyk keyboard as a KeyboardDefinition: everything Kumyk-specific
//  the General Keyboard engine uses, assembled in one value. The layout
//  lives in KumykLayout.swift, strings and key names in KumykStrings.swift.
//

import Foundation
import GeneralKeyboard

enum KumykDefinition {

    /// Kumyk Cyrillic, version 1: the canonical form of the bundled
    /// dictionary (scripts/build_dictionary.py mirrors it) and of learned
    /// words.
    ///
    /// Kumyk is written with the 33 Russian letters; its six extra letters
    /// are digraphs of those characters (гъ гь къ нг оь уь). It has no
    /// palochka, so unlike the Avar, Lezgi and Dargwa keyboards nothing is
    /// ever repaired into one: a Latin «I» or «l» next to Cyrillic letters
    /// stays what it is and makes the token invalid. The twelve Latin
    /// homoglyphs are repaired inside Cyrillic tokens, as the v0 dictionary
    /// builder did. «ъ» and «ь» extend the previous letter («гъ», «оь» are
    /// one letter each); «нг» counts as two, because «г» is a letter of its
    /// own.
    ///
    /// Identity is (id, version). Changing a rule means a new version, a
    /// dictionary rebuild and a sweep of learned data.
    static let normalization = NormalizationProfile(
        id: "kumyk-cyrillic",
        version: 1,
        repairScripts: [0x0400...0x04FF],
        palochka: nil,
        palochkaLookalikes: [],
        homoglyphs: [
            "a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
            "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н",
        ],
        rejectsASCIILetters: true,
        digraphTails: ["\u{044C}", "\u{044A}"]   // ь ъ
    )

    static let definition = KeyboardDefinition(
        // Stable identity: the extension's App Store bundle identifier.
        // Never reused for a different definition.
        id: "org.lekitech.kumykkeyboard.KumykKeyboardExtension",
        data: LanguageData(
            appGroupID: KumykIdentity.appGroupID,
            // KumykKeyboardExtension/kumyk_words.sqlite and
            // kumyk_bigrams.sqlite, built by scripts/build_dictionary.py
            wordsArtifact: "kumyk_words",
            bigramsArtifact: "kumyk_bigrams",
            diagnosticsSubsystem: "KumykKeyboardExtension"
        ),
        layout: KumykLayout.capabilities,
        keys: KumykStrings.keys,
        text: TextConventions(
            // No palochka: what is stored is what is shown and typed.
            visiblePalochka: nil,
            caseNeutral: []
        ),
        normalization: normalization,
        strings: KumykStrings.strings,
        emojiCategoryTitles: KumykStrings.emojiCategoryTitles
    )
}

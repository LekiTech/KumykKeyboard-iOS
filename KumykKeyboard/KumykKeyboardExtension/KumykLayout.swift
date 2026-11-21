//
//  KumykLayout.swift
//  KumykKeyboardExtension
//
//  The LekiTech Kumyk layout (proposed; not an Apple or otherwise official
//  layout). It is the Russian iOS keyboard with one key changed: the hard
//  sign «ъ» takes the place of «щ», and «щ» moves under a long press on «ш».
//
//  Why: in Kumyk text «ъ» is 3.8 % of all characters (the 11th most
//  frequent, ahead of у, к, о) because of the letters «къ» and «гъ», while
//  «щ» is 0.008 %. On the Russian layout «ъ» needs a long press, which the
//  model puts at 28 long presses per 100 words; here it is 3.6 (almost all
//  of them «ё»). The numbers, the alternatives that were compared and the
//  trade-offs are in docs/LAYOUT.md, computed by scripts/analyze_layout.py.
//
//  The six digraph letters of the Kumyk alphabet are typed with the plain
//  keys (г + ъ, г + ь, к + ъ, н + г, о + ь, у + ь) and are also offered as
//  long-press options that insert both characters at once. Rows are written
//  once, in lowercase; the engine derives the shift layer (first letter:
//  «гъ» → «Гъ») and Caps Lock (all letters: «ГЪ»).
//
//  Product data: the engine reads it only through
//  `KeyboardDefinition.current.layout` (see KumykDefinition.swift).
//

import Foundation
import GeneralKeyboard

extension LayoutStyle {
    /// The one Kumyk layout. Persisted raw value; never rename.
    static let standard = LayoutStyle(rawValue: "standard")
}

enum KumykLayout {

    static let capabilities = LayoutCapabilities(
        styles: [standard],
        defaultStyle: .standard,
        // One style: the engine hides the selector and the quick menu.
        showsStyleSelector: false,
        persistenceKey: "layoutStyle",
        quickSwitchOnSettingsLongPress: false,
        // iPhone portrait on Apple's native keyboard grid (pixel-snapped
        // cells, native bottom-row proportions, native panel height), as
        // approved for Lezgi and Dargwa
        gridModel: .nativeCells
    )

    static let standard = LayoutStyleSpec(
        id: .standard,
        letterRows: letterRows,
        numberRows: numberRows,
        symbolRows: symbolRows,
        callouts: callouts,
        metrics: metrics,
        settingsTitle: "Стандартная",
        settingsSubtitle: "Русская раскладка, ъ на месте щ"
    )

    /// Three letter rows and the geometry Lezgi and Dargwa ship with.
    static let metrics = KeyboardLayout.Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11,
                                                emojiRows: 5, emojiCellHeight: 33)

    // MARK: - Letter rows

    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","ъ","з","х"].map { .character($0) },   // 11 keys, ъ on щ's key
        ["ф","ы","в","а","п","р","о","л","д","ж","э"].map { .character($0) },   // 11 keys, as Russian
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) } // 9 keys, as Russian
            + [.backspace],
    ]

    // MARK: - Number page (the standard Russian iOS set)

    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Symbol page (the standard Russian iOS set)

    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","$","€","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Long-press callouts
    // Keys are lowercase; the popup puts the base key first and the shift
    // state is applied to every option. An option is inserted as a whole
    // string («гъ» = г + ъ, two Cyrillic characters).

    /// The digraph letters of the Kumyk alphabet under their first letter,
    /// in the order of their frequency in the corpus (гъ 1.72 % of letters,
    /// гь 0.79 %). The same assignment as the Kumyk long-press mapping of
    /// Agisight/rf-keyboard-corpora (kum_key_mapping_ext.json).
    static let digraphCallouts: [String: [String]] = [
        "г": ["гъ", "гь"],
        "к": ["къ"],
        "н": ["нг"],
        "о": ["оь"],
        "у": ["уь"],
    ]

    /// Letters without a key, and the Russian keyboard's ь → ъ so that a
    /// habit from that keyboard keeps working.
    static let letterCallouts: [String: [String]] = [
        "е": ["ё"],
        "ш": ["щ"],
        "ь": ["ъ"],
    ]

    /// The symbol alternates of the Russian iOS keyboard (as the sibling
    /// keyboards; the quote alternates sit on this layout's ' and " keys).
    static let symbolCallouts: [String: [String]] = [
        "0": ["°"],
        "₽": ["$", "€", "£", "¥", "￦"],
        "#": ["№"],
        ".": ["…"],
        "%": ["‰", "∞"],
        "=": ["≠", "≈"],
        "-": ["•", "–", "—"],
        "/": ["\\"],
        "&": ["§"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["’", "‘", "`"],
        "\"": ["”", "“", "„", "»", "«"],
    ]

    static let callouts: [String: [String]] = digraphCallouts
        .merging(letterCallouts) { first, _ in first }
        .merging(symbolCallouts) { first, _ in first }
}

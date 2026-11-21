# Localization and strings for review

## What is Kumyk today

| Where | String | Source |
|---|---|---|
| Keyboard name (flashed on the space bar), app header | Къумукъ тил | the self-name of the language as reference works give it; the corpus has its forms «къумукъ тилде», «къумукъ тилни» |
| Space bar corner label | КЪУМ | abbreviation chosen here, like «ЛЕЗГ», «АВАР», «ДАРГ» |

Nothing else is Kumyk yet. **No Kumyk translation was invented.**

## What is temporary Russian (needs a Kumyk translation)

No verified Kumyk translation of the key names or of the keyboard's
settings panel exists (Agisight's `ios-system-keyboard` has no Kumyk key
names), so `KumykStrings.swift` uses Russian. Every string below needs a
reviewed Kumyk version:

| Field | Russian (current) |
|---|---|
| space | Пробел |
| return key: Go / Send / Done / Next / Continue / Join / Route / Search | Перейти / Отправить / Готово / Далее / Продолжить / Подкл. / Маршрут / Найти |
| emergency call | SOS |
| lettersKey | АБВ |
| deleteWordQuestion | Удалить «…»? |
| no / delete | Нет / Удалить |
| emojiRecents | Недавние |
| back / close | Назад / Клавиатура |
| settingsCaption / settingsTitle | КУМЫКСКАЯ КЛАВИАТУРА / Настройки |
| pageInput / pageTheme / pageDictionary / pageAbout | Ввод / Тема / Словарь / О клавиатуре |
| sectionLayout / sectionSuggestions / sectionKeys / sectionLearning | Раскладка / Подсказки / Клавиши / Обучение |
| sectionLongPress / sectionTheme | Долгое нажатие (гъ, къ, ё…) / Тема |
| wordSuggestions / nextWordSuggestion / autoSpace | Подсказки слов / Подсказка следующего слова / Пробел после подсказки |
| doubleSpacePeriod / spaceCursor / spaceCornerToggle | Два пробела — точка / Курсор пробелом / «къум» на пробеле |
| learnFast / learnNormal / learnSlow / learnUses | Быстро / Обычно / Медленно / N раз(а) |
| calloutShort / calloutNormal / calloutLong / calloutDuration | Короткая задержка / Обычная задержка / Длинная задержка / 0,3 с |
| themeSystem / themeLight / themeDark | Системная / Светлая / Тёмная |
| learnedWordsCaption / noWordsYet | выученные слова / Пока нет слов |
| deleteAll / deleteAllQuestion | Удалить все выученные слова / Удалить все выученные слова? |
| aboutInitial / aboutTitle / aboutByline | К / Кумыкская клавиатура / Версия … · LekiTech |
| settingsTitle / settingsSubtitle of the layout style | Стандартная / Русская раскладка, ъ на месте щ |
| emojiCategoryTitles | Смайлики и люди, Животные и природа, Еда и напитки, Активность, Путешествия и места, Предметы, Символы, Флаги |

Also the extension's `Localizable.xcstrings` («Show «къум» on the space
bar», en/ru) and the display name «Kumyk» / «Кумыкский» in both
`InfoPlist.xcstrings` (a Kumyk display name could be added as a `kum`
localization once iOS lists the language).

The engine's own labels (for example the explanatory subtitles under the
toggles) follow the system language (en/ru) and are not Kumyk's to
translate.

## The containing app

English with Russian translations (`KumykKeyboard/Localizable.xcstrings`),
like the Lezgi and Dargwa apps: «Kumyk Keyboard» / «Кумыкская клавиатура».
No Kumyk text there except letters and «Къумукъ тил». The app shows no
contributor credits; attribution of third-party material is in the
repository (`LICENSE`, `Tests/KumykCoreTests/Fixtures/agisight/SOURCE.md`).

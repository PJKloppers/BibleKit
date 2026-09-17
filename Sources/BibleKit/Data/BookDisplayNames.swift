import Foundation

/// Per-translation display names for each canonical BookName.
///
/// This is a small stopgap for the two bundled translations, not a general
/// localization system — if BibleKit ever supports arbitrary imported
/// translations needing their own display names, this should be revisited.
public enum BookDisplayNames {
    public static func name(for book: BookName, translation: TranslationID) -> String {
        translationNames[translation]?[book] ?? book.value
    }

    private static let translationNames: [TranslationID: [BookName: String]] = [
        TranslationID("afrikaans-2020"): afrikaans,
        TranslationID("english-kjv"): english,
    ]

    private static let english: [BookName: String] = Dictionary(
        uniqueKeysWithValues: BookName.allCases.map { ($0, $0.value) }
    )

    private static let afrikaans: [BookName: String] = [
        .Genesis: "Genesis", .Exodus: "Eksodus", .Leviticus: "Levitikus", .Numbers: "Numeri",
        .Deuteronomy: "Deuteronomium", .Joshua: "Josua", .Judges: "Rigters", .Ruth: "Rut",
        .Samuel1: "1 Samuel", .Samuel2: "2 Samuel", .Kings1: "1 Konings", .Kings2: "2 Konings",
        .Chronicles1: "1 Kronieke", .Chronicles2: "2 Kronieke", .Ezra: "Esra", .Nehemiah: "Nehemia",
        .Esther: "Ester", .Job: "Job", .Psalms: "Psalms", .Proverbs: "Spreuke",
        .Ecclesiastes: "Prediker", .SongOfSolomon: "Hooglied", .Isaiah: "Jesaja", .Jeremiah: "Jeremia",
        .Lamentations: "Klaagliedere", .Ezekiel: "Esegiël", .Daniel: "Daniël", .Hosea: "Hosea",
        .Joel: "Joël", .Amos: "Amos", .Obadiah: "Obadja", .Jonah: "Jona",
        .Micah: "Miga", .Nahum: "Nahum", .Habakkuk: "Habakuk", .Zephaniah: "Sefanja",
        .Haggai: "Haggai", .Zechariah: "Sagaria", .Malachi: "Maleagi",
        .Matthew: "Matteus", .Mark: "Markus", .Luke: "Lukas", .John: "Johannes",
        .Acts: "Handelinge", .Romans: "Romeine", .Corinthians1: "1 Korintiërs", .Corinthians2: "2 Korintiërs",
        .Galatians: "Galasiërs", .Ephesians: "Efesiërs", .Philippians: "Filippense", .Colossians: "Kolossense",
        .Thessalonians1: "1 Tessalonisense", .Thessalonians2: "2 Tessalonisense", .Timothy1: "1 Timoteus", .Timothy2: "2 Timoteus",
        .Titus: "Titus", .Philemon: "Filemon", .Hebrews: "Hebreërs", .James: "Jakobus",
        .Peter1: "1 Petrus", .Peter2: "2 Petrus", .John1: "1 Johannes", .John2: "2 Johannes",
        .John3: "3 Johannes", .Jude: "Judas", .Revelation: "Openbaring",
    ]
}

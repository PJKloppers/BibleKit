import Foundation

public enum BibleTestament: Sendable {
    case old
    case new
}

public struct BibleVerse: Identifiable, Sendable {
    public let id: Int      // verse number inside the chapter
    public let text: String
}

public struct BibleChapter: Identifiable, Sendable {
    public let id: Int      // chapter number inside the book
    public let verses: [BibleVerse]
}

public struct BibleBook: Identifiable, Sendable {
    public let id: Int      // dataset book number, 1-66
    public let name: String
    public let testament: BibleTestament
    public let chapters: [BibleChapter]
}

/// The 66 books of the dataset in order. The XML only numbers them (1-39 Old, 40-66 New),
/// so the display name list lives here instead. Names match the Afrikaans 2020 translation.
public let bibleBookNames = [
    // Old Testament
    "Genesis", "Eksodus", "Levitikus", "Numeri", "Deuteronomium",
    "Josua", "Rigters", "Rut", "1 Samuel", "2 Samuel",
    "1 Konings", "2 Konings", "1 Kronieke", "2 Kronieke", "Esra",
    "Nehemia", "Ester", "Job", "Psalms", "Spreuke",
    "Prediker", "Hooglied", "Jesaja", "Jeremia", "Klaagliedere",
    "Esegiël", "Daniël", "Hosea", "Joël", "Amos",
    "Obadja", "Jona", "Miga", "Nahum", "Habakuk",
    "Sefanja", "Haggai", "Sagaria", "Maleagi",
    // New Testament
    "Matteus", "Markus", "Lukas", "Johannes", "Handelinge",
    "Romeine", "1 Korintiërs", "2 Korintiërs", "Galasiërs", "Efesiërs",
    "Filippense", "Kolossense", "1 Tessalonisense", "2 Tessalonisense", "1 Timoteus",
    "2 Timoteus", "Titus", "Filemon", "Hebreërs", "Jakobus",
    "1 Petrus", "2 Petrus", "1 Johannes", "2 Johannes", "3 Johannes",
    "Judas", "Openbaring",
]

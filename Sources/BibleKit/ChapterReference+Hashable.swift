import Foundation

extension ChapterReference: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bookName)
        hasher.combine(index)
    }
}

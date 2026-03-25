import SwiftUI

struct BookDetailView: View {
    @State private var title: String
    @State private var author: String
    @State private var status: BookStatus
    @State private var notes: String
    @State private var validationMessage: String?

    let book: Book
    let onSave: (String, String, BookStatus, String?) -> Void
    let onDelete: () -> Void

    init(book: Book, onSave: @escaping (String, String, BookStatus, String?) -> Void, onDelete: @escaping () -> Void) {
        self.book = book
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _status = State(initialValue: book.status)
        _notes = State(initialValue: book.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Book") {
                TextField("Title", text: $title)
                TextField("Author", text: $author)

                Picker("Status", selection: $status) {
                    ForEach(BookStatus.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 180)
            }

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Delete", role: .destructive) {
                    onDelete()
                }

                Spacer()

                Button("Save Changes") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private func save() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            validationMessage = "Title is required."
            return
        }

        guard !normalizedAuthor.isEmpty else {
            validationMessage = "Author is required."
            return
        }

        validationMessage = nil
        onSave(
            normalizedTitle,
            normalizedAuthor,
            status,
            normalizedNotes.isEmpty ? nil : normalizedNotes
        )
    }
}

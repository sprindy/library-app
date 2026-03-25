import SwiftUI

struct BookFormData {
    var title: String = ""
    var author: String = ""
    var status: BookStatus = .toRead
    var notes: String = ""

    var normalizedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct BookFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var formData = BookFormData()
    @State private var validationMessage: String?

    let onSave: (BookFormData) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Book")
                .font(.title2)
                .bold()

            Form {
                TextField("Title", text: $formData.title)
                TextField("Author", text: $formData.author)

                Picker("Status", selection: $formData.status) {
                    ForEach(BookStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                    TextEditor(text: $formData.notes)
                        .frame(minHeight: 120)
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
    }

    private func save() {
        let title = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = formData.author.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            validationMessage = "Title is required."
            return
        }

        guard !author.isEmpty else {
            validationMessage = "Author is required."
            return
        }

        validationMessage = nil
        formData.title = title
        formData.author = author
        onSave(formData)
        dismiss()
    }
}

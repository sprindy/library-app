import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UICommandCenter.self) private var commandCenter

    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]

    @State private var searchText: String = ""
    @State private var selectedBookID: UUID?
    @State private var showingAddBookSheet: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var deleteCandidateID: UUID?

    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false

    @FocusState private var searchIsFocused: Bool

    private var filteredBooks: [Book] {
        LibrarySearch.filter(books: books, query: searchText)
    }

    private var selectedBook: Book? {
        guard let selectedBookID else { return nil }
        return books.first(where: { $0.id == selectedBookID })
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                searchBar

                if filteredBooks.isEmpty {
                    ContentUnavailableView(
                        "No Books",
                        systemImage: "books.vertical",
                        description: Text(emptyStateDescription)
                    )
                    .padding(.top, 40)
                } else {
                    List(filteredBooks, id: \.id) { book in
                        BookRowView(
                            book: book,
                            isSelected: selectedBookID == book.id,
                            onSelect: { selectedBookID = book.id },
                            onStatusChange: { newStatus in
                                updateStatus(book: book, status: newStatus)
                            },
                            onDelete: {
                                deleteCandidateID = book.id
                                showingDeleteConfirmation = true
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
        } detail: {
            if let selectedBook {
                BookDetailView(
                    book: selectedBook,
                    onSave: { title, author, status, notes in
                        updateBook(
                            selectedBook,
                            title: title,
                            author: author,
                            status: status,
                            notes: notes
                        )
                    },
                    onDelete: {
                        deleteCandidateID = selectedBook.id
                        showingDeleteConfirmation = true
                    }
                )
                .id(selectedBook.id)
                .padding(.horizontal, 12)
            } else {
                ContentUnavailableView(
                    "Select a Book",
                    systemImage: "book.closed",
                    description: Text("Choose a book from the list or create one with Command-N.")
                )
            }
        }
        .sheet(isPresented: $showingAddBookSheet) {
            BookFormView(onSave: addBook)
        }
        .confirmationDialog(
            "Delete book?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if selectedBookID == nil {
                selectedBookID = filteredBooks.first?.id
            }
        }
        .onChange(of: filteredBooks.map(\.id)) { ids in
            guard let selectedBookID else { return }
            if !ids.contains(selectedBookID) {
                self.selectedBookID = ids.first
            }
        }
        .onChange(of: commandCenter.newBookSignal) { _ in
            showingAddBookSheet = true
        }
        .onChange(of: commandCenter.focusSearchSignal) { _ in
            searchIsFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            TextField("Search by title or author", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($searchIsFocused)

            Button("Search") {
                performSearchAction()
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("Add") {
                showingAddBookSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Export CSV") {
                exportCSV()
            }
        }
        .padding(12)
    }

    private var emptyStateDescription: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add your first book with the Add button or Command-N."
        }
        return "No books matched your current search."
    }

    private func addBook(_ formData: BookFormData) -> Bool {
        let book = Book(
            title: formData.title,
            author: formData.author,
            status: formData.status,
            notes: formData.normalizedNotes
        )

        modelContext.insert(book)
        let didSave = persistChanges(errorContext: "Failed to save the new book.")
        if didSave {
            selectedBookID = book.id
        } else {
            modelContext.delete(book)
        }

        return didSave
    }

    private func updateStatus(book: Book, status: BookStatus) {
        guard book.status != status else { return }
        book.status = status
        book.touch()
        persistChanges(errorContext: "Failed to update book status.")
    }

    private func updateBook(_ book: Book, title: String, author: String, status: BookStatus, notes: String?) {
        book.title = title
        book.author = author
        book.status = status
        book.notes = notes
        book.touch()
        persistChanges(errorContext: "Failed to save book changes.")
    }

    private func confirmDelete() {
        guard let deleteCandidateID, let book = books.first(where: { $0.id == deleteCandidateID }) else { return }
        modelContext.delete(book)

        if selectedBookID == deleteCandidateID {
            selectedBookID = nil
        }

        self.deleteCandidateID = nil
        persistChanges(errorContext: "Failed to delete book.")

        if selectedBookID == nil {
            selectedBookID = filteredBooks.first?.id
        }
    }

    private func persistChanges(errorContext: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            showAlert(title: "Save Error", message: "\(errorContext)\n\n\(error.localizedDescription)")
            return false
        }
    }


    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "library-export.csv"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            let csv = CSVExporter.export(books: books)
            try csv.write(to: destinationURL, atomically: true, encoding: .utf8)
            showAlert(title: "Export Complete", message: "CSV saved to:\n\(destinationURL.path)")
        } catch {
            showAlert(title: "Export Error", message: "Failed to export CSV.\n\n\(error.localizedDescription)")
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

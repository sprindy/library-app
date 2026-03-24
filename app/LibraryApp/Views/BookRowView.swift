import SwiftUI

struct BookRowView: View {
    let book: Book
    let isSelected: Bool
    let onSelect: () -> Void
    let onStatusChange: (BookStatus) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Picker("Status", selection: statusBinding) {
                ForEach(BookStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 120)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete Book")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.16) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var statusBinding: Binding<BookStatus> {
        Binding(
            get: { book.status },
            set: { onStatusChange($0) }
        )
    }
}

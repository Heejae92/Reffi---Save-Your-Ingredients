import SwiftUI

/// Shared recovery for all inventory mutations. The unsaved snapshot stays in memory.
struct SaveErrorNotice: View {
    @Environment(FridgeStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("Changes aren't saved yet. Keep Reffi open, free some device storage, then try again.")
                .reffiType(.caption)
            Button("Try saving again") { store.retrySave() }
                .reffiType(.subhead).frame(minHeight: 44)
        }
        .padding(ReffiSpace.s3)
        .foregroundStyle(ReffiColor.urgentDark)
        .background(ReffiColor.paper, in: RoundedRectangle(cornerRadius: ReffiRadius.md))
        .accessibilityIdentifier("storage.saveError")
    }
}

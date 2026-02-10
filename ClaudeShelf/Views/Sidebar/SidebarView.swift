import SwiftUI

/// The primary navigation sidebar showing category filters with file counts.
///
/// Displays an "All Files" row at the top followed by each category that
/// contains at least one file. Selection drives ``AppState/selectedCategory``
/// which filters the file list in the content column.
struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedCategory) {
            // "All Files" row — selected when selectedCategory is nil
            Label {
                HStack {
                    Text("All Files")
                    Spacer()
                    Text("\(appState.files.count)")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } icon: {
                Image(systemName: "tray.full")
            }
            .tag(Category?.none)

            // Category rows — only shown when they have files
            Section("Categories") {
                ForEach(Category.allCases) { category in
                    let count = appState.categoryCounts[category] ?? 0
                    if count > 0 {
                        Label {
                            HStack {
                                Text(category.displayName)
                                Spacer()
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                            }
                        } icon: {
                            Image(systemName: category.sfSymbol)
                        }
                        .tag(Category?.some(category))
                    }
                }
            }
        }
        .navigationTitle("ClaudeShelf")
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
    } detail: {
        Text("Detail")
    }
    .environment(AppState())
}

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Categories")
        } content: {
            Text("Files")
        } detail: {
            Text("Editor")
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    ContentView()
}

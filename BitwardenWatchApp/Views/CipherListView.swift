import SwiftUI

struct CipherListView: View {
    @ObservedObject var viewModel = CipherListViewModel(CipherService.shared)

    var body: some View {
        NavigationView {
            List {
                if viewModel.user?.email != nil {
                    avatarHeader
                        .listRowBackground(Color.clear)
                }
                ForEach(viewModel.filteredCiphers, id: \.id) { cipher in
                    NavigationLink(destination: CipherDetailsView(cipher: cipher)) {
                        CipherItemView(cipher)
                    }
                }
            }
            // "Search" is a key of the watch app's Localizable.strings.
            .searchable(text: $viewModel.searchTerm, prompt: Text(LocalizedStringKey("Search")))
            .emptyState(viewModel.filteredCiphers.isEmpty, emptyContent: {
                emptyContent
            })
            .navigationTitle("Pass-Y")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            #if targetEnvironment(simulator) // for the preview
            viewModel.fetchCiphers()
            #else
            viewModel.checkStateAndFetch()
            #endif
        }
        .fullScreenCover(isPresented: $viewModel.showingSheet) {
            BWStateView(viewModel.currentState, viewModel.debugText)
        }
    }

    var avatarHeader: some View {
        HStack {
            AvatarView(viewModel.user)
            Text(viewModel.user!.email!)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .privacySensitive()
        }
    }

    var emptyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "key")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("ThereAreNoItemsToList")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    var v = CipherListView()
    StateService.shared.currentState = .valid
    v.viewModel = CipherListViewModel(CipherServiceMock())
    v.viewModel.user = UserDTO(
        email: "testing@test.com",
        id: "zxc",
        name: "Tester",
    )
    return v
}

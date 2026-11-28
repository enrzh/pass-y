import SwiftUI

struct CipherItemView: View {
    let cipher: CipherDTO

    init(_ cipher: CipherDTO) {
        self.cipher = cipher
    }

    var body: some View {
        VStack(alignment: .leading) {
            if cipher.id == "-1" {
                // Workaround: To display 0 results on search
                // and the message to be localized
                Text(LocalizedStringKey(cipher.name!))
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(cipher.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if cipher.login.username != nil {
                Text(cipher.login.username!)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .privacySensitive()
            }
        }
    }
}

#Preview {
    CipherItemView(CipherMock.ciphers[0])
}

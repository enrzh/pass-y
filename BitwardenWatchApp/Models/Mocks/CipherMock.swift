import Foundation

enum CipherMock {
    /// Fictitious items of previews and the DEBUG demo mode (`-passyDemoCodes`, used for store screenshots).
    static let ciphers: [CipherDTO] = [
        CipherDTO(
            id: "0",
            login: LoginDTO(
                totp: "JBSWY3DPEHPK3PXP",
                uris: cipherLoginUris,
                username: "alex.miller@example.com",
            ),
            name: "Acme Cloud",
            userId: "123123",
        ),
        CipherDTO(
            id: "1",
            login: LoginDTO(
                totp: "KRSXG5CTMVRXEZLU",
                uris: cipherLoginUris,
                username: "alexm",
            ),
            name: "Blue Harbor Bank",
            userId: "123123",
        ),
        CipherDTO(
            id: "2",
            login: LoginDTO(
                totp: "MFRGGZDFMZTWQ2LK",
                uris: cipherLoginUris,
                username: "alex.miller@example.com",
            ),
            name: "Northwind Mail",
            userId: "123123",
        ),
        CipherDTO(
            id: "3",
            login: LoginDTO(
                totp: "ONSWG4TFOQ2DKNRX",
                uris: cipherLoginUris,
                username: "alex.miller@example.com",
            ),
            name: "Pixel Studio",
            userId: "123123",
        ),
        CipherDTO(
            id: "4",
            login: LoginDTO(
                totp: "GEZDGNBVGY3TQOJQ",
                uris: cipherLoginUris,
                username: "alex.miller@example.com",
            ),
            name: "Skyline Air",
            userId: "123123",
        ),
    ]

    static let cipherLoginUris: [LoginUriDTO] = [
        LoginUriDTO(uri: "example.com"),
    ]
}

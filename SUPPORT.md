# Pass-Y Support

Questions, problems or suggestions: **support@aiity.de**. You can also open an
[issue on GitHub](https://github.com/enrzh/pass-y/issues). Never send passwords, recovery codes or exports.

[Privacy policy](PRIVACY.md) · [Source code](https://github.com/enrzh/pass-y) · [License (GPLv3)](LICENSE.txt)

## Getting started

Pass-Y needs an account on a Vaultwarden or another Bitwarden-compatible server. On the first screen choose your
server, enter its HTTPS address, then your email address and master password. Pass-Y does not host accounts.

## Common questions

**I cannot sign in.** Check the server address (including a path such as `/vault`, if your server uses one), that the
certificate is valid, and that your clock is correct.

**AutoFill is not offered.** Turn Pass-Y on under Settings > General > AutoFill & Passwords.

**How do I import passwords?** Use your server's web vault, or the system's password transfer between apps.

**Verification codes on Apple Watch.** Turn on Settings > Other > Connect to Watch.

**Delete my account.** Settings > Account security > Delete account. This deletes the account on your server.

**I forgot my master password.** It cannot be recovered. Ask your server's operator what options your account has.

## Topics

### AutoFill

Turn Pass-Y on under Settings > General > AutoFill & Passwords, and turn off other password apps you no longer use.
When you sign in, Pass-Y appears above the keyboard and suggests the logins whose website matches.

### URI match detection

Decides which logins are suggested for a website or app: by base domain (default), by host, by the start of the
address, exactly, by a regular expression, or never. You can set a default in Settings > AutoFill and override it for
each website of a login.

### Fill Assist

Helps AutoFill on sites with unusual sign-in forms. It uses rules that your server provides, if it provides any.

### Verification codes

Pass-Y shows the one-time codes (TOTP) of logins that have an authenticator key. Add a key by scanning the QR code or
entering it by hand when you edit a login. Whether codes are available can depend on your account on your server.

### Fingerprint phrase

A sequence of words derived from your account's public key. Compare it with what your server's web vault shows to make
sure you talk to your own account, for example when you approve a login on another device.

### Username generator

Creates usernames: random words, a "plus address" or catch-all address of your email domain, or an alias from an email
forwarding service (addy.io, SimpleLogin and others). For a forwarding service you need your own account and API key
there; Pass-Y sends the request to that service directly.

### Importing passwords

Import from another password manager in your server's web vault (Tools > Import data), then sync Pass-Y. On iOS 26 you
can also move passwords between apps with the system's import and export.

### Send

Shares a text or a file through your server with a link, optionally with a password, an expiry date and a maximum
number of views. The contents are encrypted before they leave your device.

### Master password re-prompt

Asks for your master password again before Pass-Y shows or fills a login that has this option turned on.

### Organizations

Organizations let you share vault items with others. They are created and managed on your server (in its web vault);
Pass-Y shows the shared items and collections.

### Website icons

Pass-Y can show the icon of each login's website. The icons are loaded from your server's icon service, so the server
learns the websites of your logins; depending on its settings, the server may fetch the icons from another service.
Turn icons off under Settings > Appearance or Customize.

### Flight recorder

Records diagnostic logs on this device for the time you choose, then stops and deletes them after 30 days. Passwords and
vault contents are not logged. Logs leave the device only if you share them yourself.

### Premium features

Some features (for example attachments or verification codes) can depend on your account on your server. Pass-Y sells
nothing and has no in-app purchases.

### Emails

Pass-Y sends no emails and has no newsletter. Emails about your account come from your server.

### Terms

Pass-Y is free software under the GNU General Public License v3 and comes without any warranty. Your account, its data
and its terms are those of the server you sign in to and its operator.

---

## Hilfe (Deutsch)

Fragen und Probleme: **support@aiity.de**. Sende nie Passwörter, Wiederherstellungscodes oder Exporte.

- Du brauchst ein Konto auf einem Vaultwarden- oder Bitwarden-kompatiblen Server. Auf dem ersten Bildschirm den
  Server wählen, die HTTPS-Adresse eingeben, dann E-Mail und Master-Passwort.
- Anmeldung klappt nicht: Serveradresse samt Pfad, gültiges Zertifikat und Uhrzeit prüfen.
- AutoFill: in den iOS-Einstellungen unter Allgemein > Automatisches Ausfüllen & Passwörter aktivieren.
- Konto löschen: Einstellungen > Kontosicherheit > Konto löschen.
- Master-Passwort vergessen: Es kann nicht wiederhergestellt werden.
- Weitere Themen (AutoFill, Send, Website-Symbole, Flugschreiber, ...) stehen oben unter „Topics“ (englisch).

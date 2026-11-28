#!/usr/bin/env python3
"""Fills a throwaway account with fictitious demo items (App Store screenshots and the App Review demo server).

Usage: seed_demo.py [server_url]   (default http://localhost:8088)
Account: PASSY_EMAIL (default passy-test@example.test), PASSY_PASSWORD (default: the documented test password).
Register it first with seed_account.py. Items that exist already (by name) are skipped. No real data, no real brands.
"""
import base64, hashlib, hmac, json, os, sys, urllib.parse, urllib.request
from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand

SERVER = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8088").rstrip("/")
EMAIL = os.environ.get("PASSY_EMAIL", "passy-test@example.test")
PASSWORD = os.environ.get("PASSY_PASSWORD", "PassY-Test-Only-2026!")
ITER = 600000
b64 = lambda b: base64.b64encode(b).decode()
d64 = base64.b64decode


def enc_bytes(key, data):
    iv = os.urandom(16)
    p = padding.PKCS7(128).padder()
    c = Cipher(algorithms.AES(key[:32]), modes.CBC(iv)).encryptor()
    ct = c.update(p.update(data) + p.finalize()) + c.finalize()
    return f"2.{b64(iv)}|{b64(ct)}|{b64(hmac.new(key[32:], iv + ct, hashlib.sha256).digest())}"


def dec_bytes(key, s):
    iv, ct, mac = [d64(x) for x in s.split(".", 1)[1].split("|")]
    assert hmac.compare_digest(hmac.new(key[32:], iv + ct, hashlib.sha256).digest(), mac)
    d = Cipher(algorithms.AES(key[:32]), modes.CBC(iv)).decryptor()
    u = padding.PKCS7(128).unpadder()
    return u.update(d.update(ct) + d.finalize()) + u.finalize()


master = hashlib.pbkdf2_hmac("sha256", PASSWORD.encode(), EMAIL.encode(), ITER, 32)
pw_hash = b64(hashlib.pbkdf2_hmac("sha256", master, PASSWORD.encode(), 1, 32))
stretched = (HKDFExpand(hashes.SHA256(), 32, b"enc").derive(master)
             + HKDFExpand(hashes.SHA256(), 32, b"mac").derive(master))
CLIENT = {"Bitwarden-Client-Version": "2025.10.0", "User-Agent": "passy-seed"}
form = urllib.parse.urlencode({
    "grant_type": "password", "username": EMAIL, "password": pw_hash, "scope": "api offline_access",
    "client_id": "web", "deviceType": "9", "deviceIdentifier": "00000000-0000-4000-8000-000000000002",
    "deviceName": "seed"}).encode()
tok = json.load(urllib.request.urlopen(urllib.request.Request(SERVER + "/identity/connect/token", form, CLIENT)))
key = dec_bytes(stretched, tok.get("Key") or tok["key"])
payload = tok["access_token"].split(".")[1]
UID = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["sub"]
HEADERS = {"Authorization": "Bearer " + tok["access_token"], "Content-Type": "application/json", **CLIENT}


def call(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    return json.load(urllib.request.urlopen(urllib.request.Request(SERVER + path, data, HEADERS)))


def e(text):
    return None if text is None else enc_bytes(key, text.encode())


def name_of(entry):
    return dec_bytes(key, entry.get("name") or entry.get("Name")).decode()


sync = call("/api/sync?excludeDomains=true")
folders = {name_of(f): f.get("id") or f.get("Id") for f in sync.get("folders") or []}
existing = set()
for c in sync.get("ciphers") or []:
    if not (c.get("organizationId") or c.get("OrganizationId")):
        existing.add(name_of(c))
for folder in ["Work", "Personal", "Finance", "Travel"]:
    if folder not in folders:
        folders[folder] = call("/api/folders", {"name": e(folder)})["id"]


def add(kind, name, folder=None, favorite=False, notes=None, **data):
    if name in existing:
        return
    body = {"encryptedFor": UID, "type": kind, "name": e(name), "notes": e(notes), "favorite": favorite,
            "folderId": folders.get(folder), "fields": None, **data}
    call("/api/ciphers", body)


def login(name, user, host, folder=None, totp=None, favorite=False):
    password = "Demo-" + base64.urlsafe_b64encode(hashlib.sha256(name.encode()).digest()[:12]).decode()
    add(1, name, folder, favorite, login={
        "username": e(user), "password": e(password), "totp": e(totp),
        "uris": [{"uri": e("https://" + host), "match": None}]})


MAIL = "alex.miller@example.com"
login("Northwind Mail", MAIL, "mail.northwind.example.com", "Work", "JBSWY3DPEHPK3PXP", True)
login("Acme Cloud", "alex.miller", "cloud.acme.example.com", "Work", "KRSXG5CTMVRXEZLUKN2GC43H", True)
login("Team Wiki", "amiller", "wiki.example.org", "Work")
login("Pixel Studio", MAIL, "pixel.example.net", "Work", "MFRGGZDFMZTWQ2LK")
login("Blue Harbor Bank", "alexm", "bank.blueharbor.example.com", "Finance", "NB2W45DFOIZAKZLT", True)
login("Evergreen Savings", "alex.miller", "savings.example.com", "Finance")
login("Skyline Air", MAIL, "fly.skyline.example.com", "Travel", "ORSXG5BAONSWG4TF")
login("Harbor Hotels", MAIL, "stay.example.net", "Travel")
login("City Library", "A-204518", "library.example.org", "Personal")
login("Green Grocer", MAIL, "grocer.example.com", "Personal")
login("Fitness Club", "alex_m", "fit.example.net", "Personal")
login("Home Router", "admin", "router.example.test", "Personal")
login("Contoso Shop", MAIL, "shop.contoso.example.com")
login("Streaming Box", MAIL, "tv.example.net")
for name, brand, number, folder in [("Everyday Card", "Visa", "4111111111111111", "Finance"),
                                    ("Travel Card", "Mastercard", "5555555555554444", "Travel")]:
    add(3, name, folder, name == "Everyday Card", card={
        "cardholderName": e("Alex Miller"), "brand": e(brand), "number": e(number), "expMonth": e("8"),
        "expYear": e("2030"), "code": e("123")})
add(4, "Alex Miller", "Personal", identity={
    "title": e("Mx"), "firstName": e("Alex"), "lastName": e("Miller"), "email": e(MAIL),
    "address1": e("12 Sample Street"), "city": e("Springfield"), "postalCode": e("12345"), "country": e("US"),
    "company": e("Northwind")})
add(2, "Wi-Fi at home", "Personal", notes="Network: Sample-Home\nPassword: demo-only-1234", secureNote={"type": 0})
add(2, "Travel checklist", "Travel", notes="Passport, tickets, adapter.", secureNote={"type": 0})
add(5, "Build server key", "Work", sshKey={
    "privateKey": e("-----BEGIN OPENSSH PRIVATE KEY-----\ndemo only, not a key\n-----END OPENSSH PRIVATE KEY-----"),
    "publicKey": e("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDemoOnlyNotARealKey alex@example.com"),
    "keyFingerprint": e("SHA256:DemoOnlyNotARealFingerprint0000000000000000")})
print("demo items ready for", EMAIL)

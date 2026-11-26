#!/usr/bin/env python3
"""Adds N throwaway login ciphers to the local test account (performance testing) and the named fixtures the UI tests
search for: GitHub (with an authenticator key, so the "Verification codes" tile exists), Netflix and Bank
(skipped when an item with that name already exists). With a count of at most 100 (the UI test account) the first 12
Perf Items also get an authenticator key (Perf Item 0011 with a 60 s period). Account: PASSY_EMAIL (default passy-test@example.test). Usage: seed_ciphers.py [count] [server_url]
`seed_ciphers.py --count [server_url]` prints the number of "Perf Item" ciphers on the server and exits."""
import base64, hashlib, hmac, json, os, sys, urllib.parse, urllib.request
from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand

COUNT_ONLY = len(sys.argv) > 1 and sys.argv[1] == "--count"
COUNT = 0 if COUNT_ONLY else (int(sys.argv[1]) if len(sys.argv) > 1 else 2000)
SERVER = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8088"
EMAIL = os.environ.get("PASSY_EMAIL", "passy-test@example.test")
PASSWORD, ITER = "PassY-Test-Only-2026!", 600000
b64 = lambda b: base64.b64encode(b).decode()
d64 = base64.b64decode

def enc_string(key, data: bytes) -> str:
    iv = os.urandom(16)
    p = padding.PKCS7(128).padder()
    c = Cipher(algorithms.AES(key[:32]), modes.CBC(iv)).encryptor()
    ct = c.update(p.update(data) + p.finalize()) + c.finalize()
    return f"2.{b64(iv)}|{b64(ct)}|{b64(hmac.new(key[32:], iv + ct, hashlib.sha256).digest())}"

def dec_string(key, s: str) -> bytes:
    iv, ct, mac = [d64(x) for x in s.split(".", 1)[1].split("|")]
    assert hmac.compare_digest(hmac.new(key[32:], iv + ct, hashlib.sha256).digest(), mac)
    d = Cipher(algorithms.AES(key[:32]), modes.CBC(iv)).decryptor()
    u = padding.PKCS7(128).unpadder()
    return u.update(d.update(ct) + d.finalize()) + u.finalize()

master = hashlib.pbkdf2_hmac("sha256", PASSWORD.encode(), EMAIL.encode(), ITER, 32)
pw_hash = b64(hashlib.pbkdf2_hmac("sha256", master, PASSWORD.encode(), 1, 32))
stretched = HKDFExpand(hashes.SHA256(), 32, b"enc").derive(master) + HKDFExpand(hashes.SHA256(), 32, b"mac").derive(master)
form = urllib.parse.urlencode({"grant_type": "password", "username": EMAIL, "password": pw_hash, "scope": "api offline_access",
    "client_id": "web", "deviceType": "9", "deviceIdentifier": "00000000-0000-4000-8000-000000000001", "deviceName": "seed"}).encode()
CLIENT_VERSION = "2025.10.0"  # newer Vaultwarden requires the Bitwarden-Client-Version header
try:
    tok = json.load(urllib.request.urlopen(urllib.request.Request(
        SERVER + "/identity/connect/token", form, {"Bitwarden-Client-Version": CLIENT_VERSION})))
except urllib.error.HTTPError as e:
    print("token request failed:", e.code, e.read()[:500]); raise SystemExit(1)
sym = dec_string(stretched, tok.get("Key") or tok["key"])
payload = tok["access_token"].split(".")[1]; payload += "=" * (-len(payload) % 4)
UID = json.loads(base64.urlsafe_b64decode(payload))["sub"]
H = {"Authorization": "Bearer " + tok["access_token"], "Content-Type": "application/json",
     "Bitwarden-Client-Version": CLIENT_VERSION}
def post(body):
    try:
        urllib.request.urlopen(urllib.request.Request(SERVER + "/api/ciphers", json.dumps(body).encode(), H)).read()
    except urllib.error.HTTPError as e:
        print(e.code, e.read()[:400]); raise SystemExit(1)

if COUNT_ONLY:
    sync = json.load(urllib.request.urlopen(urllib.request.Request(SERVER + "/api/sync?excludeDomains=true", headers=H)))
    n = 0
    for c in sync.get("ciphers") or sync.get("Ciphers") or []:
        try:
            n += dec_string(sym, c.get("name") or c.get("Name")).decode().startswith("Perf Item")
        except Exception:
            pass
    print(n)
    raise SystemExit(0)
existing = set()
try:
    sync = json.load(urllib.request.urlopen(urllib.request.Request(SERVER + "/api/sync?excludeDomains=true", headers=H)))
    for c in sync.get("ciphers") or sync.get("Ciphers") or []:
        try:
            existing.add(dec_string(sym, c.get("name") or c.get("Name")).decode())
        except Exception:
            pass
except urllib.error.HTTPError as e:
    print("sync failed (fixtures may be duplicated):", e.code)
for name, user, pw, totp in [("GitHub", "octo@example.test", "Gh-Pass-1234", "JBSWY3DPEHPK3PXP"),
                             ("Netflix", "movie@example.test", "Nf-Pass-5678", None),
                             ("Bank", "me@example.test", "Bk-Pass-9012", None)]:
    if name in existing:
        continue
    login = {"username": enc_string(sym, user.encode()), "password": enc_string(sym, pw.encode()),
             "totp": enc_string(sym, totp.encode()) if totp else None, "uris": None}
    post({"encryptedFor": UID, "type": 1, "name": enc_string(sym, name.encode()), "notes": None, "favorite": False,
          "login": login, "fields": None})
    print("fixture", name)

# A small (UI test) account gets authenticator keys on its first 12 items, so the verification codes page scrolls
# (shared countdown ring in both title states); Perf Item 0011 uses a 60 s period (keeps its own small ring).
def perf_totp(i):
    if COUNT > 100 or i >= 12:
        return None
    return "otpauth://totp/Perf%20Item?secret=JBSWY3DPEHPK3PXP&period=60" if i == 11 else "JBSWY3DPEHPK3PXP"

for i in range(COUNT):
    totp = perf_totp(i)
    body = {"encryptedFor": UID, "type": 1, "name": enc_string(sym, f"Perf Item {i:04d}".encode()), "notes": None, "favorite": i % 50 == 0,
            "login": {"username": enc_string(sym, f"user{i}@example.test".encode()), "password": enc_string(sym, b"pw-%d" % i),
                      "totp": enc_string(sym, totp.encode()) if totp else None,
                      "uris": [{"uri": enc_string(sym, f"https://site{i}.example.test".encode()), "match": None}]}, "fields": None}
    try:
        urllib.request.urlopen(urllib.request.Request(SERVER + "/api/ciphers", json.dumps(body).encode(), H)).read()
    except urllib.error.HTTPError as e:
        print(e.code, e.read()[:400]); raise SystemExit(1)
print("seeded", COUNT)

#!/usr/bin/env python3
"""Adds N throwaway login ciphers to the local test account (performance testing).
Usage: seed_ciphers.py [count] [server_url]"""
import base64, hashlib, hmac, json, os, sys, urllib.parse, urllib.request
from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand

COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
SERVER = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8088"
EMAIL, PASSWORD, ITER = "passy-test@example.test", "PassY-Test-Only-2026!", 600000
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
tok = json.load(urllib.request.urlopen(urllib.request.Request(SERVER + "/identity/connect/token", form)))
sym = dec_string(stretched, tok.get("Key") or tok["key"])
payload = tok["access_token"].split(".")[1]; payload += "=" * (-len(payload) % 4)
UID = json.loads(base64.urlsafe_b64decode(payload))["sub"]
H = {"Authorization": "Bearer " + tok["access_token"], "Content-Type": "application/json"}
for i in range(COUNT):
    body = {"encryptedFor": UID, "type": 1, "name": enc_string(sym, f"Perf Item {i:04d}".encode()), "notes": None, "favorite": i % 50 == 0,
            "login": {"username": enc_string(sym, f"user{i}@example.test".encode()), "password": enc_string(sym, b"pw-%d" % i),
                      "uris": [{"uri": enc_string(sym, f"https://site{i}.example.test".encode()), "match": None}]}, "fields": None}
    try:
        urllib.request.urlopen(urllib.request.Request(SERVER + "/api/ciphers", json.dumps(body).encode(), H)).read()
    except urllib.error.HTTPError as e:
        print(e.code, e.read()[:400]); raise SystemExit(1)
print("seeded", COUNT)

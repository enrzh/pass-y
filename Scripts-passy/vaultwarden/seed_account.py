#!/usr/bin/env python3
"""Registers a THROWAWAY test account on a local Vaultwarden (never use real credentials).

Usage: seed_account.py [server_url]   (default http://localhost:8088)
Test account (documented test values only):
  email:           passy-test@example.test
  master password: PassY-Test-Only-2026!
"""
import base64, hashlib, hmac, json, os, sys, urllib.request
from cryptography.hazmat.primitives import hashes, padding, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand

SERVER = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8088"
EMAIL = "passy-test@example.test"
PASSWORD = "PassY-Test-Only-2026!"
ITER = 600000

b64 = lambda b: base64.b64encode(b).decode()

def enc_string(key64: bytes, data: bytes) -> str:
    enc, mac = key64[:32], key64[32:]
    iv = os.urandom(16)
    padder = padding.PKCS7(128).padder()
    ct = Cipher(algorithms.AES(enc), modes.CBC(iv)).encryptor()
    ctext = ct.update(padder.update(data) + padder.finalize()) + ct.finalize()
    tag = hmac.new(mac, iv + ctext, hashlib.sha256).digest()
    return f"2.{b64(iv)}|{b64(ctext)}|{b64(tag)}"

master = hashlib.pbkdf2_hmac("sha256", PASSWORD.encode(), EMAIL.encode(), ITER, 32)
pw_hash = b64(hashlib.pbkdf2_hmac("sha256", master, PASSWORD.encode(), 1, 32))
stretched = HKDFExpand(hashes.SHA256(), 32, b"enc").derive(master) + HKDFExpand(hashes.SHA256(), 32, b"mac").derive(master)
sym = os.urandom(64)
enc_key = enc_string(stretched, sym)
priv = rsa.generate_private_key(65537, 2048)
priv_der = priv.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
pub_der = priv.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
body = {
    "email": EMAIL, "name": "PassY Test", "masterPasswordHash": pw_hash, "masterPasswordHint": None,
    "key": enc_key, "kdf": 0, "kdfIterations": ITER,
    "keys": {"publicKey": b64(pub_der), "encryptedPrivateKey": enc_string(sym, priv_der)},
}
def post(path, payload, accept=None):
    h = {"Content-Type": "application/json"}
    if accept: h["Accept"] = accept
    return urllib.request.urlopen(urllib.request.Request(SERVER + path, json.dumps(payload).encode(), h))

token = json.loads(post("/identity/accounts/register/send-verification-email",
                        {"email": EMAIL, "name": "PassY Test"}, "application/json").read())
body["emailVerificationToken"] = token
req = urllib.request.Request(SERVER + "/identity/accounts/register/finish", json.dumps(body).encode(),
                             {"Content-Type": "application/json"})
try:
    print(urllib.request.urlopen(req).status, "registered", EMAIL)
except urllib.error.HTTPError as e:
    print(e.code, e.read().decode()[:300])

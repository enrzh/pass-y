#!/usr/bin/env python3
"""Enables authenticator (TOTP) two-step login on a THROWAWAY account of a local Vaultwarden (test values only).
Usage: PASSY_EMAIL=passy-2fa@example.test enable_2fa.py [server_url]
Prints the TOTP secret and the recovery code (test values; the UI tests use the recovery code).
First register the account with: PASSY_EMAIL=passy-2fa@example.test seed_account.py"""
import base64, hashlib, hmac, json, os, struct, sys, time, urllib.parse, urllib.request

SERVER = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8088"
EMAIL = os.environ.get("PASSY_EMAIL", "passy-2fa@example.test")
PASSWORD = "PassY-Test-Only-2026!"
ITER = 600000
b64 = lambda b: base64.b64encode(b).decode()
CV = "2025.10.0"

master = hashlib.pbkdf2_hmac("sha256", PASSWORD.encode(), EMAIL.encode(), ITER, 32)
pw_hash = b64(hashlib.pbkdf2_hmac("sha256", master, PASSWORD.encode(), 1, 32))
form = urllib.parse.urlencode({"grant_type": "password", "username": EMAIL, "password": pw_hash, "scope": "api offline_access",
    "client_id": "web", "deviceType": "9", "deviceIdentifier": "00000000-0000-4000-8000-0000000000f2", "deviceName": "seed2fa"}).encode()
tok = json.load(urllib.request.urlopen(urllib.request.Request(SERVER + "/identity/connect/token", form, {"Bitwarden-Client-Version": CV})))
H = {"Authorization": "Bearer " + tok["access_token"], "Content-Type": "application/json", "Bitwarden-Client-Version": CV}

def call(method, path, body):
    r = urllib.request.Request(SERVER + path, json.dumps(body).encode(), H, method=method)
    return json.load(urllib.request.urlopen(r))

info = call("POST", "/api/two-factor/get-authenticator", {"masterPasswordHash": pw_hash})
key = info["authenticator"]["key"]
uvt = info.get("userVerificationToken")

def totp(secret):
    k = base64.b32decode(secret + "=" * (-len(secret) % 8))
    c = struct.pack(">Q", int(time.time()) // 30)
    h = hmac.new(k, c, hashlib.sha1).digest()
    o = h[-1] & 15
    return "%06d" % ((struct.unpack(">I", h[o:o + 4])[0] & 0x7FFFFFFF) % 1000000)

call("PUT", "/api/two-factor/authenticator", {"masterPasswordHash": pw_hash, "key": key, "token": totp(key), "userVerificationToken": uvt})
rec = call("POST", "/api/two-factor/get-recover", {"masterPasswordHash": pw_hash})
print("totp secret:", key)
print("recovery code:", rec.get("code") or rec.get("Code"))

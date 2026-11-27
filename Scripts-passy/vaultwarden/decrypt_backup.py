#!/usr/bin/env python3
"""Decrypts a Pass-Y encrypted backup (a Bitwarden password-protected encrypted JSON export) independently of the app
and prints the item and folder counts. For checking test backups only.

Usage: decrypt_backup.py <backup.json> [--password-env NAME] [--expect-items N] [--expect-folders N] [--dump]
The password is read from the environment variable NAME (default PASSY_BACKUP_PASSWORD), never from the command line.

Format (Bitwarden "encrypted JSON, password protected"): {"encrypted": true, "passwordProtected": true, "salt",
"kdfType" (0 = PBKDF2-SHA256, 1 = Argon2id), "kdfIterations", "kdfMemory", "kdfParallelism",
"encKeyValidation_DO_NOT_EDIT", "data"}. Key = KDF(password, salt), stretched with HKDF-Expand ("enc", "mac") to
an AES-256-CBC key and an HMAC-SHA256 key; "data" and the validation field are EncStrings of type 2
("2.<iv>|<ciphertext>|<mac>"). The MAC is checked before anything is decrypted.
"""
import argparse, base64, hashlib, hmac, json, os, sys
from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand


def derive_key(password: str, doc: dict) -> bytes:
    salt = doc["salt"].encode()
    if doc["kdfType"] == 0:
        master = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, int(doc["kdfIterations"]), 32)
    elif doc["kdfType"] == 1:
        from argon2.low_level import Type, hash_secret_raw  # optional dependency (argon2-cffi)
        master = hash_secret_raw(password.encode(), hashlib.sha256(salt).digest(), int(doc["kdfIterations"]),
                                 int(doc["kdfMemory"]) * 1024, int(doc["kdfParallelism"]), 32, Type.ID)
    else:
        sys.exit(f"unknown kdfType {doc['kdfType']}")
    return HKDFExpand(hashes.SHA256(), 32, b"enc").derive(master) + HKDFExpand(hashes.SHA256(), 32, b"mac").derive(master)


def decrypt(key: bytes, enc_string: str) -> bytes:
    kind, rest = enc_string.split(".", 1)
    if kind != "2":
        sys.exit(f"unexpected EncString type {kind}")
    iv, ct, mac = (base64.b64decode(part) for part in rest.split("|"))
    if not hmac.compare_digest(hmac.new(key[32:], iv + ct, hashlib.sha256).digest(), mac):
        sys.exit("MAC mismatch: wrong password or corrupted file")
    decryptor = Cipher(algorithms.AES(key[:32]), modes.CBC(iv)).decryptor()
    unpadder = padding.PKCS7(128).unpadder()
    return unpadder.update(decryptor.update(ct) + decryptor.finalize()) + unpadder.finalize()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file")
    parser.add_argument("--password-env", default="PASSY_BACKUP_PASSWORD")
    parser.add_argument("--expect-items", type=int)
    parser.add_argument("--expect-folders", type=int)
    parser.add_argument("--dump", action="store_true", help="print item types and names (test data only)")
    args = parser.parse_args()

    with open(args.file, encoding="utf-8") as handle:
        doc = json.load(handle)
    if doc.get("encrypted") is not True or doc.get("passwordProtected") is not True:
        sys.exit("not a password-protected encrypted export")
    password = os.environ.get(args.password_env)
    if not password:
        sys.exit(f"set the password in ${args.password_env}")

    key = derive_key(password, doc)
    decrypt(key, doc["encKeyValidation_DO_NOT_EDIT"])  # checks the password (MAC) first
    vault = json.loads(decrypt(key, doc["data"]))

    items, folders = vault.get("items", []), vault.get("folders", [])
    types = {}
    for item in items:
        types[item.get("type")] = types.get(item.get("type"), 0) + 1
    print(f"kdfType={doc['kdfType']} iterations={doc['kdfIterations']} encrypted(inner)={vault.get('encrypted')}")
    print(f"items={len(items)} folders={len(folders)} types={dict(sorted(types.items()))}")
    print(f"organization items={sum(1 for i in items if i.get('organizationId'))} "
          f"deleted items={sum(1 for i in items if i.get('deletedDate'))} "
          f"attachments={sum(len(i.get('attachments') or []) for i in items)} "
          f"collections={len(vault.get('collections') or [])} top-level keys={sorted(vault.keys())}")
    if args.dump:
        for item in items:
            print(f"  type={item.get('type')} name={item.get('name')!r} folder={item.get('folderId')}")
        for folder in folders:
            print(f"  folder {folder.get('name')!r}")

    ok = True
    if args.expect_items is not None and len(items) != args.expect_items:
        print(f"MISMATCH: expected {args.expect_items} items"); ok = False
    if args.expect_folders is not None and len(folders) != args.expect_folders:
        print(f"MISMATCH: expected {args.expect_folders} folders"); ok = False
    print("OK" if ok else "FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

"""AES-128 encrypt/decrypt blocks using externally supplied K0..K10.
This is transparent educational reference code, not constant-time or production safe.
Each block is 16 bytes. Arbitrary plaintext uses CBC+PKCS7 and HMAC-SHA256.
AES block transforms follow the standard Rijndael layout (column-major state).
"""
from __future__ import annotations
from hashlib import sha256
import hmac
import os
from aes_reference import aes_sbox, gf_mul, key_expansion

SBOX = tuple(aes_sbox(i) for i in range(256))
INV_SBOX = [0] * 256
for i, v in enumerate(SBOX):
    INV_SBOX[v] = i


def schedule_bytes(roundkeys: list[str]) -> list[bytes]:
    if len(roundkeys) != 11:
        raise ValueError('Round key input must contain K0 through K10 (11 x 128 bits).')
    try:
        keys = [bytes.fromhex(r) for r in roundkeys]
    except ValueError as e:
        raise ValueError('Invalid round key hex') from e
    if any(len(k) != 16 for k in keys):
        raise ValueError('Each round key must be exactly 16 bytes')
    return keys


def add_round_key(state: list[int], key: bytes) -> list[int]:
    return [state[i] ^ key[i] for i in range(16)]


def shift_rows(st: list[int], inverse=False) -> list[int]:
    out = [0]*16
    for row in range(4):
        for col in range(4):
            source_col = (col - row) % 4 if inverse else (col + row) % 4
            out[4*col+row] = st[4*source_col+row]
    return out


def mix_columns(st: list[int], inverse=False) -> list[int]:
    out = st[:]
    matrix = ((14,11,13,9),(9,14,11,13),(13,9,14,11),(11,13,9,14)) if inverse else (
             (2,3,1,1),(1,2,3,1),(1,1,2,3),(3,1,1,2))
    for col in range(4):
        values = st[4*col:4*col+4]
        for row in range(4):
            result = 0
            for k in range(4):
                result ^= gf_mul(matrix[row][k], values[k])
            out[4*col+row] = result
    return out


def encrypt_block(block: bytes, roundkeys: list[str]) -> bytes:
    if len(block) != 16:
        raise ValueError('AES block must be 16 bytes')
    keys = schedule_bytes(roundkeys)
    st = add_round_key(list(block), keys[0])
    for r in range(1,10):
        st = [SBOX[x] for x in st]
        st = shift_rows(st)
        st = mix_columns(st)
        st = add_round_key(st, keys[r])
    st = [SBOX[x] for x in st]
    st = shift_rows(st)
    st = add_round_key(st, keys[10])
    return bytes(st)


def decrypt_block(block: bytes, roundkeys: list[str]) -> bytes:
    if len(block) != 16:
        raise ValueError('AES block must be 16 bytes')
    keys = schedule_bytes(roundkeys)
    st = add_round_key(list(block), keys[10])
    for r in range(9,0,-1):
        st = shift_rows(st, inverse=True)
        st = [INV_SBOX[x] for x in st]
        st = add_round_key(st, keys[r])
        st = mix_columns(st, inverse=True)
    st = shift_rows(st, inverse=True)
    st = [INV_SBOX[x] for x in st]
    st = add_round_key(st, keys[0])
    return bytes(st)


def xor_bytes(a: bytes, b: bytes) -> bytes:
    return bytes(x ^ y for x, y in zip(a, b))


def pad16(payload: bytes) -> bytes:
    pad_len = 16 - (len(payload) % 16)
    return payload + bytes([pad_len] * pad_len)


def unpad16(payload: bytes) -> bytes:
    if not payload or len(payload) % 16:
        raise ValueError('Invalid ciphertext block alignment')
    n = payload[-1]
    if not (1 <= n <= 16) or payload[-n:] != bytes([n] * n):
        raise ValueError('Invalid PKCS7 padding')
    return payload[:-n]


def mac_key_from_master(key: bytes) -> bytes:
    # Demo-only key separation; do not use this handcrafted construction in production.
    return hmac.new(key, b'DE1-FPGA-TEST-AES128-CBC-HMAC-MACKEY-v1', sha256).digest()


def encrypt_cbc_hmac(master_key: bytes, roundkeys: list[str], plaintext: bytes) -> dict:
    iv = os.urandom(16)
    padded = pad16(plaintext)
    previous = iv
    ciphertext = bytearray()
    for p in range(0, len(padded), 16):
        block = xor_bytes(padded[p:p + 16], previous)
        previous = encrypt_block(block, roundkeys)
        ciphertext.extend(previous)
    content = b'DE1-CBC-HMAC-v1\x00' + iv + bytes(ciphertext)
    tag = hmac.new(mac_key_from_master(master_key), content, sha256).digest()
    return {
        'mode': 'AES-128-CBC+HMAC-SHA256 (demo)',
        'iv_hex': iv.hex().upper(),
        'ciphertext_hex': ciphertext.hex().upper(),
        'tag_hex': tag.hex().upper(),
    }


def decrypt_cbc_hmac(master_key: bytes, roundkeys: list[str], envelope: dict) -> bytes:
    if envelope.get('mode') != 'AES-128-CBC+HMAC-SHA256 (demo)':
        raise ValueError('Unsupported encryption mode')
    iv = bytes.fromhex(envelope['iv_hex'])
    ciphertext = bytes.fromhex(envelope['ciphertext_hex'])
    tag = bytes.fromhex(envelope['tag_hex'])
    if len(iv) != 16 or not ciphertext or len(ciphertext) % 16:
        raise ValueError('Invalid IV or ciphertext length')
    content = b'DE1-CBC-HMAC-v1\x00' + iv + ciphertext
    reference_tag = hmac.new(mac_key_from_master(master_key), content, sha256).digest()
    if not hmac.compare_digest(reference_tag, tag):
        raise ValueError('Authentication failed: ciphertext/IV/tag/key wrong or tampered')
    previous = iv
    result = bytearray()
    for p in range(0, len(ciphertext), 16):
        cb = ciphertext[p:p + 16]
        result.extend(xor_bytes(decrypt_block(cb, roundkeys), previous))
        previous = cb
    return unpad16(bytes(result))

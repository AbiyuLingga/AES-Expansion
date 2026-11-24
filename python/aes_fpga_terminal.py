#!/usr/bin/env python3
"""AES-128 FPGA Key Expansion + Python AES-CBC encryption and decryption.

UART protocol (115200 8N1, original Terasic DE1 MAX232 DB9):
  PC->FPGA: b'K' + 32 ASCII hex digits + b'\n'
  FPGA->PC: 11 lines: b'K00:' + 32 hex digits + b'\r\n' ... b'K10:'

Keys and round keys are printed/exported for EDUCATIONAL TEST KEYS ONLY.
"""
from __future__ import annotations
import argparse
import csv
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

from aes_reference import (NIST_KEY, NIST_ROUND_KEYS, SEQ_KEY,
                           SEQ_ROUND_KEYS, key_expansion)
from aes_with_fpga_roundkeys import (encrypt_block, decrypt_block,
                                     encrypt_cbc_hmac, decrypt_cbc_hmac)

LINE = re.compile(r'^K(\d\d):([0-9A-Fa-f]{32})$')


def key_from_hex(value: str) -> bytes:
    value = value.strip().replace(' ', '')
    if not re.fullmatch(r'[0-9a-fA-F]{32}', value):
        raise ValueError('Master key AES-128 must have exactly 32 hex digits (0-9, A-F).')
    return bytes.fromhex(value)


def get_serial():
    try:
        import serial
        from serial.tools import list_ports
    except ImportError as e:
        raise RuntimeError('PySerial belum terinstal: python -m pip install pyserial') from e
    return serial, list_ports


def available_ports():
    _, list_ports = get_serial()
    ports = list(list_ports.comports())
    if not ports:
        print('Tidak ada COM port ditemukan. Cek kabel, driver, dan Device Manager.')
    for item in ports:
        print(f'{item.device}: {item.description}')
    return ports


def read_roundkeys(port: str, key: bytes, baud: int = 115200) -> list[str]:
    serial, _ = get_serial()
    expected = key_expansion(key)
    collected: dict[int, str] = {}
    print(f'\n[HARDWARE FPGA] Buka {port} @ {baud}, 8N1')
    print('[TX] K' + key.hex().upper() + r'\n')
    try:
        with serial.Serial(port, baud, timeout=0.8, rtscts=False,
                           xonxoff=False, dsrdtr=False) as dev:
            dev.reset_input_buffer()
            dev.write(b'K' + key.hex().upper().encode('ascii') + b'\n')
            dev.flush()
            deadline = time.monotonic() + 15
            while len(collected) != 11 and time.monotonic() < deadline:
                raw = dev.readline()
                if not raw:
                    continue
                text = raw.decode('ascii', errors='replace').strip()
                parsed = LINE.fullmatch(text)
                if not parsed:
                    print(f'[RX?] {text!r} (ignored)')
                    continue
                round_no = int(parsed.group(1))
                value = parsed.group(2).upper()
                if round_no > 10:
                    continue
                if round_no != len(collected):
                    raise RuntimeError(
                        f'Round keys out of order: expected K{len(collected):02}, got K{round_no:02}. '
                        'Check cable/baud; press KEY0 to reset if needed.')
                collected[round_no] = value
                verdict = 'PASS' if value == expected[round_no] else 'FAIL'
                print(f'[RX] K{round_no:02}: {value} | {verdict}')
    except serial.SerialException as e:
        raise RuntimeError(
            f'Gagal membuka/membaca {port}: {e}. Tutup RealTerm. '
            'Jika CH340 gagal membuka port, perbaiki driver dahulu. '
            'Pastikan USB-to-RS232 DB9, bukan TTL ke DB9.') from e
    if len(collected) != 11:
        raise RuntimeError(
            f'Timeout: hanya {len(collected)}/11 round key diterima. '
            'Cek UART_RXD=F14, UART_TXD=G12, baud 115200, sambungan DB9 TX/RX '
            '(mungkin perlu null-modem), dan bitstream AES versi baru.')
    received = [collected[i] for i in range(11)]
    if received != expected:
        mismatches = [i for i in range(11) if received[i] != expected[i]]
        raise RuntimeError(f'FPGA round keys berbeda dari referensi Python pada {mismatches}. '
                           'Enkripsi dibatalkan demi menghindari hasil yang keliru.')
    print('[OK] 11 round key FPGA cocok dengan referensi Python.')
    return received


def crypt_roundtrip(key: bytes, plaintext: str, roundkeys: list[str]) -> dict:
    """Round keys RECEIVED from FPGA (not recomputed inside AES encryption)."""
    envelope = encrypt_cbc_hmac(key, roundkeys, plaintext.encode('utf-8'))
    decrypted = decrypt_cbc_hmac(key, roundkeys, envelope).decode('utf-8')
    return {**envelope, 'decrypted_text': decrypted, 'plaintext_text': plaintext}


def decrypt_saved(key: bytes, filename: str) -> str:
    # When opening a saved envelope without the FPGA, reconstruct schedule locally.
    obj = json.loads(Path(filename).read_text(encoding='utf-8'))
    return decrypt_cbc_hmac(key, key_expansion(key), obj).decode('utf-8')


def append_csv(filename: Path, header: list[str], rows: list[list[str]]) -> None:
    filename.parent.mkdir(parents=True, exist_ok=True)
    exists = filename.exists() and filename.stat().st_size > 0
    with filename.open('a', encoding='utf-8-sig', newline='') as f:
        wr = csv.writer(f)
        if not exists:
            wr.writerow(header)
        wr.writerows(rows)


def save_result(folder: Path, source: str, key: bytes,
                actual: list[str], result: dict) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f')
    ref = key_expansion(key)
    append_csv(folder / 'hasil_roundkeys.csv',
               ['waktu','sumber','master_key_hex','round','roundkey_fpga','roundkey_ref','status'],
               [[stamp,source,key.hex().upper(),f'K{i:02}',actual[i],ref[i],
                 'PASS' if actual[i] == ref[i] else 'FAIL'] for i in range(11)])
    append_csv(folder / 'riwayat_enkripsi.csv',
               ['waktu','sumber','mode','plaintext','iv_hex','ciphertext_hex',
                'tag_hex','decrypted_text','status'],
               [[stamp,source,result['mode'],result['plaintext_text'],
                 result['iv_hex'],result['ciphertext_hex'],result['tag_hex'],
                 result['decrypted_text'],'PASS' if result['decrypted_text']==result['plaintext_text'] else 'FAIL']])
    envelope = {k: result[k] for k in ['mode','iv_hex','ciphertext_hex','tag_hex']}
    json_path = folder / f'pesan_terenkripsi_{stamp}.json'
    json_path.write_text(json.dumps(envelope, indent=2) + '\n', encoding='utf-8')
    print('\n[FILE] CSV round keys  :', folder / 'hasil_roundkeys.csv')
    print('[FILE] CSV encryption  :', folder / 'riwayat_enkripsi.csv')
    print('[FILE] Cipher JSON     :', json_path)
    print('[NOTE] CSV roundkeys contains the master key; testing only. Do not use real secrets.')


def self_test() -> None:
    assert key_expansion(bytes.fromhex(NIST_KEY)) == NIST_ROUND_KEYS
    assert key_expansion(bytes.fromhex(SEQ_KEY)) == SEQ_ROUND_KEYS
    assert aes_sbox_quickcheck() is True
    k = bytes.fromhex(NIST_KEY)
    p = bytes.fromhex('6BC1BEE22E409F96E93D7E117393172A')
    c = encrypt_block(p, NIST_ROUND_KEYS)
    assert c.hex().upper() == '3AD77BB40D7A3660A89ECAF32466EF97'
    assert decrypt_block(c, NIST_ROUND_KEYS) == p
    assert encrypt_block(bytes.fromhex('00112233445566778899AABBCCDDEEFF'), SEQ_ROUND_KEYS).hex().upper() == '69C4E0D86A7B0430D8CDB78070B4C55A'
    for _ in range(20):
        random_key = os.urandom(16)
        random_schedule = key_expansion(random_key)
        message = os.urandom(16)
        assert decrypt_block(encrypt_block(message, random_schedule), random_schedule) == message
    envelope = encrypt_cbc_hmac(k, NIST_ROUND_KEYS, 'Unit test AES CBC FPGA'.encode())
    assert decrypt_cbc_hmac(k, NIST_ROUND_KEYS, envelope) == b'Unit test AES CBC FPGA'
    tampered = dict(envelope)
    tampered['ciphertext_hex'] = ('00' if envelope['ciphertext_hex'][:2] != '00' else '01') + envelope['ciphertext_hex'][2:]
    try:
        decrypt_cbc_hmac(k, NIST_ROUND_KEYS, tampered)
    except ValueError:
        pass
    else:
        raise AssertionError('Tampering was not detected')
    print('SELFTEST PASS: 2 key schedules, 2 AES-128 block vectors, 20 random block roundtrips,')
    print('               CBC encryption/decryption and altered ciphertext rejection')
    print('NOTE: Selftest only verifies Python. It does NOT exercise the physical FPGA.')


def aes_sbox_quickcheck() -> bool:
    from aes_reference import aes_sbox
    return aes_sbox(0x53) == 0xED and aes_sbox(0) == 0x63


def run_one(args, key_text: str, plaintext: str) -> None:
    key = key_from_hex(key_text)
    ref = key_expansion(key)
    if args.offline:
        source = 'OFFLINE_SOFTWARE_ONLY'
        print('\n*** OFFLINE MODE: FPGA TIDAK DIHUBUNGI; ini bukan bukti hasil board ***')
        actual = ref
        for i, r in enumerate(actual):
            print(f'[SW] K{i:02}: {r} | REFERENCE ONLY')
    else:
        if not args.port:
            raise ValueError('Masukkan COM port: --port COM8')
        source = f'FPGA_{args.port.upper()}'
        actual = read_roundkeys(args.port, key, args.baud)
    encrypted = crypt_roundtrip(key, plaintext, actual)
    print('\n===== AES-128-CBC ENKRIPSI DI PYTHON (PAKAI ROUND KEY FPGA) =====')
    print('Input master key :', key.hex().upper())
    print('Input plaintext  :', plaintext)
    print('IV (128 bit)    :', encrypted['iv_hex'])
    print('Ciphertext (hex) :', encrypted['ciphertext_hex'] or '(empty)')
    print('HMAC-SHA256 tag  :', encrypted['tag_hex'])
    print('\n===== AES-128-CBC DEKRIPSI DI PYTHON =====')
    print('Plaintext hasil  :', encrypted['decrypted_text'])
    print('VERIFIKASI       : PASS' if plaintext == encrypted['decrypted_text'] else 'VERIFIKASI: FAIL')
    save_result(Path(args.output), source, key, actual, encrypted)


def main() -> int:
    p = argparse.ArgumentParser(description='AES-128: Python key/plaintext -> FPGA round keys -> Python CBC+HMAC enc/dec')
    p.add_argument('--port', help='COM8, COM3, etc (USB-RS232 adaptor)')
    p.add_argument('--baud', type=int, default=115200)
    p.add_argument('--key', '--master-key', dest='key', help='32 hexadecimal digits, AES-128')
    p.add_argument('--text', '--plaintext', dest='text', help='Teks yang akan dienkripsi')
    p.add_argument('--output', default='hasil', help='Folder hasil CSV dan JSON')
    p.add_argument('--list', action='store_true', help='Lihat port serial yang tersedia')
    p.add_argument('--selftest', action='store_true', help='Uji referensi AES menggunakan Python saja')
    p.add_argument('--offline', action='store_true', help='Demo software TANPA FPGA, jelas dilabeli')
    p.add_argument('--decrypt-file', help='Dekripsi JSON ciphertext yang disimpan sebelumnya')
    a = p.parse_args()
    try:
        if a.list:
            available_ports()
            return 0
        if a.selftest:
            self_test()
            return 0
        if a.decrypt_file:
            key = key_from_hex(a.key or input('Master key (32 hex): '))
            print('HASIL DEKRIPSI:', decrypt_saved(key, a.decrypt_file))
            return 0
        if not a.offline and not a.port:
            available_ports()
            a.port = input('Masukkan COM port (mis. COM8): ').strip().upper()
        while True:
            key_text = a.key if a.key is not None else input('\nMaster key AES-128 (32 hex, kosong=NIST): ').strip() or NIST_KEY
            plaintext = a.text if a.text is not None else input('Plaintext UTF-8: ')
            run_one(a, key_text, plaintext)
            if a.key is not None and a.text is not None:
                break
            again = input('\nUlangi dengan master key / plaintext baru? [y/N] ').strip().lower()
            if again not in ('y','yes','ya'):
                break
        return 0
    except KeyboardInterrupt:
        print('\nDibatalkan pengguna')
        return 130
    except Exception as e:
        print('\nERROR:', e, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

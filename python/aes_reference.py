"""Independent pure-Python AES-128 key schedule for comparing against FPGA.
Uses algebraic S-Box construction, not the FPGA's LUT table.
This code is for functional validation, not constant-time cryptography.
"""


def gf_mul(a: int, b: int) -> int:
    out = 0
    for _ in range(8):
        if b & 1:
            out ^= a
        a = (a << 1) ^ (0x11B if a & 0x80 else 0)
        a &= 0xFF
        b >>= 1
    return out


def gf_pow(a: int, n: int) -> int:
    out = 1
    while n:
        if n & 1:
            out = gf_mul(out, a)
        a = gf_mul(a, a)
        n >>= 1
    return out


def rotl8(v: int, n: int) -> int:
    return ((v << n) | (v >> (8 - n))) & 0xFF


def aes_sbox(x: int) -> int:
    inv = gf_pow(x, 254) if x else 0
    return inv ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63


def key_expansion(key: bytes) -> list[str]:
    if len(key) != 16:
        raise ValueError('AES-128 master key must be exactly 16 bytes')
    words = [list(key[i:i + 4]) for i in range(0, 16, 4)]
    rcon = 1
    for i in range(4, 44):
        temp = words[i - 1][:]
        if i % 4 == 0:
            temp = temp[1:] + temp[:1]
            temp = [aes_sbox(x) for x in temp]
            temp[0] ^= rcon
            rcon = gf_mul(rcon, 2)
        words.append([a ^ b for a, b in zip(words[i - 4], temp)])
    return [''.join(f'{x:02X}' for w in words[i:i + 4] for x in w)
            for i in range(0, 44, 4)]


NIST_KEY = '2B7E151628AED2A6ABF7158809CF4F3C'
NIST_ROUND_KEYS = [
    '2B7E151628AED2A6ABF7158809CF4F3C',
    'A0FAFE1788542CB123A339392A6C7605',
    'F2C295F27A96B9435935807A7359F67F',
    '3D80477D4716FE3E1E237E446D7A883B',
    'EF44A541A8525B7FB671253BDB0BAD00',
    'D4D1C6F87C839D87CAF2B8BC11F915BC',
    '6D88A37A110B3EFDDBF98641CA0093FD',
    '4E54F70E5F5FC9F384A64FB24EA6DC4F',
    'EAD27321B58DBAD2312BF5607F8D292F',
    'AC7766F319FADC2128D12941575C006E',
    'D014F9A8C9EE2589E13F0CC8B6630CA6',
]
SEQ_KEY = '000102030405060708090A0B0C0D0E0F'
SEQ_ROUND_KEYS = [
    '000102030405060708090A0B0C0D0E0F',
    'D6AA74FDD2AF72FADAA678F1D6AB76FE',
    'B692CF0B643DBDF1BE9BC5006830B3FE',
    'B6FF744ED2C2C9BF6C590CBF0469BF41',
    '47F7F7BC95353E03F96C32BCFD058DFD',
    '3CAAA3E8A99F9DEB50F3AF57ADF622AA',
    '5E390F7DF7A69296A7553DC10AA31F6B',
    '14F9701AE35FE28C440ADF4D4EA9C026',
    '47438735A41C65B9E016BAF4AEBF7AD2',
    '549932D1F08557681093ED9CBE2C974E',
    '13111D7FE3944A17F307A78B4D2B30C5',
]

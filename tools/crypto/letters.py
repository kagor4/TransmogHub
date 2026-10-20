#!/usr/bin/env python3
"""Шифрование писем разработчику и обращений (RSA-1024 без внешних библиотек).

Аддон шифрует открытым ключом (Data/LetterKey.lua); закрытый ключ лежит только
в закрытом репозитории (secrets/letters.key) и нужен ежедневной задаче.

  python3 tools/crypto/letters.py keygen <файл закрытого ключа> <Data/LetterKey.lua>
  python3 tools/crypto/letters.py decrypt <файл закрытого ключа> <ideas.tsv|appeals.tsv> [вывод]
  python3 tools/crypto/letters.py selftest

Шифровка в тексте: «~» и base64 (алфавит 0-9A-Za-z+/) из блоков по 128 байт.
Блок до шифрования: 0x01, 8 случайных байт, длина, до 100 байт данных.
Внутри: «имя\\tтекст» (UTF-8). Расшифрованная строка ideas.tsv / appeals.tsv
получает настоящее имя вместо метки и текст вместо шифровки.
"""
import secrets
import sys

E = 65537
BITS = 1024
BLOCK = 128
LIMB = 24
ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"


def is_probable_prime(n, rounds=40):
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for _ in range(rounds):
        a = secrets.randbelow(n - 3) + 2
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def gen_prime(bits):
    while True:
        p = secrets.randbits(bits) | (1 << (bits - 1)) | (1 << (bits - 2)) | 1
        if p % E != 1 and is_probable_prime(p):
            return p


def keygen():
    while True:
        p, q = gen_prime(BITS // 2), gen_prime(BITS // 2)
        n = p * q
        if p != q and n.bit_length() == BITS:
            d = pow(E, -1, (p - 1) * (q - 1))
            return n, d


def limbs(x, k):
    out = []
    for _ in range(k):
        out.append(x & ((1 << LIMB) - 1))
        x >>= LIMB
    return out


def lua_public(n):
    k = (BITS + LIMB - 1) // LIMB + 1  # с запасом: n < B^k
    r2 = pow(1 << (LIMB * k), 2, n)
    n0inv = (-pow(n, -1, 1 << LIMB)) % (1 << LIMB)
    def lst(v):
        return "{ " + ", ".join(str(x) for x in limbs(v, k)) + " }"
    return ("-- Открытый ключ для шифрования писем и обращений (tools/crypto/letters.py keygen).\n"
            "-- Закрытый ключ — только в закрытом репозитории модератора.\n"
            "TransmogHub_LetterKey = {\n"
            f"\tk = {k},\n\tn0inv = {n0inv},\n\tn = {lst(n)},\n\tr2 = {lst(r2)},\n}}\n")


def b64decode(s):
    v, bits, out = 0, 0, bytearray()
    for ch in s:
        v = (v << 6) | ALPHA.index(ch)
        bits += 6
        if bits >= 8:
            bits -= 8
            out.append((v >> bits) & 0xFF)
    return bytes(out)


def b64encode(b):
    out, v, bits = [], 0, 0
    for byte in b:
        v = (v << 8) | byte
        bits += 8
        while bits >= 6:
            bits -= 6
            out.append(ALPHA[(v >> bits) & 63])
    if bits:
        out.append(ALPHA[(v << (6 - bits)) & 63])
    return "".join(out)


def decrypt_text(cipher, n, d):
    """«~…» -> исходные байты (имя\\tтекст), или None, если не расшифровалось."""
    if not cipher.startswith("~"):
        return None
    raw = b64decode(cipher[1:])
    if len(raw) % BLOCK:
        raw = raw[: len(raw) - len(raw) % BLOCK]
    out = bytearray()
    for i in range(0, len(raw), BLOCK):
        m = pow(int.from_bytes(raw[i:i + BLOCK], "big"), d, n)
        mb = m.to_bytes((m.bit_length() + 7) // 8, "big")
        if len(mb) < 10 or mb[0] != 1 or mb[9] > len(mb) - 10:
            return None
        out += mb[10:10 + mb[9]]
    return bytes(out)


def encrypt_text(data, n):
    """Для самопроверки: так же, как аддон."""
    out = bytearray()
    for i in range(0, max(len(data), 1), 100):
        piece = data[i:i + 100]
        block = bytes([1]) + secrets.token_bytes(8) + bytes([len(piece)]) + piece
        out += pow(int.from_bytes(block, "big"), E, n).to_bytes(BLOCK, "big")
    return "~" + b64encode(bytes(out))


def read_key(path):
    vals = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                vals[k] = int(v, 16)
    return vals["n"], vals["d"]


def decrypt_file(keyfile, path, out_path=None):
    n, d = read_key(keyfile)
    lines = open(path, encoding="utf-8").read().splitlines()
    out, done, bad = [], 0, 0
    for line in lines:
        f = line.split("|")
        # ideas: 1|кто|время|вид|текст; appeals: 1|кто|время|текст
        idx = len(f) - 1
        if len(f) >= 4 and f[idx].startswith("~"):
            plain = decrypt_text(f[idx], n, d)
            if plain is None:
                bad += 1
            else:
                name, _, text = plain.decode("utf-8", "replace").partition("\t")
                f[1], f[idx] = name, text.replace("|", "/")
                done += 1
        out.append("|".join(f))
    data = "\n".join(out) + ("\n" if out else "")
    if out_path:
        open(out_path, "w", encoding="utf-8").write(data)
    else:
        sys.stdout.write(data)
    sys.stderr.write(f"{path}: расшифровано {done}, не удалось {bad}\n")


def selftest():
    n, d = keygen()
    for text in ["", "Кагор-Ревущийфьорд\tПривет", "x" * 250, "Я-Сервер\t" + "длинное письмо " * 40]:
        data = text.encode()
        assert decrypt_text(encrypt_text(data, n), n, d) == data
    assert b64decode(b64encode(b"\x00\xff\x10abc")) == b"\x00\xff\x10abc"
    print("CRYPTO PY OK")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "keygen":
        n, d = keygen()
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            f.write(f"n={n:x}\nd={d:x}\n")
        with open(sys.argv[3], "w", encoding="utf-8") as f:
            f.write(lua_public(n))
        print("ключ создан")
    elif cmd == "decrypt":
        decrypt_file(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif cmd == "selftest":
        selftest()
    else:
        print(__doc__)
        sys.exit(1)

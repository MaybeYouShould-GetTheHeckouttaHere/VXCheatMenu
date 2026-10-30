"""Build an RGSS3 scripts archive without a Ruby installation (stdlib only)."""
from pathlib import Path
import zlib


def integer(n):
    if n == 0:
        return b'\x00'
    if 0 < n < 123:
        return bytes([n + 5])
    size = (n.bit_length() + 7) // 8
    return bytes([size]) + n.to_bytes(size, 'little')


def marshal(value):
    if isinstance(value, int):
        return b'i' + integer(value)
    if isinstance(value, bytes):
        return b'"' + integer(len(value)) + value
    if isinstance(value, list):
        return b'[' + integer(len(value)) + b''.join(map(marshal, value))
    raise TypeError(type(value))


def build():
    root = Path(__file__).resolve().parent
    source = (root / 'cheat/bootstrap.rb').read_bytes()
    archive = b'\x04\x08' + marshal([[1, b'VXCheat bootstrap', zlib.compress(source)]])
    (root / 'cheat/bootstrap.rvdata2').write_bytes(archive)


if __name__ == '__main__':
    build()

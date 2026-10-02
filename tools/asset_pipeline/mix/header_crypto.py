"""加密 MIX 头部的解密。

Westwood 的方案：头部用 Blowfish 加密；Blowfish 密钥又被 RSA 公钥加密后放在头部前 80 字节。
这是公开已知的混淆（公钥常量写在 OpenRA、XCC 等开源项目里），不是密码保护。

Blowfish 为标准 ECB（实测无需字节翻转：解出的文件数与数据大小和实际文件大小吻合）。
"""

from __future__ import annotations

import base64

from Crypto.Cipher import Blowfish

_PUBLIC_KEY_B64 = "AihRvNoIbTn85FZRYNZRcT+i6KpU+maCsEqr3Q5q+LDB5tH7Tz2qQ38V"
_EXPONENT = 0x10001
KEY_BLOCK_SIZE = 80


def _modulus() -> int:
    der = base64.b64decode(_PUBLIC_KEY_B64)
    # ASN.1 INTEGER: 0x02 <len> <big-endian 数值>
    assert der[0] == 0x02
    return int.from_bytes(der[2 : 2 + der[1]], "big")


def decrypt_blowfish_key(key_block: bytes) -> bytes:
    """80 字节密钥块 -> 56 字节 Blowfish 密钥。"""
    n = _modulus()
    in_size = (n.bit_length() - 1) // 8 + 1  # 40
    out_size = in_size - 1  # 39
    key = b""
    for off in range(0, KEY_BLOCK_SIZE, in_size):
        c = int.from_bytes(key_block[off : off + in_size], "little")
        key += pow(c, _EXPONENT, n).to_bytes(in_size, "little")[:out_size]
    return key[:56]


def decrypt_blocks(key: bytes, data: bytes) -> bytes:
    """解密 8 字节对齐的数据（ECB）。"""
    cipher = Blowfish.new(key, Blowfish.MODE_ECB)
    return cipher.decrypt(data)

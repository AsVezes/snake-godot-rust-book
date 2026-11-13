"""Header-only sanity checks for native GDExtension binaries.

These checks catch wrong file type/CPU before staging. They do not validate
loadability, dependencies, ABI compatibility, digital signatures, or safety.
"""

from pathlib import Path


def verify_native_binary(path: Path, platform: str) -> None:
    with path.open('rb') as stream:
        head = stream.read(4096)

    if platform == 'linux':
        if (
            len(head) < 64
            or head[:4] != b'\x7fELF'
            or head[4] != 2  # 64-bit
            or head[5] != 1  # little-endian
            or int.from_bytes(head[16:18], 'little') != 3  # ET_DYN
            or int.from_bytes(head[18:20], 'little') != 62  # x86_64
        ):
            raise ValueError(f'{path.name}: expected a 64-bit x86_64 ELF shared library for Linux')
    elif platform == 'windows':
        if len(head) < 64 or head[:2] != b'MZ':
            raise ValueError(f'{path.name}: expected Windows PE DLL (missing MZ header)')
        pe_offset = int.from_bytes(head[0x3c:0x40], 'little')
        # COFF header: Machine (+4), Characteristics (+22). Optional header
        # starts at +24; PE32+ magic 0x20b is required for x86_64 DLLs.
        # A PE executable with an .dll filename must not pass this gate.
        if (
            pe_offset < 64
            or pe_offset + 26 > len(head)
            or head[pe_offset:pe_offset + 4] != b'PE\x00\x00'
            or int.from_bytes(head[pe_offset + 4:pe_offset + 6], 'little') != 0x8664
            or not (int.from_bytes(head[pe_offset + 22:pe_offset + 24], 'little') & 0x2000)
            or int.from_bytes(head[pe_offset + 24:pe_offset + 26], 'little') != 0x20b
        ):
            raise ValueError(f'{path.name}: expected x86_64 Windows PE32+ DLL')
    elif platform == 'macos':
        # 64-bit thin Mach-O or universal/fat binaries. Macs may use x86_64
        # or arm64; the operator must still test on the actual target machine.
        if len(head) < 32:
            raise ValueError(f'{path.name}: too short for macOS dylib')
        magic = head[:4]
        if magic in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf'):
            endian = 'little' if magic == b'\xcf\xfa\xed\xfe' else 'big'
            cpu = int.from_bytes(head[4:8], endian)
            file_type = int.from_bytes(head[12:16], endian)
            if cpu not in (0x01000007, 0x0100000c) or file_type != 6:
                raise ValueError(f'{path.name}: expected 64-bit macOS Mach-O dylib')
        elif magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
            count = int.from_bytes(head[4:8], 'big')
            if not 1 <= count <= 32:
                raise ValueError(f'{path.name}: invalid macOS universal Mach-O header')
        else:
            raise ValueError(f'{path.name}: expected Mach-O dylib for macOS')
    else:
        raise ValueError(f'Unsupported platform: {platform}')

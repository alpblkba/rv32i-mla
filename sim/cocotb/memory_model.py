"""Python model of bram0, the 2048 x 32-bit block RAM that the CPU reaches through its dmem_* port.

The model follows the port B configuration in rv32i_mla_bd_bram0_0.xci: 8 KiB of little-endian storage, the word selected by addr[12:2], one cycle of read latency without output registers, WRITE_FIRST and four byte write lanes. The latency is a parameter so that the two-cycle model of the old Verilog testbench can be reproduced on purpose.

clock() stands for one rising edge of clkb. The caller passes the port values sampled before that edge and receives the doutb value that holds after it. Addresses are byte addresses, and this file is the only place that turns them into word indices.
"""

SIZE = 0x2000
WORDS = SIZE // 4


class MemoryAccessError(Exception):
    pass


class Bram:
    def __init__(self, latency=1):
        if latency < 1:
            raise ValueError(f"read latency must be at least 1, got {latency}")
        self.data = bytearray(SIZE)
        # out[0] is the BRAM output latch; out[1:] are extra output register stages for latency > 1.
        self.out = [0] * latency
        self.writes = []

    def index(self, addr):
        if not 0 <= addr < SIZE:
            raise MemoryAccessError(f"address 0x{addr:x} is outside the modelled memory 0x0000-0x{SIZE - 1:04x}")
        return addr >> 2  # addr[12:2]; addr[1:0] selects no word, as in blk_mem_gen

    def load(self, addr, blob):
        """Backdoor write of raw bytes, used to place a program image before reset."""
        if addr < 0 or addr + len(blob) > SIZE:
            raise MemoryAccessError(f"image bytes 0x{addr:x}-0x{addr + len(blob) - 1:x} do not fit in 0x0000-0x{SIZE - 1:04x}")
        self.data[addr:addr + len(blob)] = blob

    def word(self, addr):
        """Backdoor read of the word that holds byte address addr."""
        i = self.index(addr) * 4
        return int.from_bytes(self.data[i:i + 4], "little")

    def clock(self, en, addr, wdata=0, mask=0):
        """One rising edge. mask has one bit per byte lane, bit 0 for bits 7:0. Returns doutb after the edge."""
        for i in range(len(self.out) - 1, 0, -1):
            self.out[i] = self.out[i - 1]
        if en:
            base = self.index(addr) * 4
            if mask:
                for lane in range(4):
                    if mask >> lane & 1:
                        self.data[base + lane] = wdata >> (8 * lane) & 0xFF
                self.writes.append((addr, wdata, mask))
            # WRITE_FIRST: on a write, doutb shows the word as it is after the write.
            self.out[0] = int.from_bytes(self.data[base:base + 4], "little")
        # With en low the latch keeps its value and nothing is written.
        return self.out[-1]

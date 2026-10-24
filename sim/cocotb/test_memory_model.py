"""Unit tests of memory_model.Bram without a simulator. Every expected value is a literal written by hand, not a value computed by the model."""

import unittest

from memory_model import Bram, MemoryAccessError


def write(m, addr, value, mask=0xF):
    return m.clock(1, addr, value, mask)


def read(m, addr):
    return m.clock(1, addr)


class Layout(unittest.TestCase):
    def test_little_endian_bytes(self):
        m = Bram()
        m.load(0x10, bytes([0x01, 0x02, 0x03, 0x04]))
        self.assertEqual(m.word(0x10), 0x04030201)
        self.assertEqual(read(m, 0x10), 0x04030201)

    def test_full_word_write_lands_in_byte_order(self):
        m = Bram()
        write(m, 0x20, 0x11223344)
        self.assertEqual(bytes(m.data[0x20:0x24]), bytes([0x44, 0x33, 0x22, 0x11]))

    def test_byte_addresses_0_4_8_select_words_0_1_2(self):
        m = Bram()
        write(m, 0, 0xAAAA0000)
        write(m, 4, 0xBBBB0001)
        write(m, 8, 0xCCCC0002)
        self.assertEqual(bytes(m.data[0:12]), bytes([0x00, 0x00, 0xAA, 0xAA, 0x01, 0x00, 0xBB, 0xBB, 0x02, 0x00, 0xCC, 0xCC]))
        self.assertEqual(read(m, 0), 0xAAAA0000)
        self.assertEqual(read(m, 4), 0xBBBB0001)
        self.assertEqual(read(m, 8), 0xCCCC0002)

    def test_neighbouring_words_stay_distinct(self):
        m = Bram()
        write(m, 0x100, 0x01010101)
        write(m, 0x104, 0x02020202)
        write(m, 0x0FC, 0x03030303)
        self.assertEqual(read(m, 0x100), 0x01010101)
        self.assertEqual(read(m, 0x104), 0x02020202)
        self.assertEqual(read(m, 0x0FC), 0x03030303)

    def test_low_address_bits_do_not_select_a_word(self):
        m = Bram()
        write(m, 0x40, 0xDEADBEEF)
        self.assertEqual(read(m, 0x41), 0xDEADBEEF)
        self.assertEqual(read(m, 0x43), 0xDEADBEEF)
        write(m, 0x46, 0x12345678)
        self.assertEqual(m.word(0x44), 0x12345678)

    def test_first_and_last_word(self):
        m = Bram()
        write(m, 0x0000, 0x0BADF00D)
        write(m, 0x1FFC, 0xCAFEF00D)
        self.assertEqual(read(m, 0x0000), 0x0BADF00D)
        self.assertEqual(read(m, 0x1FFC), 0xCAFEF00D)
        self.assertEqual(bytes(m.data[0x1FFC:0x2000]), bytes([0x0D, 0xF0, 0xFE, 0xCA]))


class Lanes(unittest.TestCase):
    BASE = 0xA1B2C3D4
    NEW = 0x55667788

    def lanes(self, mask):
        m = Bram()
        write(m, 0x200, self.BASE)
        write(m, 0x200, self.NEW, mask)
        return m.word(0x200)

    def test_single_lanes(self):
        self.assertEqual(self.lanes(0b0001), 0xA1B2C388)
        self.assertEqual(self.lanes(0b0010), 0xA1B277D4)
        self.assertEqual(self.lanes(0b0100), 0xA166C3D4)
        self.assertEqual(self.lanes(0b1000), 0x55B2C3D4)

    def test_lane_pairs(self):
        self.assertEqual(self.lanes(0b0011), 0xA1B27788)
        self.assertEqual(self.lanes(0b1100), 0x5566C3D4)
        self.assertEqual(self.lanes(0b0101), 0xA166C388)
        self.assertEqual(self.lanes(0b1001), 0x55B2C388)

    def test_all_lanes_and_no_lanes(self):
        self.assertEqual(self.lanes(0b1111), 0x55667788)
        self.assertEqual(self.lanes(0b0000), 0xA1B2C3D4)

    def test_lane_write_leaves_neighbour_words(self):
        m = Bram()
        write(m, 0x1FC, 0x11111111)
        write(m, 0x204, 0x22222222)
        write(m, 0x200, 0x99999999, 0b0110)
        self.assertEqual(m.word(0x1FC), 0x11111111)
        self.assertEqual(m.word(0x200), 0x00999900)
        self.assertEqual(m.word(0x204), 0x22222222)


class Timing(unittest.TestCase):
    def test_latency_one(self):
        m = Bram()
        m.load(0x0, bytes([0x11, 0, 0, 0, 0x22, 0, 0, 0]))
        self.assertEqual(m.clock(1, 0x0), 0x11)
        self.assertEqual(m.clock(1, 0x4), 0x22)
        self.assertEqual(m.clock(1, 0x0), 0x11)

    def test_latency_two(self):
        m = Bram(latency=2)
        m.load(0x0, bytes([0x11, 0, 0, 0, 0x22, 0, 0, 0]))
        self.assertEqual(m.clock(1, 0x0), 0x00)
        self.assertEqual(m.clock(1, 0x4), 0x11)
        self.assertEqual(m.clock(1, 0x0), 0x22)
        self.assertEqual(m.clock(1, 0x0), 0x11)

    def test_write_first_collision(self):
        m = Bram()
        write(m, 0x80, 0x01020304)
        self.assertEqual(m.clock(1, 0x80, 0xF0E0D0C0, 0xF), 0xF0E0D0C0)
        self.assertEqual(m.clock(1, 0x80, 0xAABBCCDD, 0b0001), 0xF0E0D0DD)

    def test_disabled_port_writes_nothing_and_holds_output(self):
        m = Bram()
        write(m, 0x30, 0x13579BDF)
        self.assertEqual(read(m, 0x30), 0x13579BDF)
        self.assertEqual(m.clock(0, 0x30, 0xFFFFFFFF, 0xF), 0x13579BDF)
        self.assertEqual(m.word(0x30), 0x13579BDF)
        self.assertEqual(m.clock(0, 0x34), 0x13579BDF)
        self.assertEqual(m.writes, [(0x30, 0x13579BDF, 0xF)])

    def test_disabled_port_ignores_out_of_range_address(self):
        m = Bram()
        self.assertEqual(m.clock(0, 0x4000), 0)


class Range(unittest.TestCase):
    def test_reads_and_writes_at_or_above_0x2000_raise(self):
        m = Bram()
        for addr in (0x2000, 0x2003, 0xFFFFFFFC):
            with self.assertRaises(MemoryAccessError):
                read(m, addr)
            with self.assertRaises(MemoryAccessError):
                write(m, addr, 1)
        self.assertEqual(m.writes, [])
        self.assertEqual(bytes(m.data), bytes(0x2000))

    def test_last_byte_address_is_in_range(self):
        m = Bram()
        write(m, 0x1FFF, 0x7E7E7E7E)
        self.assertEqual(m.word(0x1FFC), 0x7E7E7E7E)

    def test_image_must_fit(self):
        m = Bram()
        m.load(0x1FFC, bytes(4))
        with self.assertRaises(MemoryAccessError):
            m.load(0x1FFD, bytes(4))

    def test_latency_below_one_is_rejected(self):
        with self.assertRaises(ValueError):
            Bram(latency=0)


class Reinit(unittest.TestCase):
    def test_new_instance_starts_zeroed(self):
        m = Bram()
        write(m, 0x100, 0x12345678)
        n = Bram()
        self.assertEqual(n.word(0x100), 0)
        self.assertEqual(n.clock(1, 0x100), 0)
        self.assertEqual(n.writes, [])
        self.assertEqual(bytes(n.data), bytes(0x2000))


if __name__ == "__main__":
    unittest.main()

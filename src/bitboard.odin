package main

import "core:fmt"
import "core:math/bits"
import "base:intrinsics"

BitBoard :: distinct u64

RANK_1: BitBoard : 0x00000000000000FF
RANK_2: BitBoard : 0x000000000000FF00
RANK_3: BitBoard : 0x0000000000FF0000
RANK_4: BitBoard : 0x00000000FF000000
RANK_5: BitBoard : 0x000000FF00000000
RANK_6: BitBoard : 0x0000FF0000000000
RANK_7: BitBoard : 0x00FF000000000000
RANK_8: BitBoard : 0xFF00000000000000

FILE_A: BitBoard : 0x0101010101010101
FILE_B: BitBoard : 0x0202020202020202
FILE_C: BitBoard : 0x0404040404040404
FILE_D: BitBoard : 0x0808080808080808
FILE_E: BitBoard : 0x1010101010101010
FILE_F: BitBoard : 0x2020202020202020
FILE_G: BitBoard : 0x4040404040404040
FILE_H: BitBoard : 0x8080808080808080

EDGE: BitBoard : RANK_1 | RANK_8 | FILE_A | FILE_H

A1: BitBoard : 1 << 0
B1: BitBoard : 1 << 1
C1: BitBoard : 1 << 2
D1: BitBoard : 1 << 3
E1: BitBoard : 1 << 4
F1: BitBoard : 1 << 5
G1: BitBoard : 1 << 6
H1: BitBoard : 1 << 7
A2: BitBoard : 1 << 8
B2: BitBoard : 1 << 9
C2: BitBoard : 1 << 10
D2: BitBoard : 1 << 11
E2: BitBoard : 1 << 12
F2: BitBoard : 1 << 13
G2: BitBoard : 1 << 14
H2: BitBoard : 1 << 15
A3: BitBoard : 1 << 16
B3: BitBoard : 1 << 17
C3: BitBoard : 1 << 18
D3: BitBoard : 1 << 19
E3: BitBoard : 1 << 20
F3: BitBoard : 1 << 21
G3: BitBoard : 1 << 22
H3: BitBoard : 1 << 23
A4: BitBoard : 1 << 24
B4: BitBoard : 1 << 25
C4: BitBoard : 1 << 26
D4: BitBoard : 1 << 27
E4: BitBoard : 1 << 28
F4: BitBoard : 1 << 29
G4: BitBoard : 1 << 30
H4: BitBoard : 1 << 31
A5: BitBoard : 1 << 32
B5: BitBoard : 1 << 33
C5: BitBoard : 1 << 34
D5: BitBoard : 1 << 35
E5: BitBoard : 1 << 36
F5: BitBoard : 1 << 37
G5: BitBoard : 1 << 38
H5: BitBoard : 1 << 39
A6: BitBoard : 1 << 40
B6: BitBoard : 1 << 41
C6: BitBoard : 1 << 42
D6: BitBoard : 1 << 43
E6: BitBoard : 1 << 44
F6: BitBoard : 1 << 45
G6: BitBoard : 1 << 46
H6: BitBoard : 1 << 47
A7: BitBoard : 1 << 48
B7: BitBoard : 1 << 49
C7: BitBoard : 1 << 50
D7: BitBoard : 1 << 51
E7: BitBoard : 1 << 52
F7: BitBoard : 1 << 53
G7: BitBoard : 1 << 54
H7: BitBoard : 1 << 55
A8: BitBoard : 1 << 56
B8: BitBoard : 1 << 57
C8: BitBoard : 1 << 58
D8: BitBoard : 1 << 59
E8: BitBoard : 1 << 60
F8: BitBoard : 1 << 61
G8: BitBoard : 1 << 62
H8: BitBoard : 1 << 63

rank_file_to_bb :: proc(rank: int, file: int) -> BitBoard {
	sq: int = rank_file_to_sq(rank, file)
	return BitBoard(1) << uint(sq)
}

sq_to_bb :: #force_inline proc(sq: int) -> BitBoard {
	return BitBoard(1) << uint(sq)
}

display_bitboard :: proc(bitboard: BitBoard) {
	shift: uint
	mask: BitBoard

	for i in 0 ..< 8 {
		for j in 0 ..< 8 {
			shift = uint((7 - i) * 8 + j)
			mask = BitBoard(1) << shift
			if (bitboard & mask) > 0 {
				fmt.print("1")
			} else {
				fmt.print("0")
			}
		}
		fmt.print("\n")
	}
	fmt.print("\n")
}

count_ones_bb :: proc(b: BitBoard) -> int {
	/*
    r : int = 0
    bp : BitBoard = b
    for (bp != 0) {
        r += 1
        bp = bp & (bp-1)
    }
    return r
    */
	return int(bits.count_ones(u64(b)))
}

pop_first_bit :: #force_inline proc(bb: ^BitBoard) -> int {
	sq := int(intrinsics.count_trailing_zeros(bb^))
	bb^ &= bb^ - 1
	return sq
}

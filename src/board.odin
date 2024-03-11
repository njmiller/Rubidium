package main

import "core:fmt"
import "core:math/rand"

BitBoard :: distinct u64
//BitBoard :: distinct bit_set[0..<64]

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

idx_A1 :: 0
idx_B1 :: 1
idx_C1 :: 2
idx_D1 :: 3
idx_E1 :: 4
idx_F1 :: 5
idx_G1 :: 6
idx_H1 :: 7
idx_A2 :: 8
idx_B2 :: 9
idx_C2 :: 10
idx_D2 :: 11
idx_E2 :: 12
idx_F2 :: 13
idx_G2 :: 14
idx_H2 :: 15
idx_A3 :: 16
idx_B3 :: 17
idx_C3 :: 18
idx_D3 :: 19
idx_E3 :: 20
idx_F3 :: 21
idx_G3 :: 22
idx_H3 :: 23
idx_A4 :: 24
idx_B4 :: 25
idx_C4 :: 26
idx_D4 :: 27
idx_E4 :: 28
idx_F4 :: 29
idx_G4 :: 30
idx_H4 :: 31
idx_A5 :: 32
idx_B5 :: 33
idx_C5 :: 34
idx_D5 :: 35
idx_E5 :: 36
idx_F5 :: 37
idx_G5 :: 38
idx_H5 :: 39
idx_A6 :: 40
idx_B6 :: 41
idx_C6 :: 42
idx_D6 :: 43
idx_E6 :: 44
idx_F6 :: 45
idx_G6 :: 46
idx_H6 :: 47
idx_A7 :: 48
idx_B7 :: 49
idx_C7 :: 50
idx_D7 :: 51
idx_E7 :: 52
idx_F7 :: 53
idx_G7 :: 54
idx_H7 :: 55
idx_A8 :: 56
idx_B8 :: 57
idx_C8 :: 58
idx_D8 :: 59
idx_E8 :: 60
idx_F8 :: 61
idx_G8 :: 62
idx_H8 :: 63

//Maybe this would make the move generation code simpler
PositionOneColor :: struct {
	Pawns:     BitBoard,
	Rooks:     BitBoard,
	Bishops:   BitBoard,
	Knights:   BitBoard,
	Queens:    BitBoard,
	King:      BitBoard,
	AllPieces: BitBoard,
}

GamePosition :: struct {
	white:      PositionOneColor,
	black:      PositionOneColor,
	castling:   u8, // Says what castling is available
	en_passant: uint, // What square is available for en passant capture
	turn:       Color,
}

Color :: enum {
	White,
	Black,
}

PieceType :: enum {
	Pawn,
	Knight,
	Bishop,
	Rook,
	Queen,
	King,
	All,
}

Piece :: struct {
	piecetype: PieceType,
	color:     Color,
}

empty_position_onecolor :: proc() -> PositionOneColor {
	pos: PositionOneColor

	pos.King = 0
	pos.Queens = 0
	pos.Rooks = 0
	pos.Knights = 0
	pos.Bishops = 0
	pos.Pawns = 0
	pos.AllPieces = 0

	return pos
}

empty_position :: proc() -> GamePosition {
	pos: GamePosition

	pos.white = empty_position_onecolor()
	pos.black = empty_position_onecolor()

	pos.castling = 0
	pos.en_passant = 0

	return pos
}

//sq runs from 0 to 63 and rank, file go from 0 to 7
sq_to_rank_file :: proc(sq: int) -> (int, int) {
	//return (sq-1) / 8 + 1, (sq-1) % 8 + 1
	return (sq / 8), (sq % 8)
}

rank_file_to_bb :: proc(rank: int, file: int) -> BitBoard {
	sq: int = rank_file_to_sq(rank, file)
	return BitBoard(1) << uint(sq)
}

rank_file_to_sq :: proc(rank: int, file: int) -> int {
	//return (rank-1)*8 + file
	return 8 * rank + file
}

mirror_sq :: proc(sq: int) -> int {
	rank, file: int
	rank, file = sq_to_rank_file(sq)
	rank = 7 - rank
	return rank_file_to_sq(rank, file)
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

display_position :: proc(position: GamePosition) {
	shift: uint
	mask: BitBoard

	for i in 0 ..< 8 {
		for j in 0 ..< 8 {
			shift = uint((7 - i) * 8 + j)
			mask = BitBoard(1) << shift
			switch {
			case (mask & position.white.King) > 0:
				fmt.print('K')
			case (mask & position.white.Queens) > 0:
				fmt.print('Q')
			case (mask & position.white.Rooks) > 0:
				fmt.print('R')
			case (mask & position.white.Bishops) > 0:
				fmt.print('B')
			case (mask & position.white.Knights) > 0:
				fmt.print('N')
			case (mask & position.white.Pawns) > 0:
				fmt.print('P')
			case (mask & position.black.King) > 0:
				fmt.print('k')
			case (mask & position.black.Queens) > 0:
				fmt.print('q')
			case (mask & position.black.Rooks) > 0:
				fmt.print('r')
			case (mask & position.black.Bishops) > 0:
				fmt.print('b')
			case (mask & position.black.Knights) > 0:
				fmt.print('n')
			case (mask & position.black.Pawns) > 0:
				fmt.print('p')
			case:
				fmt.print('.')
			}
		}
		fmt.print("\n")
	}
}

get_bitboard :: proc(bitboards: GamePosition, piece: PieceType, color: Color) -> BitBoard {
	switch color {
	case .White:
		{
			switch piece {
			case .Pawn:
				return bitboards.white.Pawns
			case .Knight:
				return bitboards.white.Knights
			case .Bishop:
				return bitboards.white.Bishops
			case .Rook:
				return bitboards.white.Rooks
			case .Queen:
				return bitboards.white.Queens
			case .King:
				return bitboards.white.King
			case .All:
				return bitboards.white.AllPieces
			}
		}
	case .Black:
		{
			switch piece {
			case .Pawn:
				return bitboards.black.Pawns
			case .Knight:
				return bitboards.black.Knights
			case .Bishop:
				return bitboards.black.Bishops
			case .Rook:
				return bitboards.black.Rooks
			case .Queen:
				return bitboards.black.Queens
			case .King:
				return bitboards.black.King
			case .All:
				return bitboards.black.AllPieces
			}
		}
	}

	panic("Should never get past switch statement in get_bitboard.")

}


test :: proc() {
	x: i32 = 5
	fmt.println(x)

	/*
    a : rand.Rand = rand.create(1123)

    //fmt.println(rand.Rand())
    fmt.println(rand.uint64(&a))

    left_side : BitBoard = 1085102592571150095
    right_side : BitBoard = 17361641481138401520

    k := []u32{0, 1, 2, 3, 4, 5, 6, 7}
    j : u32
    off : u32

    for j2 in k {
        for j in k {
            off = 8*j2 + j
            fmt.print((left_side & (1 << off)) >> off, " ")
        }
        fmt.println("")
    }
    */

	bb: BitBoard = (1 << 5) | (1 << 3) | (1 << 7) | (1 << 23)
	fmt.println("num_ones:", count_ones_bb(bb))
}

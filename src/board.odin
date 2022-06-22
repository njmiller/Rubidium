package main

import "core:fmt"
import "core:math/rand"

BitBoard :: distinct u64
//BitBoard :: distinct bit_set[0..<64]

RANK_1 : BitBoard : 0x00000000000000FF
RANK_2 : BitBoard : 0x000000000000FF00
RANK_3 : BitBoard : 0x0000000000FF0000
RANK_4 : BitBoard : 0x00000000FF000000
RANK_5 : BitBoard : 0x000000FF00000000
RANK_6 : BitBoard : 0x0000FF0000000000
RANK_7 : BitBoard : 0x00FF000000000000
RANK_8 : BitBoard : 0xFF00000000000000

FILE_A : BitBoard : 0x0101010101010101
FILE_B : BitBoard : 0x0202020202020202
FILE_C : BitBoard : 0x0404040404040404
FILE_D : BitBoard : 0x0808080808080808
FILE_E : BitBoard : 0x1010101010101010
FILE_F : BitBoard : 0x2020202020202020
FILE_G : BitBoard : 0x4040404040404040
FILE_H : BitBoard : 0x8080808080808080

EDGE : BitBoard : RANK_1 | RANK_8 | FILE_A | FILE_H

GamePosition :: struct {
    WhitePawns : BitBoard,
    WhiteRooks : BitBoard,
    WhiteBishops : BitBoard,
    WhiteKnights : BitBoard,
    WhiteQueens : BitBoard,
    WhiteKing : BitBoard,
    WhiteAllPieces : BitBoard,

    BlackPawns : BitBoard,
    BlackRooks : BitBoard,
    BlackBishops : BitBoard,
    BlackKnights : BitBoard,
    BlackQueens : BitBoard,
    BlackKing : BitBoard,
    BlackAllPieces : BitBoard,
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
    piecetype : PieceType,
    color : Color,
}

empty_position :: proc() -> GamePosition {
    pos : GamePosition

    pos.WhiteKing = 0
    pos.WhiteQueens = 0
    pos.WhiteRooks = 0
    pos.WhiteBishops = 0
    pos.WhiteKnights = 0
    pos.WhitePawns = 0
    pos.WhiteAllPieces = 0

    pos.BlackKing = 0
    pos.BlackQueens = 0
    pos.BlackRooks = 0
    pos.BlackBishops = 0
    pos.BlackKnights = 0
    pos.BlackPawns = 0
    pos.BlackAllPieces = 0

    return pos
}

sq_to_rank_file :: proc(sq: int) -> (int, int) {
    return (sq-1) / 8 + 1, (sq-1) % 8 + 1
}

rank_file_to_bb :: proc(rank : int, file : int) -> BitBoard {
    sq : int = rank_file_to_sq(rank, file)
    return BitBoard(1) << uint(sq-1)
}

rank_file_to_sq :: proc(rank : int, file : int) -> int {
    return (rank-1)*8 + file
}

display_bitboard :: proc(bitboard : BitBoard) {
    shift : uint
    mask : BitBoard

    fmt.println("")
    for i in 0..<8 {
        for j in 0..<8 {
            shift = uint((7-i)*8 + j)
            mask = BitBoard(1) << shift
            if (bitboard & mask) > 0 {
                fmt.print("1")
            } else {
                fmt.print("0")
            }
        }
        fmt.print("\n")
    }
}

display_position :: proc(position : GamePosition) {
    shift : uint
    mask : BitBoard

    for i in 0..<8 {
        for j in 0..<8 {
            shift = uint((7-i)*8 + j)
            mask = BitBoard(1) << shift
            switch {
                case (mask & position.WhiteKing) > 0:
                    fmt.print('K')
                case (mask & position.WhiteQueens) > 0:
                    fmt.print('Q')
                case (mask & position.WhiteRooks) > 0:
                    fmt.print('R')
                case (mask & position.WhiteBishops) > 0:
                    fmt.print('B')
                case (mask & position.WhiteKnights) > 0:
                    fmt.print('N')
                case (mask & position.WhitePawns) > 0:
                    fmt.print('P')
                case (mask & position.BlackKing) > 0:
                    fmt.print('k')
                case (mask & position.BlackQueens) > 0:
                    fmt.print('q')
                case (mask & position.BlackRooks) > 0:
                    fmt.print('r')
                case (mask & position.BlackBishops) > 0:
                    fmt.print('b')
                case (mask & position.BlackKnights) > 0:
                    fmt.print('n')
                case (mask & position.BlackPawns) > 0:
                    fmt.print('p')
                case:
                    fmt.print('.')
            }
        }
        fmt.print("\n")
    }
}

get_bitboard :: proc(bitboards : GamePosition, piece: PieceType, color: Color) -> BitBoard {
    switch color {
        case .White: {
            switch piece {
                case .Pawn: return bitboards.WhitePawns
                case .Knight: return bitboards.WhiteKnights
                case .Bishop: return bitboards.WhiteBishops
                case .Rook: return bitboards.WhiteRooks
                case .Queen: return bitboards.WhiteQueens
                case .King: return bitboards.WhiteKing
                case .All: return bitboards.WhiteAllPieces
            }
        }
        case .Black: {
            switch piece {
                case .Pawn: return bitboards.BlackPawns
                case .Knight: return bitboards.BlackKnights
                case .Bishop: return bitboards.BlackBishops
                case .Rook: return bitboards.BlackRooks
                case .Queen: return bitboards.BlackQueens
                case .King: return bitboards.BlackKing
                case .All: return bitboards.BlackAllPieces
            }
        }
    }

    fmt.println("SHOULD NEVER GET HERE")
    return bitboards.BlackPawns
}


test :: proc () {
    x : i32 = 5
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

    bb : BitBoard = (1 << 5) | (1 << 3) | (1 << 7) | (1 << 23)
    fmt.println("num_ones:", count_ones(bb))
}
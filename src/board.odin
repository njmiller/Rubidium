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

/*
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

    Castling : u8,
    EnPassant : uint,
}
*/

//Maybe this would make the move generation code simpler
PositionOneColor :: struct {
    Pawns : BitBoard,
    Rooks : BitBoard,
    Bishops : BitBoard,
    Knights : BitBoard,
    Queens : BitBoard,
    King : BitBoard,
    AllPieces : BitBoard,
}

GamePosition :: struct {
    White : PositionOneColor,
    Black : PositionOneColor,

    Castling : u8,
    EnPassant : uint,
    turn : Color,
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

/*
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
*/

empty_position_onecolor :: proc() -> PositionOneColor {
    pos : PositionOneColor

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
    pos : GamePosition

    pos.White = empty_position_onecolor()
    pos.Black = empty_position_onecolor()

    pos.Castling = 0
    pos.EnPassant = 0

    return pos
}

//sq runs from 0 to 63 and rank, file go from 0 to 7
sq_to_rank_file :: proc(sq: int) -> (int, int) {
    //return (sq-1) / 8 + 1, (sq-1) % 8 + 1
    return (sq / 8), (sq % 8)
}

rank_file_to_bb :: proc(rank : int, file : int) -> BitBoard {
    sq : int = rank_file_to_sq(rank, file)
    return BitBoard(1) << uint(sq)
}

rank_file_to_sq :: proc(rank : int, file : int) -> int {
    //return (rank-1)*8 + file
    return 8*rank + file
}

display_bitboard :: proc(bitboard : BitBoard) {
    shift : uint
    mask : BitBoard

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
    fmt.print("\n")
}

display_position :: proc(position : GamePosition) {
    shift : uint
    mask : BitBoard

    for i in 0..<8 {
        for j in 0..<8 {
            shift = uint((7-i)*8 + j)
            mask = BitBoard(1) << shift
            switch {
                case (mask & position.White.King) > 0:
                    fmt.print('K')
                case (mask & position.White.Queens) > 0:
                    fmt.print('Q')
                case (mask & position.White.Rooks) > 0:
                    fmt.print('R')
                case (mask & position.White.Bishops) > 0:
                    fmt.print('B')
                case (mask & position.White.Knights) > 0:
                    fmt.print('N')
                case (mask & position.White.Pawns) > 0:
                    fmt.print('P')
                case (mask & position.Black.King) > 0:
                    fmt.print('k')
                case (mask & position.Black.Queens) > 0:
                    fmt.print('q')
                case (mask & position.Black.Rooks) > 0:
                    fmt.print('r')
                case (mask & position.Black.Bishops) > 0:
                    fmt.print('b')
                case (mask & position.Black.Knights) > 0:
                    fmt.print('n')
                case (mask & position.Black.Pawns) > 0:
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
                case .Pawn: return bitboards.White.Pawns
                case .Knight: return bitboards.White.Knights
                case .Bishop: return bitboards.White.Bishops
                case .Rook: return bitboards.White.Rooks
                case .Queen: return bitboards.White.Queens
                case .King: return bitboards.White.King
                case .All: return bitboards.White.AllPieces
            }
        }
        case .Black: {
            switch piece {
                case .Pawn: return bitboards.Black.Pawns
                case .Knight: return bitboards.Black.Knights
                case .Bishop: return bitboards.Black.Bishops
                case .Rook: return bitboards.Black.Rooks
                case .Queen: return bitboards.Black.Queens
                case .King: return bitboards.Black.King
                case .All: return bitboards.Black.AllPieces
            }
        }
    }

    fmt.println("SHOULD NEVER GET HERE")
    return BitBoard(0)
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
    fmt.println("num_ones:", count_ones_bb(bb))
}
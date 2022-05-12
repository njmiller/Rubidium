package main

import "core:fmt"
import "core:math/rand"

BitBoard :: distinct u64
//BitBoard :: distinct bit_set[0..<64]

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

    y : bit_set[0..<64] = {0, 1}
    z : bit_set[0..<64] = {2, 3, 4}

    fmt.println(y)
    fmt.println(size_of(y), size_of(u64))
    fmt.println(y | z)
    fmt.println(~y)

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
}
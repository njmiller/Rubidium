package main

import "core:fmt"
import "core:strconv"

process_fen :: proc(fen : string) -> GamePosition {
    pos_out : GamePosition
    bb_tmp : BitBoard
    shift : uint
    pos_out = empty_position()

    col, row, idx : uint

    idx = 0
    col = 1
    row = 8
    fmt.println("FEN:", fen)
    for {
        shift = 8*(row-1) + (col-1)
        bb_tmp = BitBoard(1) << shift
        fmt.println("TEST", idx, fen[idx], row, col)
        if fen[idx] == '/' {
            row = row - 1
            col = 1
        }

        fmt.println("TEST2:", fen[idx] == 'r')

        switch fen[idx] {
            case 'r' : 
                pos_out.BlackRooks = pos_out.BlackRooks | bb_tmp
                fmt.println("B:", pos_out.WhiteRooks, " ", bb_tmp)
            case 'p' : pos_out.BlackPawns = pos_out.BlackPawns | bb_tmp
            case 'n' : pos_out.BlackKnights = pos_out.BlackKnights | bb_tmp
            case 'b' : pos_out.BlackBishops = pos_out.BlackBishops | bb_tmp
            case 'q' : pos_out.BlackQueens = pos_out.BlackQueens | bb_tmp
            case 'k' : pos_out.BlackKing = pos_out.BlackKing | bb_tmp
            case 'R' : 
                pos_out.WhiteRooks = pos_out.WhiteRooks | bb_tmp
                fmt.println("W:", pos_out.WhiteRooks, " ", bb_tmp)
            case 'P' : pos_out.WhitePawns = pos_out.WhitePawns | bb_tmp
            case 'N' : pos_out.WhiteKnights = pos_out.WhiteKnights | bb_tmp
            case 'B' : pos_out.WhiteBishops = pos_out.WhiteBishops | bb_tmp
            case 'Q' : pos_out.WhiteQueens = pos_out.WhiteQueens | bb_tmp
            case 'K' : pos_out.WhiteKing = pos_out.WhiteKing | bb_tmp
            case '1'..'8' : col += uint(fen[idx] - 48)
            case '/' :
                row = row - 1
                col = 0
        }

        idx += 1
        col += 1

        if row == 0 && col > 8 do break
    }

    //NOTE: Still need to do processing of castling

    pos_out.BlackAllPieces = pos_out.BlackKing | pos_out.BlackQueens | pos_out.BlackRooks |
                             pos_out.BlackKnights | pos_out.BlackBishops | pos_out.BlackPawns
    pos_out.WhiteAllPieces = pos_out.WhiteKing | pos_out.WhiteQueens | pos_out.WhiteRooks |
                             pos_out.WhiteKnights | pos_out.WhiteBishops | pos_out.WhitePawns

    return pos_out
}

main :: proc() {
    pos : GamePosition
    fen : string
    test : int
    fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    pos = process_fen(fen)
    //generate_magics()
    //test = strconv.atoi("1")
    display_bitboard(pos.WhiteRooks)
}
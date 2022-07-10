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
    for {
        shift = 8*(row-1) + (col-1)
        bb_tmp = BitBoard(1) << shift

        switch fen[idx] {
            case 'r' : 
                pos_out.Black.Rooks = pos_out.Black.Rooks | bb_tmp
                //fmt.println("B:", pos_out.BlackRooks, " ", bb_tmp)
            case 'p' : pos_out.Black.Pawns = pos_out.Black.Pawns | bb_tmp
            case 'n' : pos_out.Black.Knights = pos_out.Black.Knights | bb_tmp
            case 'b' : pos_out.Black.Bishops = pos_out.Black.Bishops | bb_tmp
            case 'q' : pos_out.Black.Queens = pos_out.Black.Queens | bb_tmp
            case 'k' : pos_out.Black.King = pos_out.Black.King | bb_tmp
            case 'R' : 
                pos_out.White.Rooks = pos_out.White.Rooks | bb_tmp
                //fmt.println("W:", pos_out.WhiteRooks, " ", bb_tmp)
            case 'P' : pos_out.White.Pawns = pos_out.White.Pawns | bb_tmp
            case 'N' : pos_out.White.Knights = pos_out.White.Knights | bb_tmp
            case 'B' : pos_out.White.Bishops = pos_out.White.Bishops | bb_tmp
            case 'Q' : pos_out.White.Queens = pos_out.White.Queens | bb_tmp
            case 'K' : pos_out.White.King = pos_out.White.King | bb_tmp
            case '1'..='8' : col += uint(fen[idx] - 48) - 1
            case '/' :
                idx += 1
                continue
        }

        idx += 1
        col += 1

        if row == 1 && col > 8 do break

        if col == 9 {
            row = row - 1
            col = 1
        }

    }

    //NOTE: Still need to do processing of castling

    pos_out.Black.AllPieces = pos_out.Black.King | pos_out.Black.Queens | pos_out.Black.Rooks |
                             pos_out.Black.Knights | pos_out.Black.Bishops | pos_out.Black.Pawns
    pos_out.White.AllPieces = pos_out.White.King | pos_out.White.Queens | pos_out.White.Rooks |
                             pos_out.White.Knights | pos_out.White.Bishops | pos_out.White.Pawns

    return pos_out
}

main :: proc() {
    pos : GamePosition
    fen : string = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    bb_tmp : BitBoard
    bb_out, occ : BitBoard
    mask : BitBoard
    i : int
    //pos = process_fen(fen)
    //generate_magics()
    init_knight_moves()
    init_king_moves()
    init_magic_bitboards()

    /*
    occ = BitBoard(1) << 16
    occ |= BitBoard(1) << 17
    occ |= BitBoard(1) << 18
    occ |= BitBoard(1) << 10
    occ |= BitBoard(1) << 2

    occ |= BitBoard(1) << 0

    fmt.println("Occupancy")
    display_bitboard(occ)

    bb_tmp = get_rook_moves(0, occ)
    fmt.println("Rook")
    display_bitboard(bb_tmp)

    bb_tmp = get_bishop_moves(0, occ)
    fmt.println("Bishop")
    display_bitboard(bb_tmp)

    /*
    bb_out = init_slider_move(1, occ, false)
    display_bitboard(bb_out)
    fmt.println("")
    bb_out = init_slider_move(1, occ, true)
    display_bitboard(bb_out)
    */

    
    mask = rmask(0)
    display_bitboard(mask)
    mask = get_rook_mask(0)
    display_bitboard(mask)
    */
    sq : int = 0

    //mask = rmask(sq)
    //display_bitboard(mask)
    mask = get_rook_mask(sq)
    display_bitboard(mask)

    /*
    n : int = magic_rook_shifts[sq]
    bb_tmp = index_to_bb(sq, n, mask)
    //tmp = batt(27)
    /*
    for i in 0..<100 {
        bb_tmp = index_to_bb(i, 12, mask)
        fmt.println("I = ", i)
        display_bitboard(bb_tmp)
    }
    */
    */
    //generate_magics()

    /*
    bb_tmp = BitBoard(1) << 22 | BitBoard(1) << 10 | BitBoard(1) << 0
    fmt.println("AAA", bb_tmp)
    i = pop_first_bit(&bb_tmp)
    fmt.println("BBB", i, bb_tmp)
    i = pop_first_bit(&bb_tmp)
    fmt.println("BBB", i, bb_tmp)
    i = pop_first_bit(&bb_tmp)
    fmt.println("BBB", i, bb_tmp)
    */
}
package main

import "core:container/queue"
import "core:fmt"

Move :: struct {
    pos_init : u32,
    pos_final : u32,
    piece : Piece,
    //check : bool,
    //capture : bool,
    flags : bit_set[0..<4],
}

knight_moves : [64]BitBoard
king_moves : [64]BitBoard

init_knight_moves :: proc() {
    pi : BitBoard
    pos_moves : BitBoard

    //left_side : BitBoard = 1085102592571150095
    //right_side : BitBoard = 17361641481138401520
    //left_two : BitBoard = 217020518514230019
    //right_two : BitBoard = 13889313184910721216

    left_side : BitBoard : FILE_A | FILE_B | FILE_C | FILE_D 
    right_side : BitBoard : FILE_E | FILE_F | FILE_G | FILE_H
    left_two : BitBoard : FILE_A | FILE_B
    right_two : BitBoard : FILE_G | FILE_H
    
    for i in 0..<64 {
        pi = BitBoard(1) << uint(i)
        pos_moves = (pi << 6) | (pi << 10) | (pi << 15) | (pi << 17)
        pos_moves = pos_moves | (pi >> 6) | (pi >> 10) | (pi >> 15) | (pi >> 17)

        if (pi & left_two != 0) { pos_moves = pos_moves & left_side }
        if (pi & right_two != 0) { pos_moves = pos_moves & right_side }

        knight_moves[i] = pos_moves
    }
}

init_king_moves :: proc() {
    pi : BitBoard
    pos_moves : BitBoard
    
    //left_side : BitBoard = 1085102592571150095
    //right_side : BitBoard = 17361641481138401520
    //left_one : BitBoard = 72340172838076673
    //right_one : BitBoard = 9259542123273814144

    left_side : BitBoard : FILE_A | FILE_B | FILE_C | FILE_D 
    right_side : BitBoard : FILE_E | FILE_F | FILE_G | FILE_H

    for i in 0..<64 {
        pi = BitBoard(1) << uint(i)

        pos_moves = (pi << 1) | (pi << 7) | (pi << 8) | (pi << 9)
        pos_moves = pos_moves | (pi >> 1) | (pi >> 7) | (pi >> 8) | (pi >> 9)

        if (pi & FILE_A != 0) { pos_moves = pos_moves & left_side }
        if (pi & FILE_H != 0) { pos_moves = pos_moves & right_side }

        king_moves[i] = pos_moves
    }
}

//Use computation to determine slider moves
init_slider_move :: proc(sq : int, occupied : BitBoard, is_rook : bool) -> BitBoard {
    rank, file, rank_i, file_i : int
    i : int
    output : BitBoard = 0
    bb_tmp : BitBoard

    rf_max :: 7
    rf_min :: 0

    delta_rook := matrix[2,2]int{
        0, 1,
        1, 0,
    }
    delta_bishop := matrix[2,2]int{
        1, 1,
        1, -1,
    }

    delta : matrix[2,2]int
    if is_rook {
        delta = delta_rook
    } else {
        delta = delta_bishop
    }

    rank_i, file_i = sq_to_rank_file(sq)

    //Maybe a second loop to get rid of copied code
    for i in 0..=1 {
        rank = rank_i
        file = file_i
        for {
            rank += delta[i, 0]
            file += delta[i, 1]
            if (rank > rf_max) || (rank < rf_min) || (file > rf_max) || (file < rf_min) do break
            bb_tmp = rank_file_to_bb(rank, file)
            output |= bb_tmp
            if (bb_tmp & occupied) != 0 do break
        }
    
        rank = rank_i
        file = file_i
        for {
            rank -= delta[i, 0]
            file -= delta[i, 1]
            if (rank > rf_max) || (rank < rf_min) || (file > rf_max) || (file < rf_min) do break
            bb_tmp = rank_file_to_bb(rank, file)
            output |= bb_tmp
            if (bb_tmp & occupied) != 0 do break
        }
    }
    
    return output
}

//Magic table stuff is initialized in magics.odin
get_bishop_moves :: proc(sq : int, occupancy : BitBoard) -> BitBoard {
    hash : u64
    hash = u64(occupancy & magic_bishop_table[sq].mask)
    hash *= magic_bishop_table[sq].magic
    hash >>= uint(64 - magic_bishop_table[sq].shift)
    return magic_bishop_table[sq].attacks[hash]
}

get_rook_moves :: proc(sq : int, occupancy : BitBoard) -> BitBoard {
    hash : u64
    hash = u64(occupancy & magic_rook_table[sq].mask)
    hash *= magic_rook_table[sq].magic
    hash >>= uint(64 - magic_rook_table[sq].shift)
    return magic_rook_table[sq].attacks[hash]
}

get_queen_moves :: proc(sq : int, occupancy : BitBoard) -> BitBoard {
    return get_bishop_moves(sq, occupancy) | get_rook_moves(sq, occupancy)
}

gen_moves :: proc(position : GamePosition, color : Color) {
    //This is better than the separate procedures because we only have to loop over a single bitboard
    i : int
    moves : queue.Queue(Move)

    /*
    if color == .White {
        my_bb = position.WhiteAllPieces
        opp_bb = position.BlackAllPieces
    } else if color == .Black {
        my_bb = position.BlackAllPieces
        opp_bb = position.WhiteAllPieces
    }

    for i in 0..<64 {
        pos_bb = BitBoard(1) << uint(i)
        switch {
            case (pos_bb & WhitePawns) && color == .White:
                fmt.println("TEST")
        }
    }
    */


    //TODO: Is there a better way to do this???
    /*
    if color == Color.White {
        /all_pieces = position.WhiteAllPieces
        pawns = position.WhitePawns
        knights = position.WhiteKnights
        bishops = position.WhiteBishops
        rooks = position.WhiteRooks
        queens = position.WhiteQueens
        king = position.WhiteKing
        opp_pieces = position.BlackAllPieces
    } else if color == Color.Black {
        all_pieces = position.BlackAllPieces
        pawns = position.BlackPawns
        knights = position.BkackKnights
        bishops = position.BlackBishops
        rooks = position.BlackRooks
        queens = position.BlackQueens
        king = position.BlackKing
        opp_pieces = position.WhiteAllPieces
    }

    for i in 0..<64 {
        pos_shift = 1 << u64(i)
        //if (pos_shift &)

        if (pos_shift & pawns) {
            println("DO STUFF HERE")
        }

        if (pos_shift & knights > 0) {
            pos_final = knight_patterns[i] &~ friendly_pieces
            captures = knight_patterns[i] & opp_pieces
        }

    }
    */
}

bitboard_to_move :: proc(pos_init: u32, pos_final: BitBoard, piece: Piece, moves: queue.Queue) {

    move : Move

    pos_shift : BitBoard = pos_final
    for i in 0..<64 {
        pos_shift = pos_shift >> 1
        if (pos_shift & 0x01) == 1 {
            move = Move{pos_init, i, piece, bit_set[0..<4]}
            //moves.push_back(move)
        }
    }

}
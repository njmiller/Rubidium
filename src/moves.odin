package main

import "core:container/queue"
import "core:fmt"

Move :: struct {
    pos_init : int,
    pos_final : int,
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
    moves : queue.Queue(Move)
    my_pos, opp_pos : PositionOneColor
    pos_bb, moves_bb, captures_bb : BitBoard
    piece : Piece

    /*
    if color == .White {
        my_pos = position.White
        opp_pos = position.Black
    } else if color == .Black {
        my_pos = position.Black
        opp_pos = position.White
    }
    */

    switch color {
        case .White:
            my_pos = position.White
            opp_pos = position.Black
        case .Black:
            my_pos = position.Black
            opp_pos = position.White
    }

    //TODO: Maybe do pop_first_bit for quicker move generation. Would need to time it
    //to see if it is faster
    for sq in 0..<64 {
        pos_bb = BitBoard(1) << uint(sq)
        switch {
            case (pos_bb & position.White.Pawns) != 0 && (color == .White):
                fmt.println("TEST")
                piece = Piece{PieceType.Pawn, color}
            case (pos_bb & my_pos.Knights) != 0 :
                piece = Piece{PieceType.Knight, color}
                moves_bb = knight_moves[sq] & ~my_pos.AllPieces
                captures_bb = knight_moves[sq] & opp_pos.AllPieces
            case (pos_bb & my_pos.Rooks) != 0 :
                piece = Piece{PieceType.Rook, color}
                moves_bb = get_rook_moves(sq, my_pos.AllPieces | opp_pos.AllPieces)
                captures_bb = moves_bb & opp_pos.AllPieces
                moves_bb = moves_bb & ~captures_bb
            case (pos_bb & my_pos.Bishops) != 0 :
                piece = Piece{PieceType.Bishop, color}
                moves_bb = get_bishop_moves(sq, my_pos.AllPieces | opp_pos.AllPieces)
                captures_bb = moves_bb & opp_pos.AllPieces
                moves_bb = moves_bb & ~captures_bb
            case (pos_bb & my_pos.Queens) != 0 :
                piece = Piece{PieceType.Queen, color}
                moves_bb = get_queen_moves(sq, my_pos.AllPieces | opp_pos.AllPieces)
                captures_bb = moves_bb & opp_pos.AllPieces
                moves_bb = moves_bb & ~captures_bb
            case (pos_bb & my_pos.King) != 0 :
                piece = Piece{PieceType.King, color}
                moves_bb = king_moves[sq] & ~my_pos.AllPieces
                captures_bb = king_moves[sq] & opp_pos.AllPieces
        }
        bb_to_moves(&moves, sq, piece, moves_bb, captures_bb)
    }

    check_castle: bool = true
    if check_castle do gen_castle_move(&moves, color, my_pos, opp_pos)

}

gen_castle_move :: proc(moves : ^queue.Queue(Move), color : Color, my_pos : PositionOneColor, opp_pos : PositionOneColor) {
    
    //O-O

    //O-O-O
}

bb_to_moves :: proc(moves : ^queue.Queue(Move), sq: int, piece : Piece, moves_bb : BitBoard, captures_bb : BitBoard) {

    //TODO: Check to see if I need separate bitboard inputs for standard moves and captures

    bb_tmp : BitBoard
    sq_fin : int
    move : Move
    flags : bit_set[0..<4] = {}

    bb_tmp = moves_bb
    for bb_tmp != 0 {
        sq_fin = pop_first_bit(&bb_tmp) + 1
        move = Move{sq, sq_fin, piece, flags}
        queue.push_back(moves, move)
    }

    bb_tmp = captures_bb
    for bb_tmp != 0 {
        sq_fin = pop_first_bit(&bb_tmp) + 1
        move = Move{sq, sq_fin, piece, flags}
        queue.push_front(moves, move)
    }

}

apply_move :: proc(move : Move, position_in : GamePosition) -> GamePosition {

    position_out : GamePosition
    my_pos, opp_pos : ^PositionOneColor
    sq_bb : BitBoard = BitBoard(1) << uint(move.pos_init - 1)

    position_out = position_in

    switch move.piece.color {
        case .White:
            my_pos = &position_out.White
            opp_pos = &position_out.Black
        case .Black:
            my_pos = &position_out.Black
            opp_pos = &position_out.White
    }

    /*
    switch move.piece.piecetype {
        case .Pawn:
            my_pos.Pawns = 1
    }
    */

    return position_out
}
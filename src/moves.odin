package main

import "core:container/queue"

Move :: struct {
    pos_init : u32,
    pos_final : u32,
    piece : Piece,
    //check : bool,
    //capture : bool,
    flags : bit_set[0..<4],
}

knight_patterns : [64]BitBoard

gen_moves :: proc(position: GamePosition, color: Color) -> queue.Queue {
    moves : queue.Queue

    return moves
}

gen_pawn_moves :: proc(pawns : BitBoard, friendly : BitBoard, enemies: BitBoard,
                       color: Color, moves: queue.Queue) {
    pi : u64
    pm : i64
    flags : bit_set[0..<4]

    if color == Color.White { pm=1 } else {pm=-1}
    for i in 0..<64 {
        if (1 << i) & pawns { 
            //4 possible moves
            pi = (1 << (i+pm*8))
            if (pi & friendly == 0) & (pi & enemies == 0) {
                move = Move{i, i+pm*8, piece.Pawn, flags}
                moves.push_back(move)
            }
            pi = (1 << (i+pm*7))
            if (pi & enemies > 0) {
                flags = {1}
                move = Move{i, i+pm*8, piece.Pawn, flags}
                moves.push_back(move)
            }
        }
    }
    return moves
}

init_knight_patterns :: proc() {
    pi : BitBoard
    pos_moves : BitBoard

    left_side : BitBoard = 1085102592571150095
    right_side : BitBoard = 17361641481138401520
    left_two : BitBoard = 1
    right_two : BitBoard = 1

    for i in 0..<64 {
        pi = 1 << u64(i)
        pos_moves = (pi << 6) | (pi << 10) | (pi << 15) | (pi << 17)
        pos_moves = pos_moves | (pi >> 6) | (pi >> 10) | (pi >> 15) | (pi >> 17)

        if (pi & left_two != 0) { pos_moves = pos_moves & left_side }
        if (pi & right_two != 0) { pos_moves = pos_moves & right_side }

        knight_patterns[i] = pos_moves
    }
}

gen_rook_moves :: proc(rooks : BitBoard, friendly : BitBoard, enemies : BitBoard, moves: queue.Queue) {
    move: Move
    occupancy : BitBoard = friendly & enemies
}

gen_bishop_moves :: proc(bishops : BitBoard, friendly : BitBoard, enemies : BitBoard, moves: queue.Queue) {

}

gen_queen_moves :: proc(queens : BitBoard, friendly, BitBoard, enemies : BitBoard, moves: queue.Queue) {
    gen_rook_moves(queens, friendly, enemies, moves)
    gen_bishop_moves(queens, friendly, enemies, moves)
}

gen_all_moves :: proc(position : GamePosition, color : Color) {
    //This is better than the separate procedures because we only have to loop over a single bitboard
    pos_shift : BitBoard

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
            moves.push_back(move)
        }
    }

}
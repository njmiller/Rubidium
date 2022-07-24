package main

import "core:math/bits"

KING_CP :: 100000
QUEEN_CP ::  900
ROOK_CP :: 500
BISHOP_CP :: 330
KNIGHT_CP :: 320
PAWN_CP :: 100

pawn_square_table := [64]int{
    0,  0,  0,  0,  0,  0,  0,  0,
    5, 10, 10,-20,-20, 10, 10,  5,
    5, -5,-10,  0,  0,-10, -5,  5,
    0,  0,  0, 20, 20,  0,  0,  0,
    5,  5, 10, 25, 25, 10,  5,  5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
    0,  0,  0,  0,  0,  0,  0,  0
}

knight_square_table := [64]int{
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50
}

bishop_square_table := [64]int{
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10,-10,-10,-10,-10,-20
}

rook_square_table := [64]int{
    0,  0,  0,  5,  5,  0,  0,  0,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    5, 10, 10, 10, 10, 10, 10,  5,
    0,  0,  0,  0,  0,  0,  0,  0
}

queen_square_table := [64]int{
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -10,  5,  5,  5,  5,  5,  0,-10,
    0,  0,  5,  5,  5,  5,  0, -5,
    -5,  0,  5,  5,  5,  5,  0, -5,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20
}

king_square_mid := [64]int{
    20, 30, 10,  0,  0, 10, 30, 20,
    20, 20,  0,  0,  0,  0, 20, 20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30
}

king_square_end := [64]int{
    -50,-30,-30,-30,-30,-30,-30,-50,
    -30,-30,  0,  0,  0,  0,-30,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-20,-10,  0,  0,-10,-20,-30,
    -50,-40,-30,-20,-20,-30,-40,-50
}

num_pieces :: proc(bb : BitBoard) -> int {
    return count_ones_bb(bb)
}

eval_position :: proc(pos : ^GamePosition) -> int {
    score : int
    bb_tmp : BitBoard
    n_wqueen, n_bqueen : int
    n_wpieces, n_bpieces : int
    sq, sq2 : int
    king_square_table : [64]int

    //Queen
    n_wqueen = 0
    bb_tmp = pos.White.Queens
    for (bb_tmp != 0) {
        n_wqueen += 1
        sq = pop_first_bit(&bb_tmp)
        score += QUEEN_CP
        score += queen_square_table[sq]
    }

    n_bqueen = 0
    bb_tmp = pos.Black.Queens
    for (bb_tmp != 0) {
        n_bqueen += 1
        sq = pop_first_bit(&bb_tmp)
        sq2 = mirror_sq(sq)
        score -= QUEEN_CP
        score -= queen_square_table[sq2]
    }

    n_wpieces = 0
    n_bpieces = 0
    //Rook
    bb_tmp = pos.White.Rooks
    for (bb_tmp != 0) {
        n_wpieces += 1
        sq = pop_first_bit(&bb_tmp)
        score += ROOK_CP
        score += rook_square_table[sq]
    }

    bb_tmp = pos.Black.Rooks
    for (bb_tmp != 0) {
        n_bpieces = 0
        sq = pop_first_bit(&bb_tmp)
        sq2 = mirror_sq(sq)
        score -= ROOK_CP
        score -= rook_square_table[sq2]
    }

    //Knight
    bb_tmp = pos.White.Knights
    for (bb_tmp != 0) {
        n_wpieces += 1
        sq = pop_first_bit(&bb_tmp)
        score += KNIGHT_CP
        score += knight_square_table[sq]
    }

    bb_tmp = pos.Black.Knights
    for (bb_tmp != 0) {
        n_bpieces = 0
        sq = pop_first_bit(&bb_tmp)
        sq2 = mirror_sq(sq)
        score -= KNIGHT_CP
        score -= knight_square_table[sq2]
    }

    //Bishop
    bb_tmp = pos.White.Bishops
    for (bb_tmp != 0) {
        n_wpieces += 1
        sq = pop_first_bit(&bb_tmp)
        score += BISHOP_CP
        score += bishop_square_table[sq]
    }

    bb_tmp = pos.Black.Bishops
    for (bb_tmp != 0) {
        n_bpieces = 0
        sq = pop_first_bit(&bb_tmp)
        sq2 = mirror_sq(sq)
        score -= BISHOP_CP
        score -= bishop_square_table[sq2]
    }

    //Pawn
    bb_tmp = pos.White.Pawns
    for (bb_tmp != 0) {
        sq = pop_first_bit(&bb_tmp)
        score += PAWN_CP
        score += pawn_square_table[sq]
    }

    bb_tmp = pos.Black.Queens
    for (bb_tmp != 0) {
        sq = pop_first_bit(&bb_tmp)
        sq2 = mirror_sq(sq)
        score -= PAWN_CP
        score -= pawn_square_table[sq2]
    }
    
    //King

    //determine which of the king square tables to use
    //TODO: See if this copies the whole arrays. We want just a reference to the original end and mid arrays
    if (pos.White.Queens == 0 ) && (pos.Black.Queens == 0) {
        king_square_table = king_square_end
    } else {
        king_square_table = king_square_mid
    }

    bb_tmp = pos.White.King
    sq = pop_first_bit(&bb_tmp)
    score += king_square_table[sq]
    bb_tmp = pos.Black.King
    sq = pop_first_bit(&bb_tmp)
    sq2 = mirror_sq(sq)
    score -= king_square_table[sq]
    
    return score
}
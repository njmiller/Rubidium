package main

import "core:math/bits"

KING_CP :: 100000
QUEEN_CP :: 900
ROOK_CP :: 500
BISHOP_CP :: 330
KNIGHT_CP :: 320
PAWN_CP :: 100

MAX_PHASE :: 24

PHASE_WEIGHT := [PieceType]int {
	.Pawn = 0,
	.Knight = 1,
	.Bishop = 1,
	.Rook = 2,
	.Queen = 4,
	.King = 0,
	.All = 0,
}

PIECE_VALUE := [PieceType]int {
	.Pawn = 100,
	.Knight = 320,
	.Bishop = 330,
	.Rook = 500,
	.Queen = 900,
	.King = 0, // never used but meeded for the arrau
	.All = 0, // same as previous
}

DIST_BONUS : [64][64]int

//odinfmt: disable
pawn_square_table := [64]int{
    0,  0,  0,  0,  0,  0,  0,  0,
    5, 10, 10,-20,-20, 10, 10,  5,
    5, -5,-10,  0,  0,-10, -5,  5,
    0,  0,  0, 20, 20,  0,  0,  0,
    5,  5, 10, 25, 25, 10,  5,  5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
    0,  0,  0,  0,  0,  0,  0,  0,
}

knight_square_table := [64]int{
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
}

bishop_square_table := [64]int{
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
}

rook_square_table := [64]int{
    0,  0,  0,  5,  5,  0,  0,  0,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    5, 10, 10, 10, 10, 10, 10,  5,
    0,  0,  0,  0,  0,  0,  0,  0,
}

queen_square_table := [64]int{
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -10,  5,  5,  5,  5,  5,  0,-10,
    0,  0,  5,  5,  5,  5,  0, -5,
    -5,  0,  5,  5,  5,  5,  0, -5,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20,
}

king_square_mid := [64]int{
    20, 30, 10,  0,  0, 10, 30, 20,
    20, 20,  0,  0,  0,  0, 20, 20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
}

king_square_end := [64]int{
    -50,-30,-30,-30,-30,-30,-30,-50,
    -30,-30,  0,  0,  0,  0,-30,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-20,-10,  0,  0,-10,-20,-30,
    -50,-40,-30,-20,-20,-30,-40,-50,
}
//odinfmt: enable

PIECE_SQ_TABLE_MID := [PieceType][64]int {
	.Pawn = pawn_square_table,
	.Knight = knight_square_table,
	.Bishop = bishop_square_table,
	.Rook = rook_square_table,
	.Queen = queen_square_table,
	.King = king_square_mid,
	.All = {}, // unused
}

PIECE_SQ_TABLE_END := [PieceType][64]int {
	.Pawn = pawn_square_table,
	.Knight = knight_square_table,
	.Bishop = bishop_square_table,
	.Rook = rook_square_table,
	.Queen = queen_square_table,
	.King = king_square_end,
	.All = {}, // unused
}

num_pieces :: proc(bb: BitBoard) -> int {
	return count_ones_bb(bb)
}

set_dist :: proc() {
	for i in 0..<64 {
		for j in 0..<64 {
			rank_i, file_i := sq_to_rank_file(i)
			rank_j, file_j := sq_to_rank_file(j)
			DIST_BONUS[i][j] = 14 - ( abs(file_i - file_j) + abs(rank_i - rank_j) )
		}
	}
}

/*
score_update :: #force_inline proc(
	bb: BitBoard,
	score_piece: int,
	score_square: [64]int,
	mirror: bool,
) -> (
	int,
	int,
) {
	score := 0
	n_piece := 0
	bb_tmp := bb
	for (bb_tmp != 0) {
		n_piece += 1
		sq := pop_first_bit(&bb_tmp)
		if mirror do sq = mirror_sq(sq)
		score += score_piece
		score += score_square[sq]
	}

	return score, n_piece
}

eval_position :: proc(pos: ^GamePosition) -> int {
	bb_tmp: BitBoard
	sq2: int

	score := 0
	score_tmp: int

	// who2move val
	who2move := 1 if pos.turn == .White else -1

	//Queen
	n_wqueen := 0
	bb_tmp = pos.white.Queens
	for (bb_tmp != 0) {
		n_wqueen += 1
		sq := pop_first_bit(&bb_tmp)
		score += QUEEN_CP
		score += queen_square_table[sq]
	}

	// score_wqueen, n_wqueen2 := score_update(pos.White.Queens, QUEEN_CP, queen_square_table, false)


	n_bqueen := 0
	bb_tmp = pos.black.Queens
	for (bb_tmp != 0) {
		n_bqueen += 1
		sq := pop_first_bit(&bb_tmp)
		sq = mirror_sq(sq)
		score -= QUEEN_CP
		score -= queen_square_table[sq]
	}

	n_wpieces := 0
	n_bpieces := 0
	//Rook
	bb_tmp = pos.white.Rooks
	for (bb_tmp != 0) {
		n_wpieces += 1
		sq := pop_first_bit(&bb_tmp)
		score += ROOK_CP
		score += rook_square_table[sq]
	}

	bb_tmp = pos.black.Rooks
	for (bb_tmp != 0) {
		n_bpieces += 1
		sq := pop_first_bit(&bb_tmp)
		sq = mirror_sq(sq)
		score -= ROOK_CP
		score -= rook_square_table[sq]
	}

	//Knight
	bb_tmp = pos.white.Knights
	for (bb_tmp != 0) {
		n_wpieces += 1
		sq := pop_first_bit(&bb_tmp)
		score += KNIGHT_CP
		score += knight_square_table[sq]
	}

	bb_tmp = pos.black.Knights
	for (bb_tmp != 0) {
		n_bpieces = 0
		sq := pop_first_bit(&bb_tmp)
		sq = mirror_sq(sq)
		score -= KNIGHT_CP
		score -= knight_square_table[sq]
	}

	//Bishop
	bb_tmp = pos.white.Bishops
	for (bb_tmp != 0) {
		n_wpieces += 1
		sq := pop_first_bit(&bb_tmp)
		score += BISHOP_CP
		score += bishop_square_table[sq]
	}

	bb_tmp = pos.black.Bishops
	for (bb_tmp != 0) {
		n_bpieces = 0
		sq := pop_first_bit(&bb_tmp)
		sq = mirror_sq(sq)
		score -= BISHOP_CP
		score -= bishop_square_table[sq]
	}

	//Pawn
	bb_tmp = pos.white.Pawns
	for (bb_tmp != 0) {
		sq := pop_first_bit(&bb_tmp)
		score += PAWN_CP
		score += pawn_square_table[sq]
	}

	bb_tmp = pos.black.Pawns
	for (bb_tmp != 0) {
		sq := pop_first_bit(&bb_tmp)
		sq = mirror_sq(sq)
		score -= PAWN_CP
		score -= pawn_square_table[sq]
	}

	//King

	//determine which of the king square tables to use
	//TODO: See if this copies the whole arrays. We want just a reference to the original end and mid arrays
	king_square_table: [64]int
	if (pos.white.Queens == 0) && (pos.black.Queens == 0) {
		king_square_table = king_square_end
	} else {
		king_square_table = king_square_mid
	}

	bb_tmp = pos.white.King
	sq := pop_first_bit(&bb_tmp)
	score += king_square_table[sq]
	bb_tmp = pos.black.King
	sq = pop_first_bit(&bb_tmp)
	sq2 = mirror_sq(sq)
	score -= king_square_table[sq]

	return who2move*score
}
*/

eval_position :: proc(pos: ^GamePosition) -> int {
	mid_score := (pos.material[.White] + pos.psqt_mid[.White]) - (pos.material[.Black] + pos.psqt_mid[.Black])
	end_score := (pos.material[.White] + pos.psqt_end[.White]) - (pos.material[.Black] + pos.psqt_end[.Black])

	phase := clamp(pos.phase, 0, MAX_PHASE)

	// weighted average with full mid weight at MAX_PHASE and full end weight at phase=0
	score := (mid_score * phase + end_score * (MAX_PHASE - phase)) / MAX_PHASE

	// score = score if pos.turn == .White else -score
	// return score
	return pos.turn == .White ? score : -score
}

psqt_square :: #force_inline proc(square: int, color: Color) -> int {
	return color == .White ? square : square ~ 56 // flip rank, keep file
}

psqt_value_mid :: #force_inline proc(piece: Piece, square: int) -> int {
	return PIECE_SQ_TABLE_MID[piece.piecetype][psqt_square(square, piece.color)]
}

psqt_value_end :: #force_inline proc(piece: Piece, square: int) -> int {
	return PIECE_SQ_TABLE_END[piece.piecetype][psqt_square(square, piece.color)]
}
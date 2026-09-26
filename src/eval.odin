package main

import "core:math/bits"

KING_CP :: 100000
QUEEN_CP :: 900
ROOK_CP :: 500
BISHOP_CP :: 330
KNIGHT_CP :: 320
PAWN_CP :: 100

MAX_PHASE :: 24

TEMPO_BONUS :: 10

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

eval_position :: proc(pos: ^GamePosition) -> int {
	mid_score := (pos.material[.White] + pos.psqt_mid[.White]) - (pos.material[.Black] + pos.psqt_mid[.Black])
	end_score := (pos.material[.White] + pos.psqt_end[.White]) - (pos.material[.Black] + pos.psqt_end[.Black])

	phase := clamp(pos.phase, 0, MAX_PHASE)

	// weighted average with full mid weight at MAX_PHASE and full end weight at phase=0
	score := (mid_score * phase + end_score * (MAX_PHASE - phase)) / MAX_PHASE

	// Should be a positive score if the side moving is ahead
	return (pos.turn == .White ? score : -score) + TEMPO_BONUS
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
package main

import "core:testing"

@(test)
test_knight_moves :: proc(_: ^testing.T) {

	// Initialize knight moves array
	init_knight_moves()

	// Check several parts of the array
	kA1 := C2 | B3
	kD3 := E5 | E1 | F2 | F4 | C5 | C1 | B2 | B4
	kF5 := G7 | G3 | H6 | H4 | E7 | E3 | D6 | D4
	kC7 := E8 | E6 | D5 | B5 | A6 | A8

	assert(knight_moves[idx_A1] == kA1)
	assert(knight_moves[idx_D3] == kD3)
	assert(knight_moves[idx_F5] == kF5)
	assert(knight_moves[idx_C7] == kC7)
}

@(test)
test_bishop_moves :: proc(_: ^testing.T) {
	init_magic_bitboards()

	// Define an occupancy that will be used for testing
	// bishop moves
	occupancy := G5 | G3 | D5 | C6

	moves_B1 := get_bishop_moves(idx_B1, occupancy)
	moves_F3 := get_bishop_moves(idx_F3, occupancy)

	bB1 := A2 | C2 | D3 | E4 | F5 | G6 | H7
	bF3 := E4 | D5 | G2 | H1 | G4 | H5 | E2 | D1

	assert(moves_B1 == bB1)
	assert(moves_F3 == bF3)

}

@(test)
test_rook_moves :: proc(_: ^testing.T) {
	init_magic_bitboards()

	occupancy := G5 | G3 | D2 | F4

	moves_G2 := get_rook_moves(idx_G2, occupancy)
	moves_F5 := get_rook_moves(idx_F5, occupancy)

	bG2 := G3 | G1 | F2 | E2 | D2 | H2
	bF5 := F4 | F6 | F7 | F8 | G5 | E5 | D5 | C5 | B5 | A5

	assert(moves_G2 == bG2)
	assert(moves_F5 == bF5)
}

@(test)
test_apply_move :: proc(_: ^testing.T) {
	assert(1 == 1)
}

@(test)
test_process_fen :: proc(_: ^testing.T) {
	fen := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	pos := process_fen(fen)

	white_pawns := A2 | B2 | C2 | D2 | E2 | F2 | G2 | H2
	black_pawns := A7 | B7 | C7 | D7 | E7 | F7 | G7 | H7

	assert(pos.white.Pawns == white_pawns)
	assert(pos.black.Pawns == black_pawns)
}

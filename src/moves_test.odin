package main

import "core:fmt"
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
test_magic_moves :: proc(t: ^testing.T) {
	init_magic_bitboards()
	defer free_magic_bitboards()

	test_bishop_moves(t)
	test_rook_moves(t)

}

// @(test)
test_bishop_moves :: proc(_: ^testing.T) {
	// init_magic_bitboards()
	// defer free_magic_bitboards()

	// Define an occupancy that will be used for testing
	// bishop moves
	occupancy := G5 | G3 | D5 | C6

	moves_B1 := get_bishop_moves(idx_B1, occupancy)
	moves_F3 := get_bishop_moves(idx_F3, occupancy)

	bB1 := A2 | C2 | D3 | E4 | F5 | G6 | H7
	bF3 := E4 | D5 | G2 | H1 | G4 | H5 | E2 | D1

	assert(moves_B1 == bB1)
	assert(moves_F3 == bF3)

	// Additional test cases with different occupancy patterns

	// Test bishop on central square with scattered occupancy
	occupancy2 := B2 | F2 | B6 | F6
	moves_D4 := get_bishop_moves(idx_D4, occupancy2)
	bD4 := C3 | B2 | E5 | F6 | C5 | B6 | E3 | F2
	assert(moves_D4 == bD4)

	// Test bishop in corner with minimal blocking
	occupancy3 := B7 | G2
	moves_A8 := get_bishop_moves(idx_A8, occupancy3)
	moves_H1 := get_bishop_moves(idx_H1, occupancy3)
	bA8 := B7
	bH1 := G2
	assert(moves_A8 == bA8)
	assert(moves_H1 == bH1)

	// Test bishop with heavy occupancy blocking multiple directions
	occupancy4 := C3 | C5 | E3 | E5
	moves_D4_blocked := get_bishop_moves(idx_D4, occupancy4)
	bD4_blocked := C3 | C5 | E3 | E5

	assert(moves_D4_blocked == bD4_blocked)

	// Test bishop on edge with partial blocking
	occupancy5 := D6 | F4
	moves_C7 := get_bishop_moves(idx_C7, occupancy5)
	bC7 := B8 | D8 | B6 | A5 | D6

	assert(moves_C7 == bC7)
}


// @(test)
test_rook_moves :: proc(_: ^testing.T) {
	// init_magic_bitboards()
	// defer free_magic_bitboards()

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
	fen := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	pos := process_fen(fen)

	piece := Piece{.Pawn, .White}
	move := Move{idx_E2, idx_E4, piece, false}

	pos_init := pos

	info := apply_move_inplace(move, &pos)

	assert(pos.turn == .Black)
	assert(pos.en_passant == idx_E3)

	undo_move_inplace(move, info, &pos)

	assert(pos.turn == .White)

	assert(pos == pos_init)
}

@(test)
test_process_fen :: proc(_: ^testing.T) {
	fen := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	pos := process_fen(fen)

	white_pawns := A2 | B2 | C2 | D2 | E2 | F2 | G2 | H2
	black_pawns := A7 | B7 | C7 | D7 | E7 | F7 | G7 | H7

	assert(pos.white.Pawns == white_pawns)
	assert(pos.black.Pawns == black_pawns)

	assert(pos.castling == {.WHITEKINGSIDE, .WHITEQUEENSIDE, .BLACKKINGSIDE, .BLACKQUEENSIDE})
	assert(pos.en_passant == -1)
	assert(pos.turn == .White)

	fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b Kk e3 7 10"
	pos = process_fen(fen)

	assert(pos.en_passant == idx_E3)
	assert(pos.castling == {.WHITEKINGSIDE, .BLACKKINGSIDE})
	assert(pos.halfmove == 7)
	assert(pos.turn == .Black)
	assert(pos.movenum == 10)


}

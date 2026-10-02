package main

import "core:testing"

@(test)
test_knight_moves :: proc(_: ^testing.T) {

	// Initialize knight moves array
	// init_knight_moves()

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

// @(test)
// test_magic_moves :: proc(t: ^testing.T) {
	// test_bishop_moves(t)
	// test_rook_moves(t)
// }

@(test)
test_bishop_moves :: proc(_: ^testing.T) {
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


@(test)
test_rook_moves :: proc(_: ^testing.T) {
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
	move := Move{idx_E2, idx_E4, piece, false, .Pawn}

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

	assert(pos.bb[.White][.Pawn] == white_pawns)
	assert(pos.bb[.Black][.Pawn] == black_pawns)

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

@(test)
test_en_passant :: proc(_: ^testing.T) {
	// Black pawn on d4 can capture en passant on e3
	fen := "rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
	pos := process_fen(fen)
	pos_init := pos

	move := Move{idx_D4, idx_E3, Piece{.Pawn, .Black}, true, .Pawn}
	info := apply_move_inplace(move, &pos)

	assert((pos.bb[.Black][.Pawn] & E3) != 0)
	assert((pos.bb[.White][.Pawn] & E4) == 0)
	assert((pos.occupied[.White] & E4) == 0)

	undo_move_inplace(move, info, &pos)

	assert(pos == pos_init)
}

@(test)
test_promotion :: proc(_: ^testing.T) {
	// White pawn on a7 promotes to a queen by pushing to a8
	fen := "8/P7/8/8/8/8/7k/K7 w - - 0 1"
	pos := process_fen(fen)

	move := Move{idx_A7, idx_A8, Piece{.Pawn, .White}, false, .Queen}
	info := apply_move_inplace(move, &pos)

	assert((pos.bb[.White][.Queen] & A8) != 0)
	assert((pos.bb[.White][.Pawn] & A8) == 0)
	assert((pos.bb[.White][.Pawn] & A7) == 0)

	undo_move_inplace(move, info, &pos)

	assert((pos.bb[.White][.Pawn] & A7) != 0)
	assert(pos.bb[.White][.Queen] == 0)
}

@(test)
test_castle_gen :: proc(_: ^testing.T) {
	fen := "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
	pos := process_fen(fen)

	move_list := gen_moves(&pos)

	found_kingside, found_queenside := false, false
	for i in 0..<move_list.n {
		move := move_list.moves[i]
		if move.piece.piecetype == .King {
			if move.pos_final == idx_G1 do found_kingside = true
			if move.pos_final == idx_C1 do found_queenside = true
		}
	}

	assert(found_kingside)
	assert(found_queenside)
}

expect_perft :: proc(t: ^testing.T, pos: ^GamePosition, depth: int, expected: u64, captures: int, promotions: int, castles: int, checks: int, ep: int) {
	stats: PerftStats
	perft(depth, pos, &stats)
	testing.expectf(t, stats.nodes == expected,
		"perft(%d) = %d, expected %d", depth, stats.nodes, expected)
	if captures >= 0 {
		testing.expectf(t, stats.captures == auto_cast captures,
		"perft captures(%d) = %d, expected %d", depth, stats.captures, captures)
	}
	if promotions >= 0 {
		testing.expectf(t, stats.promotions == auto_cast promotions,
		"perft promotions(%d) = %d, expected %d", depth, stats.promotions, promotions)
	}
	if castles >= 0 {
		testing.expectf(t, stats.castles == auto_cast castles,
		"perft castles(%d) = %d, expected %d", depth, stats.castles, castles)
	}
	if checks >= 0 {
		testing.expectf(t, stats.checks == auto_cast checks,
		"perft checks(%d) = %d, expected %d", depth, stats.checks, checks)
	}
	if ep >= 0 {
		testing.expectf(t, stats.en_passant == auto_cast ep,
		"perft en_passant(%d) = %d, expected %d", depth, stats.en_passant, ep)
	}
}

@(test)
test_perft_startpos :: proc(t: ^testing.T) {
	pos := gen_newgame()

	expect_perft(t, &pos, 1, 20, 0, 0, 0, 0, 0)
	expect_perft(t, &pos, 2, 400, 0, 0, 0, 0, 0)
	expect_perft(t, &pos, 3, 8902, 34, 0, 0, 12, 0)
	expect_perft(t, &pos, 4, 197281, 1576, 0, 0, 469, 0)
	expect_perft(t, &pos, 5, 4865609, 82719, 0, 0, 27351, 258)
}

@(test)
test_perft_kiwipete :: proc(t: ^testing.T) {
	pos := process_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

	expect_perft(t, &pos, 1, 48, 8, 0, 2, 0, 0)
	expect_perft(t, &pos, 2, 2039, 351, 0, 91, 3, 1)
	expect_perft(t, &pos, 3, 97862, 17102, 0, 3162, 993, 45)
	expect_perft(t, &pos, 4, 4085603, 757163, 15172, 128013, 25523, 1929)
}

@(test)
test_perft_cpw_pos3 :: proc(t: ^testing.T) {
	pos := process_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1 ")

	expect_perft(t, &pos, 1, 14, 1, 0, 0, 2, 0)
	expect_perft(t, &pos, 2, 191, 14, 0, 0, 10, 0)
	expect_perft(t, &pos, 3, 2812, 209, 0, 0, 267, 2)
}

@(test)
test_perft_cpw_pos4 :: proc(t: ^testing.T) {
	pos := process_fen("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1")

	expect_perft(t, &pos, 1, 6, 0, 0, 0, 0, 0)
	expect_perft(t, &pos, 2, 264, 87, 48, 6, 10, 0)
	expect_perft(t, &pos, 3, 9467, 1021, 120, 0, 38, 4)
}

@(test)
test_perft_cpw_pos5 :: proc(t: ^testing.T) {
	pos := process_fen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8")

	expect_perft(t, &pos, 1, 44, -1, -1, -1, -1, -1)
	expect_perft(t, &pos, 2, 1486, -1, -1, -1, -1, -1)
	expect_perft(t, &pos, 3, 62379, -1, -1, -1, -1, -1)
}

@(test)
test_perft_cpw_pos6 :: proc(t: ^testing.T) {
	pos := process_fen("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10 ")

	expect_perft(t, &pos, 1, 46, -1, -1, -1, -1, -1)
	expect_perft(t, &pos, 2, 2079, -1, -1, -1, -1, -1)
	expect_perft(t, &pos, 3, 89890, -1, -1, -1, -1, -1)
}

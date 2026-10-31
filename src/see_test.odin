package main

import "core:testing"

// Checks that the exchange value of move is exactly value: see_ge passes at
// value and fails one centipawn above it
expect_see :: proc(t: ^testing.T, fen: string, move: Move, value: int, label: string) {
	pos := process_fen(fen)
	testing.expectf(t, see_ge(&pos, move, value), "%s: see_ge(%d) should be true", label, value)
	testing.expectf(t, !see_ge(&pos, move, value + 1), "%s: see_ge(%d) should be false", label, value + 1)
}

@(test)
test_see_hanging_piece :: proc(t: ^testing.T) {
	// Rxd5 wins an undefended knight
	expect_see(t, "4k3/8/8/3n4/8/8/8/3RK3 w - - 0 1",
		Move{idx_D1, idx_D5, Piece{.Rook, .White}, true, .Pawn}, KNIGHT_CP, "hanging knight")
}

@(test)
test_see_defended_pawn :: proc(t: ^testing.T) {
	// Qxd5 cxd5 loses the queen for a pawn
	expect_see(t, "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1",
		Move{idx_D1, idx_D5, Piece{.Queen, .White}, true, .Pawn}, PAWN_CP - QUEEN_CP, "queen takes defended pawn")

	// exd5 cxd5 is an even trade
	expect_see(t, "4k3/8/2p5/3p4/4P3/8/8/4K3 w - - 0 1",
		Move{idx_E4, idx_D5, Piece{.Pawn, .White}, true, .Pawn}, 0, "pawn trade")
}

@(test)
test_see_xray :: proc(t: ^testing.T) {
	// Nxd5 Rxd5 Bxd5 Qxd5. Qd8 only joins once Rd7 has captured. Without
	// x-rays black would run out of attackers and Nxd5 would win the pawn
	expect_see(t, "3qk3/3r4/8/3p4/8/2N2B2/8/4K3 w - - 0 1",
		Move{idx_C3, idx_D5, Piece{.Knight, .White}, true, .Pawn},
		PAWN_CP - KNIGHT_CP + ROOK_CP - BISHOP_CP, "queen behind rook")
}

@(test)
test_see_king_recapture :: proc(t: ^testing.T) {
	// Kxd5 is illegal because Bf3 covers d5, so Rxd5 wins the pawn
	expect_see(t, "8/8/4k3/3p4/8/5B2/8/3RK3 w - - 0 1",
		Move{idx_D1, idx_D5, Piece{.Rook, .White}, true, .Pawn}, PAWN_CP, "king can't recapture")

	// Without the bishop, Kxd5 wins the rook
	expect_see(t, "8/8/4k3/3p4/8/8/8/3RK3 w - - 0 1",
		Move{idx_D1, idx_D5, Piece{.Rook, .White}, true, .Pawn}, PAWN_CP - ROOK_CP, "king recaptures")
}

@(test)
test_see_quiet :: proc(t: ^testing.T) {
	// Qd4 puts the queen where exd4 takes it
	expect_see(t, "4k3/8/8/4p3/8/8/8/3QK3 w - - 0 1",
		Move{idx_D1, idx_D4, Piece{.Queen, .White}, false, .Pawn}, -QUEEN_CP, "queen to attacked square")

	// Qd3 is safe
	expect_see(t, "4k3/8/8/4p3/8/8/8/3QK3 w - - 0 1",
		Move{idx_D1, idx_D3, Piece{.Queen, .White}, false, .Pawn}, 0, "safe quiet move")
}

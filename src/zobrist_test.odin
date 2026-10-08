package main

import "core:testing"

// Plays a sequence of UCI moves (e.g. "g1f3") on the position. Each move is
// looked up in the generated move list so castling, en passant and promotion
// flags are set exactly as the engine would set them. Fails the test if a
// move is not found.
play_uci_moves :: proc(t: ^testing.T, pos: ^GamePosition, moves: []string) -> bool {
	for move_str in moves {
		move_list := gen_moves(pos)
		found := false

		for i in 0 ..< move_list.n {
			buf: [5]u8
			if move_to_uci(move_list.moves[i], &buf) == move_str {
				apply_move_inplace(move_list.moves[i], pos)
				found = true
				break
			}
		}

		if !testing.expectf(t, found, "move %s not found in generated moves", move_str) {
			return false
		}

		testing.expectf(t, pos.hash == compute_hash(pos),
			"after %s: incremental hash %d != recomputed hash %d", move_str, pos.hash, compute_hash(pos))
	}

	return true
}

// Plays both move sequences from the same starting FEN and asserts that the
// resulting hashes are equal (same_position = true) or different (false).
expect_transposition :: proc(t: ^testing.T, fen: string, a: []string, b: []string, same_position: bool, label: string) {
	pos_a := process_fen(fen)
	pos_b := process_fen(fen)

	if !play_uci_moves(t, &pos_a, a) do return
	if !play_uci_moves(t, &pos_b, b) do return

	if same_position {
		testing.expectf(t, pos_a.hash == pos_b.hash,
			"%s: transposed positions have different hashes %d != %d", label, pos_a.hash, pos_b.hash)
	} else {
		testing.expectf(t, pos_a.hash != pos_b.hash,
			"%s: different positions share hash %d", label, pos_a.hash)
	}
}

STARTPOS_FEN :: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

@(test)
test_zobrist_transpositions :: proc(t: ^testing.T) {
	// Knight development in a different order
	expect_transposition(t, STARTPOS_FEN,
		{"g1f3", "g8f6", "b1c3"},
		{"b1c3", "g8f6", "g1f3"},
		true, "knights")

	// Both sides swap move order
	expect_transposition(t, STARTPOS_FEN,
		{"g1f3", "g8f6", "b1c3", "b8c6"},
		{"b1c3", "b8c6", "g1f3", "g8f6"},
		true, "both sides knights")

	// Pawn moves mixed with piece moves. The last move is not a double push so
	// no en passant square is left behind in either line
	expect_transposition(t, STARTPOS_FEN,
		{"e2e4", "e7e5", "g1f3", "b8c6", "f1c4"},
		{"g1f3", "b8c6", "e2e4", "e7e5", "f1c4"},
		true, "italian")

	// Castling in a different order relative to the other side's moves
	expect_transposition(t, STARTPOS_FEN,
		{"e2e4", "e7e5", "g1f3", "g8f6", "f1c4", "f8c5", "e1g1", "e8g8"},
		{"g1f3", "g8f6", "e2e4", "e7e5", "f1c4", "f8c5", "e1g1", "e8g8"},
		true, "castled")

	// Knight tour back to the start: same pieces, same side to move, same rights
	expect_transposition(t, STARTPOS_FEN,
		{"g1f3", "g8f6", "f3g1", "f6g8"},
		{},
		true, "knight round trip")
}

@(test)
test_zobrist_non_transpositions :: proc(t: ^testing.T) {
	// Same piece placement, different side to move. The rook loses a tempo
	// with a1a3 a3a2 a2a1 (knights can't do this)
	ROOK_FEN :: "4k3/8/8/8/8/8/4P3/R3K3 w - - 0 1"
	expect_transposition(t, ROOK_FEN,
		{"a1a3", "e8d8", "a3a2", "d8e8", "a2a1"},
		{},
		false, "side to move")

	// Same piece placement, but white lost kingside castling rights by
	// moving the rook out and back
	expect_transposition(t, STARTPOS_FEN,
		{"g1f3", "g8f6", "h1g1", "f6g8", "g1h1", "g8f6"},
		{"g1f3", "g8f6", "b1c3", "f6g8", "c3b1", "g8f6"},
		false, "castling rights")

	// Same piece placement, but one line leaves an en passant square
	// (black to move in both, rook triangle used to fix the move parity)
	expect_transposition(t, ROOK_FEN,
		{"e2e4"},
		{"e2e3", "e8d8", "a1a3", "d8e8", "a3a2", "e8d8", "a2a1", "d8e8", "e3e4"},
		false, "en passant square")
}

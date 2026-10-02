package main

import "core:fmt"
import "core:testing"

// Recompute the incremental eval bookkeeping fields (material, psqt_mid,
// psqt_end, phase) from scratch by walking the piece bitboards. Used by the
// eval tests to verify that the incrementally updated fields in
// apply/undo_move_inplace never drift.
recompute_eval_fields :: proc(pos: ^GamePosition) -> (material: [Color]int, psqt_mid: [Color]int, psqt_end: [Color]int, phase: int) {
	for color in Color {
		for pt in PieceType {
			bb := pos.bb[color][pt]
			for bb != 0 {
				sq := pop_first_bit(&bb)
				p := Piece{pt, color}
				material[color] += PIECE_VALUE[pt]
				psqt_mid[color] += psqt_value_mid(p, sq)
				psqt_end[color] += psqt_value_end(p, sq)
				phase += PHASE_WEIGHT[pt]
			}
		}
	}

	return
}

// Asserts that the mailbox and occupancy bitboards agree with the per-piece
// bitboards
assert_board_consistent :: proc(t: ^testing.T, pos: ^GamePosition, label: string) {
	for color in Color {
		union_bb: BitBoard
		for pt in PieceType do union_bb |= pos.bb[color][pt]
		testing.expectf(t, pos.occupied[color] == union_bb,
			"%s: occupied[%v] does not match piece bitboards", label, color)
	}

	for sq in 0 ..< 64 {
		sq_bb := sq_to_bb(sq)
		p, ok := piece_at(pos, sq)
		if ok {
			testing.expectf(t, pos.bb[p.color][p.piecetype] & sq_bb != 0,
				"%s: mailbox has %v on %d but its bitboard does not", label, p, sq)
		} else {
			testing.expectf(t, all_occupied(pos) & sq_bb == 0,
				"%s: mailbox empty on %d but square is occupied", label, sq)
		}
	}
}

// xorshift64 for deterministic pseudo-random move selection in tests. State is
// kept local to each test so concurrent test threads never share it.
next_random :: proc(state: ^u64) -> u64 {
	s := state^
	s ~= s << 13
	s ~= s >> 7
	s ~= s << 17
	state^ = s
	return s
}

// Picks a pseudo-random legal move and LEAVES IT APPLIED on the position.
// Returns the move and its MoveInfo so the caller can undo it later. If no
// legal move exists, ok is false and the position is unchanged.
pick_random_legal :: proc(pos: ^GamePosition, state: ^u64) -> (move: Move, info: MoveInfo, ok: bool) {
	move_list := gen_moves(pos)
	if move_list.n == 0 do return

	start := int(next_random(state) % u64(move_list.n))

	for i in 0 ..< move_list.n {
		idx := (start + i) % move_list.n
		candidate := move_list.moves[idx]
		info_c := apply_move_inplace(candidate, pos)

		if !is_in_check(candidate.piece.color, pos) {
			return candidate, info_c, true
		}

		undo_move_inplace(candidate, info_c, pos)
	}

	return
}

// Asserts that the incrementally maintained eval fields match a from-scratch
// recompute, and that eval_position equals the tapered blend computed from the
// recomputed values (catches blend/sign/tempo formula bugs too).
assert_eval_consistent :: proc(t: ^testing.T, pos: ^GamePosition, label: string) {
	assert_board_consistent(t, pos, label)

	material, psqt_mid, psqt_end, phase := recompute_eval_fields(pos)

	testing.expectf(
		t,
		pos.material == material && pos.psqt_mid == psqt_mid && pos.psqt_end == psqt_end && pos.phase == phase,
		"%s: incremental eval fields drift\n  material  %v vs %v\n  psqt_mid  %v vs %v\n  psqt_end  %v vs %v\n  phase     %d vs %d",
		label,
		pos.material, material,
		pos.psqt_mid, psqt_mid,
		pos.psqt_end, psqt_end,
		pos.phase, phase,
	)

	mid := (material[.White] + psqt_mid[.White]) - (material[.Black] + psqt_mid[.Black])
	end := (material[.White] + psqt_end[.White]) - (material[.Black] + psqt_end[.Black])
	ph := clamp(phase, 0, MAX_PHASE)

	expected := (mid * ph + end * (MAX_PHASE - ph)) / MAX_PHASE
	if pos.turn != .White do expected = -expected
	expected += TEMPO_BONUS

	testing.expectf(t, eval_position(pos) == expected,
		"%s: eval %d != %d from recomputed fields", label, eval_position(pos), expected)
}

@(test)
test_eval_startpos :: proc(t: ^testing.T) {
	pos := gen_newgame()

	assert_eval_consistent(t, &pos, "startpos")

	testing.expectf(t, pos.phase == MAX_PHASE,
		"startpos phase %d != MAX_PHASE %d", pos.phase, MAX_PHASE)

	// Fully symmetric position: only the tempo bonus shows up
	testing.expectf(t, eval_position(&pos) == TEMPO_BONUS,
		"startpos eval %d != TEMPO_BONUS %d", eval_position(&pos), TEMPO_BONUS)
}

@(test)
test_eval_black_to_move :: proc(t: ^testing.T) {
	// Same startpos layout, black to move: STM-relative score is still tempo
	pos := process_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")

	assert_eval_consistent(t, &pos, "startpos black to move")

	testing.expectf(t, eval_position(&pos) == TEMPO_BONUS,
		"black-to-move eval %d != TEMPO_BONUS %d", eval_position(&pos), TEMPO_BONUS)
}

@(test)
test_eval_mirror_symmetry :: proc(t: ^testing.T) {
	// Mirrored startpos with black to move must score identically to the
	// normal startpos with white to move. Catches PSQT mirror (psqt_square)
	// orientation bugs.
	pos := process_fen("RNBQKBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbqkbnr b KQkq - 0 1")

	assert_eval_consistent(t, &pos, "mirrored startpos")

	testing.expectf(t, eval_position(&pos) == TEMPO_BONUS,
		"mirrored startpos eval %d != TEMPO_BONUS %d", eval_position(&pos), TEMPO_BONUS)
}

@(test)
test_eval_taper_endpoints :: proc(t: ^testing.T) {
	// Bare kings: phase 0 -> eval must be the pure endgame score + tempo
	pos := process_fen("7k/8/8/8/8/8/8/K7 w - - 0 1")

	assert_eval_consistent(t, &pos, "bare kings")

	testing.expectf(t, pos.phase == 0,
		"bare kings phase %d != 0", pos.phase)

	end_score := (pos.material[.White] + pos.psqt_end[.White]) - (pos.material[.Black] + pos.psqt_end[.Black])
	testing.expectf(t, eval_position(&pos) == end_score + TEMPO_BONUS,
		"bare kings eval %d != end score %d + tempo", eval_position(&pos), end_score)

	// Full material: phase MAX_PHASE -> eval must be the pure midgame score + tempo
	pos = gen_newgame()
	mid_score := (pos.material[.White] + pos.psqt_mid[.White]) - (pos.material[.Black] + pos.psqt_mid[.Black])
	testing.expectf(t, eval_position(&pos) == mid_score + TEMPO_BONUS,
		"startpos eval %d != mid score %d + tempo", eval_position(&pos), mid_score)
}

@(test)
test_eval_phase_accounting :: proc(t: ^testing.T) {
	// Startpos has every non-pawn piece: phase must be exactly MAX_PHASE
	pos := gen_newgame()
	testing.expectf(t, pos.phase == MAX_PHASE,
		"startpos phase %d != %d", pos.phase, MAX_PHASE)

	// Queen capture: phase 4 -> 0
	pos = process_fen("4k3/8/8/3q4/2P5/8/8/4K3 w - - 0 1")
	testing.expectf(t, pos.phase == PHASE_WEIGHT[.Queen],
		"queen-only position phase %d != %d", pos.phase, PHASE_WEIGHT[.Queen])
	b_mat := pos.material[.Black]

	move := Move{idx_C4, idx_D5, Piece{.Pawn, .White}, true, .Pawn}
	info := apply_move_inplace(move, &pos)

	assert_eval_consistent(t, &pos, "queen capture")
	testing.expectf(t, pos.phase == 0, "queen capture phase %d != 0", pos.phase)
	testing.expectf(t, pos.material[.Black] == b_mat - PIECE_VALUE[.Queen],
		"queen capture material %d != %d", pos.material[.Black], b_mat - PIECE_VALUE[.Queen])

	undo_move_inplace(move, info, &pos)
	assert_eval_consistent(t, &pos, "queen capture undo")
	testing.expectf(t, pos.phase == PHASE_WEIGHT[.Queen],
		"queen capture undo phase %d != %d", pos.phase, PHASE_WEIGHT[.Queen])

	// Knight capture: phase 1 -> 0
	pos = process_fen("4k3/8/8/3n4/2P5/8/8/4K3 w - - 0 1")
	testing.expectf(t, pos.phase == PHASE_WEIGHT[.Knight],
		"knight-only position phase %d != %d", pos.phase, PHASE_WEIGHT[.Knight])

	move = Move{idx_C4, idx_D5, Piece{.Pawn, .White}, true, .Pawn}
	info = apply_move_inplace(move, &pos)

	assert_eval_consistent(t, &pos, "knight capture")
	testing.expectf(t, pos.phase == 0, "knight capture phase %d != 0", pos.phase)

	undo_move_inplace(move, info, &pos)
	assert_eval_consistent(t, &pos, "knight capture undo")

	// Quiet pawn push: phase must not change
	pos = process_fen("4k3/8/8/3q4/2P5/8/8/4K3 w - - 0 1")
	phase_before := pos.phase

	move = Move{idx_C4, idx_C5, Piece{.Pawn, .White}, false, .Pawn}
	info = apply_move_inplace(move, &pos)

	assert_eval_consistent(t, &pos, "pawn push")
	testing.expectf(t, pos.phase == phase_before,
		"pawn push changed phase %d -> %d", phase_before, pos.phase)

	undo_move_inplace(move, info, &pos)
	assert_eval_consistent(t, &pos, "pawn push undo")
}

@(test)
test_eval_promotion_delta :: proc(t: ^testing.T) {
	pos := process_fen("7k/P7/8/8/8/8/8/K7 w - - 0 1")

	assert_eval_consistent(t, &pos, "promotion before")

	mat_before := pos.material[.White]
	phase_before := pos.phase

	move := Move{idx_A7, idx_A8, Piece{.Pawn, .White}, false, .Queen}
	info := apply_move_inplace(move, &pos)

	assert_eval_consistent(t, &pos, "promotion after")
	testing.expectf(t, pos.material[.White] == mat_before + PIECE_VALUE[.Queen] - PIECE_VALUE[.Pawn],
		"promotion material %d != %d", pos.material[.White], mat_before + PIECE_VALUE[.Queen] - PIECE_VALUE[.Pawn])
	testing.expectf(t, pos.phase == phase_before + PHASE_WEIGHT[.Queen],
		"promotion phase %d != %d", pos.phase, phase_before + PHASE_WEIGHT[.Queen])

	undo_move_inplace(move, info, &pos)

	assert_eval_consistent(t, &pos, "promotion undo")
	testing.expectf(t, pos.material[.White] == mat_before,
		"promotion undo material %d != %d", pos.material[.White], mat_before)
	testing.expectf(t, pos.phase == phase_before,
		"promotion undo phase %d != %d", pos.phase, phase_before)
}

@(test)
test_eval_en_passant_delta :: proc(t: ^testing.T) {
	// Black pawn on d4 captures en passant on e3; the white pawn is removed
	// from e4, not e3
	pos := process_fen("rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

	assert_eval_consistent(t, &pos, "en passant before")

	mat_w := pos.material[.White]

	move := Move{idx_D4, idx_E3, Piece{.Pawn, .Black}, true, .Pawn}
	info := apply_move_inplace(move, &pos)

	assert_eval_consistent(t, &pos, "en passant after")
	testing.expectf(t, pos.material[.White] == mat_w - PIECE_VALUE[.Pawn],
		"en passant white material %d != %d", pos.material[.White], mat_w - PIECE_VALUE[.Pawn])

	undo_move_inplace(move, info, &pos)

	assert_eval_consistent(t, &pos, "en passant undo")
}

@(test)
test_eval_known_game_roundtrip :: proc(t: ^testing.T) {
	pos := gen_newgame()
	initial := pos

	game := [5]Move{
		{idx_E2, idx_E4, Piece{.Pawn, .White}, false, .Pawn},
		{idx_E7, idx_E5, Piece{.Pawn, .Black}, false, .Pawn},
		{idx_G1, idx_F3, Piece{.Knight, .White}, false, .Pawn},
		{idx_B8, idx_C6, Piece{.Knight, .Black}, false, .Pawn},
		{idx_F1, idx_C4, Piece{.Bishop, .White}, false, .Pawn},
	}

	infos: [5]MoveInfo
	for m, i in game {
		infos[i] = apply_move_inplace(m, &pos)
		assert_eval_consistent(t, &pos, fmt.tprintf("known game ply %d", i))
	}

	for i := len(game) - 1; i >= 0; i -= 1 {
		undo_move_inplace(game[i], infos[i], &pos)
	}

	testing.expect(t, pos == initial, "known game undo-all did not restore initial position")
	assert_eval_consistent(t, &pos, "known game after undo")
}

@(test)
test_eval_random_walk_consistency :: proc(t: ^testing.T) {
	fens := [6]string{
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
		"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
		"8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
		"r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
		"rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
		"r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
	}

	max_plies := 120

	for fen, fen_idx in fens {
		pos := process_fen(fen)
		initial := pos

		// Deterministic per-position seed; local state so concurrent tests
		// never share it
		state: u64 = 0x2545F4914F6CDD1D + u64(fen_idx) * 0x9E3779B97F4A7C15

		moves_stack := make([dynamic]Move)
		infos_stack := make([dynamic]MoveInfo)
		defer delete(moves_stack)
		defer delete(infos_stack)

		for ply := 0; ply < max_plies; ply += 1 {
			move, info, ok := pick_random_legal(&pos, &state)
			if !ok do break

			append(&moves_stack, move)
			append(&infos_stack, info)

			assert_eval_consistent(t, &pos, fmt.tprintf("walk fen %d ply %d", fen_idx, ply))
		}

		// Undo the whole walk; every field must return exactly to the start
		for i := len(moves_stack) - 1; i >= 0; i -= 1 {
			undo_move_inplace(moves_stack[i], infos_stack[i], &pos)
		}

		testing.expectf(t, pos == initial,
			"walk fen %d: undo-all did not restore initial position", fen_idx)
	}
}
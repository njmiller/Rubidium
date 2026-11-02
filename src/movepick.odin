package main

CAPTURE_BASE :: 1_000_000
BAD_CAPTURE :: -2 * CAPTURE_BASE

KILLER_1 :: 900_000
KILLER_2 :: 800_000
HISTORY_MAX :: 16384

is_quiet :: #force_inline proc(m: Move) -> bool {
	return !m.is_capture && m.promotion == .Pawn
}

// Captures and queen promotions must score at least CAPTURE_BASE in this
// function or quiesce and the killer detection in LMR will break.
// Other moves score 0.
mvv_lva_score :: #force_inline proc(move: Move, pos: ^GamePosition) -> int {
	score := 0

	if move.is_capture {
		victim := PieceType.Pawn // used if pos_final is empty for ep
		if p, ok := pos.board[move.pos_final].?; ok do victim = p.piecetype

		score = CAPTURE_BASE + 10 * int(victim) + int(PieceType.King) - int(move.piece.piecetype)
	}

	if move.promotion == .Queen {
		// Treat like winning a queen's worth of material
		score = max(score, CAPTURE_BASE) + 10 * int(PieceType.Queen)
	}

	return score
}

mvv_lva :: proc(ml: ^MoveList, pos: ^GamePosition) {
	for i in 0..<ml.n do ml.scores[i] = mvv_lva_score(ml.moves[i], pos)
}

// Order: TT move, captures (MVV-LVA), killers, other quiets by history
score_moves :: proc(s: ^SearchState, ml: ^MoveList, pos: ^GamePosition, ply: int, tt_move: u16) {
	for i in 0..<ml.n {
		m := ml.moves[i]
		switch {
		case pack_move(m) == tt_move:            ml.scores[i] = max(int)
		case !is_quiet(m):
			ml.scores[i] = mvv_lva_score(m, pos)
			if !see_ge(pos, m, 0) do ml.scores[i] += BAD_CAPTURE
		case move_equal(m, killers[ply][0]):     ml.scores[i] = KILLER_1
		case move_equal(m, killers[ply][1]):     ml.scores[i] = KILLER_2
		case:
			c1 := ply >= 1 ? s.cont_stack[ply - 1] : &cont_sentinel
			c2 := ply >= 2 ? s.cont_stack[ply - 2] : &cont_sentinel
			pi := piece_index(m.piece)                                    
			ml.scores[i] = quiet_history[m.piece.color][m.pos_init][m.pos_final] +
				int(c1[pi][m.pos_final]) + int(c2[pi][m.pos_final])
		}
	}
}

// Iterates over move list from start to end and finds one with highest
// score. Swaps it with move in start position so next time we can start at
// start+1
pick_next_move :: proc(ml: ^MoveList, start: int) -> Move {
	best := start
	for i in start+1..<ml.n {
		if ml.scores[i] > ml.scores[best] do best = i
	}
	ml.moves[start], ml.moves[best] = ml.moves[best], ml.moves[start]
	ml.scores[start], ml.scores[best] = ml.scores[best], ml.scores[start]

	return ml.moves[start]
}

store_killer :: proc(ply: int, move: Move) {
	if move_equal(killers[ply][0], move) do return
	killers[ply][1] = killers[ply][0]
	killers[ply][0] = move
}

update_history :: proc(move: Move, bonus: int) {
	h := &quiet_history[move.piece.color][move.pos_init][move.pos_final]
	h^ += bonus - h^ * abs(bonus) / HISTORY_MAX
}

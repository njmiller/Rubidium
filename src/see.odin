package main

// Static exchange evaluation: the material result of the capture sequence on
// one square, with each side recapturing with its least valuable attacker

SEE_VALUE := [PieceType]int {
	.Pawn   = PAWN_CP,
	.Knight = KNIGHT_CP,
	.Bishop = BISHOP_CP,
	.Rook   = ROOK_CP,
	.Queen  = QUEEN_CP,
	.King   = 0, // never captured; king recaptures are handled separately
}

// Pieces of both colors attacking sq, with sliders blocked by occ
attackers_to :: proc(pos: ^GamePosition, sq: int, occ: BitBoard) -> BitBoard {
	w, b := &pos.bb[.White], &pos.bb[.Black]
	t := sq_to_bb(sq)

	// A pawn attacking t sits diagonally behind it from its own side's view
	white_pawns := (((t >> 7) & ~FILE_A) | ((t >> 9) & ~FILE_H)) & w[.Pawn]
	black_pawns := (((t << 7) & ~FILE_H) | ((t << 9) & ~FILE_A)) & b[.Pawn]

	diag := w[.Bishop] | b[.Bishop] | w[.Queen] | b[.Queen]
	orth := w[.Rook] | b[.Rook] | w[.Queen] | b[.Queen]

	return white_pawns | black_pawns |
		(knight_moves[sq] & (w[.Knight] | b[.Knight])) |
		(king_moves[sq] & (w[.King] | b[.King])) |
		(get_bishop_moves(sq, occ) & diag) |
		(get_rook_moves(sq, occ) & orth)
}

// True if the exchange started by move nets at least threshold centipawns for
// the mover. Pins are ignored. Castling, en passant and promotions are scored
// as an even trade
see_ge :: proc(pos: ^GamePosition, move: Move, threshold: int) -> bool {
	from, to := move.pos_init, move.pos_final

	captured, has_victim := pos.board[to].?
	is_castle := move.piece.piecetype == .King && abs(to - from) == 2
	is_en_passant := move.is_capture && !has_victim
	if move.promotion != .Pawn || is_castle || is_en_passant do return 0 >= threshold

	gain := has_victim ? SEE_VALUE[captured.piecetype] : 0

	// Even if nothing recaptures, we fall short
	swap := gain - threshold
	if swap < 0 do return false

	// Even if we lose the moved piece for nothing, we still make it
	swap = SEE_VALUE[move.piece.piecetype] - swap
	if swap <= 0 do return true

	w, b := &pos.bb[.White], &pos.bb[.Black]
	diag := w[.Bishop] | b[.Bishop] | w[.Queen] | b[.Queen]
	orth := w[.Rook] | b[.Rook] | w[.Queen] | b[.Queen]

	occ := all_occupied(pos) &~ sq_to_bb(from)
	attackers := attackers_to(pos, to, occ)
	stm := move.piece.color
	res := 1 // 1 if the side that made the original move is currently winning

	for {
		stm = opp_color(stm)
		attackers &= occ // drop pieces that have already captured

		stm_attackers := attackers & pos.occupied[stm]
		if stm_attackers == 0 do break

		res ~= 1

		// Least valuable attacker. King is last in PieceType, so it is chosen
		// only when nothing else attacks
		attacker := PieceType.King
		for pt in PieceType {
			if stm_attackers & pos.bb[stm][pt] != 0 {
				attacker = pt
				break
			}
		}

		if attacker == .King {
			// The king can only recapture if the other side has no attackers left
			return (attackers & pos.occupied[opp_color(stm)] != 0 ? res ~ 1 : res) == 1
		}

		swap = SEE_VALUE[attacker] - swap
		if swap < res do break

		lsb := stm_attackers & pos.bb[stm][attacker]
		occ &~= lsb & (~lsb + 1)

		// Removing the attacker can uncover a slider behind it
		if attacker == .Pawn || attacker == .Bishop || attacker == .Queen {
			attackers |= get_bishop_moves(to, occ) & diag
		}
		if attacker == .Rook || attacker == .Queen {
			attackers |= get_rook_moves(to, occ) & orth
		}
	}

	return res == 1
}

// Captures that lose material by SEE. Taking an equal or more valuable piece
// can't lose, so those skip the full exchange
losing_capture :: #force_inline proc(pos: ^GamePosition, m: Move) -> bool {
	victim := PieceType.Pawn // en passant and non-capture promotions
	if p, ok := pos.board[m.pos_final].?; ok do victim = p.piecetype

	if SEE_VALUE[victim] >= SEE_VALUE[m.piece.piecetype] do return false

	return !see_ge(pos, m, 0)
}
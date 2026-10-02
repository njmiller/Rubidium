package main

INF :: 32000
MATE :: 31000
MAX_PLY :: 128

is_mate_score :: #force_inline proc(s: int) -> bool {
	return abs(s) > MATE - MAX_PLY
}

nega_max :: proc(depth: int, pos: ^GamePosition, alpha: int, beta: int) -> int {
	if depth == 0 do return eval_position(pos)

	score : int
	alpha := alpha

	maxscore := -INF

	all_moves := gen_moves(pos)

	for i in 0..<all_moves.n {
		move := all_moves.moves[i]
		mi := apply_move_inplace(move, pos)

		if !is_in_check(move.piece.color, pos) {
			score = -nega_max(depth-1, pos, -beta, -alpha)
			if score > maxscore do maxscore = score

			alpha = max(alpha, score)
		}
		undo_move_inplace(move, mi, pos)

		if alpha >= beta do break

	}

	return maxscore
}

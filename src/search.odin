package main

import "core:container/queue"

nega_max :: proc(depth: int, pos: ^GamePosition) -> int {
	if depth == 0 do return eval_position(pos)

	max := -1000000

	all_moves := gen_moves(pos)

	for i in 0..<all_moves.n {
		move := all_moves.moves[i]
		mi := apply_move_inplace(move, pos)
		score := -nega_max(depth-1, pos)
		undo_move_inplace(move, mi, pos)
		if score > max do max = score
	}
	return max
}

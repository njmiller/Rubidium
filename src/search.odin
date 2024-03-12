package main

import "core:container/queue"

alpha_beta_max :: proc(alpha: int, beta: int, depthleft: int, pos: ^GamePosition) -> int {
	//moves : ^queue.Queue(Move) = gen_moves(pos)
	moves := gen_moves(pos)

	move: Move
	score: int
	alpha_out := alpha

	if depthleft == 0 do return eval_position(pos)

	for queue.len(moves^) > 0 {
		move = queue.pop_front(moves)
		move_info := apply_move_inplace(move, pos)
		score = alpha_beta_min(alpha, beta, depthleft - 1, pos)
		undo_move_inplace(move, move_info, pos)
		if score >= beta do return beta
		if score > alpha_out do alpha_out = score
	}

	return alpha_out
}

alpha_beta_min :: proc(alpha: int, beta: int, depthleft: int, pos: ^GamePosition) -> int {
	//moves: ^queue.Queue(Move) = gen_moves(pos)
	moves := gen_moves(pos)
	move: Move
	score: int
	beta_out := beta

	if depthleft == 0 do return -eval_position(pos)

	for queue.len(moves^) > 0 {
		move = queue.pop_front(moves)
		info := apply_move_inplace(move, pos)
		score = alpha_beta_min(alpha, beta, depthleft - 1, pos)
		undo_move_inplace(move, info, pos)
		if score <= alpha do return alpha
		if score < beta_out do beta_out = score
	}

	return beta_out
}

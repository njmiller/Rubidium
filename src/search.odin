package main

import "core:fmt"
import "core:sync"
import "core:time"

INF :: 32000
MATE :: 31000
MAX_PLY :: 128
MAX_GAME_PLY :: 1024

MOVE_OVERHEAD :: 30 * time.Millisecond

stop_flag : bool

SearchLimits :: struct {
	depth: int,
	time_budget: time.Duration, // 0 = no limit
	nodes: int,
	infinite: bool,
}

SearchState :: struct {
	nodes : int,
	history : History,
	start: time.Tick,
	limits: SearchLimits,
}

History :: struct {
	keys: [MAX_GAME_PLY + MAX_PLY]u64,
	len: int,
}

check_limits :: proc(s: ^SearchState) {
	if s.nodes & 2047 != 0 do return

	over_time := s.limits.time_budget > 0 && time.tick_since(s.start) >= s.limits.time_budget
	over_nodes := s.limits.nodes > 0 && s.nodes >= s.limits.nodes

	if over_time || over_nodes do sync.atomic_store_explicit(&stop_flag, true, .Relaxed)
}
time_budget :: proc(time_left_ms, inc_ms, movestogo: int) -> time.Duration {
	left := time.Duration(max(time_left_ms, 0)) * time.Millisecond
	inc := time.Duration(max(inc_ms, 0)) * time.Millisecond
	mtg := movestogo > 0 ? movestogo : 30 // sudden death: assume ~30 moves left

	budget := left / time.Duration(mtg) + inc * 3 / 4
	budget = min(budget, left - MOVE_OVERHEAD) // never plan past the flag

	return max(budget, time.Millisecond)
}

should_stop :: #force_inline proc() -> bool {
	return sync.atomic_load_explicit(&stop_flag, .Relaxed)
}

is_repetition :: proc(h: ^History, key: u64, halfmove: int) -> bool {
	// Only need to check positions since the last capture/pawn move
	// and only with the same side to move (step back 2 plies at a time

	// Only check one repetition. If we repeat once, we will probably
	// repeat again
	start := max(0, h.len - halfmove)
	for i := h.len - 2; i >= start; i -= 2 {
		if h.keys[i] == key do return true
	}
	return false
}

is_mate_score :: #force_inline proc(s: int) -> bool {
	return abs(s) > MATE - MAX_PLY
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

negamax :: proc(s: ^SearchState, pos: ^GamePosition, depth, ply, alpha, beta: int) -> int {
	s.nodes += 1
	check_limits(s)

	if should_stop() do return 0

	if ply > 0 {
		// Draw by 50-move rule or repetition
		if pos.halfmove >= 100 || is_repetition(&s.history, pos.hash, pos.halfmove) do return 0
	}

	// Adding hash key to history
	s.history.keys[s.history.len] = pos.hash
	s.history.len += 1
	defer s.history.len -= 1

	if depth == 0 do return quiesce(s, pos, ply, alpha, beta)
	if ply >= MAX_PLY do return eval_position(pos)

	score : int
	alpha := alpha

	maxscore := -INF

	all_moves := gen_moves(pos)

	legal_moves := 0
	for i in 0..<all_moves.n {
		move := pick_next_move(&all_moves, i)

		mi := apply_move_inplace(move, pos)

		if !is_in_check(move.piece.color, pos) {
			legal_moves += 1

			score = -negamax(s, pos, depth-1, ply+1, -beta, -alpha)
			if score > maxscore do maxscore = score
			// maxscore = max(maxscore, score)

			alpha = max(alpha, score)
		}
		undo_move_inplace(move, mi, pos)

		if alpha >= beta do break

	}

	if legal_moves == 0 {
		// Checkmate if we are in check, otherwise it is stalemate
		return is_in_check(pos.turn, pos) ? -(MATE - ply) : 0
	}

	return maxscore
}

quiesce :: proc(s: ^SearchState, pos: ^GamePosition, ply, alpha, beta: int) -> int {
	s.nodes += 1
	check_limits(s)

	if should_stop() do return 0

	static_eval := eval_position(pos)

	if ply >= MAX_PLY do return static_eval

	best_val := static_eval

	alpha := alpha

	if best_val >= beta do return best_val

	if best_val >= alpha do alpha = best_val

	ml := gen_moves(pos)

	for i in 0..<ml.n {
		move := pick_next_move(&ml, i)

		if !move.is_capture do break

		mi := apply_move_inplace(move, pos)

		if is_in_check(move.piece.color, pos) {
			undo_move_inplace(move, mi, pos)
			continue
		}

		score := -quiesce(s, pos, ply+1, -beta, -alpha)

		undo_move_inplace(move, mi, pos)

		if score >= beta do return score
		if score > best_val do best_val = score
		if score > alpha do alpha = score
	}

	return best_val
}

search_root :: proc(s: ^SearchState, pos: ^GamePosition, depth: int, prev_best: Move) -> (best_move: Move, best_score: int) {
	s.nodes += 1

	alpha := -INF
	beta := INF
	best_score = -INF
	best_move = NULL_MOVE

	// Push the root hash so repetitions found deepr in the tree see it
	s.history.keys[s.history.len] = pos.hash
	s.history.len += 1
	defer s.history.len -= 1

	ml := gen_moves(pos)

	// Search the previous iteration's best move fitst. This makes alpha-beta
	// cut much more, and it means a partial iteration still search the best move
	if prev_best != NULL_MOVE {
		for i in 0..<ml.n {
			if move_equal(ml.moves[i], prev_best) {
				ml.scores[i] = max(int)
				break
			}
		}
	}

	for i in 0..<ml.n {
		move := pick_next_move(&ml, i)

		mi := apply_move_inplace(move, pos)
		if is_in_check(move.piece.color, pos) {
			undo_move_inplace(move, mi, pos)
			continue
		}

		score := -negamax(s, pos, depth-1, 1, -beta, -alpha)
		undo_move_inplace(move, mi, pos)

		if should_stop() do break

		if score > best_score {
			best_score = score
			best_move = move
		}

		if score > alpha do alpha = score

	}
	
	// best_move == NULL_MOVE here means no legal moves (checkmate or stalemate)
	return
}

search :: proc(pos: ^GamePosition, game_history: ^History, limits: SearchLimits) -> Move {
	s: SearchState
	s.history = game_history^
	s.start = time.tick_now()
	s.limits = limits

	best_move := NULL_MOVE
	for depth in 1..=limits.depth {
		move, score := search_root(&s, pos, depth, best_move)

		stopped := should_stop()
		// Don't trust a partial iteration. Kepp the last completed one
		// (unless we have nothing yet)
		if stopped && best_move != NULL_MOVE do break
		if move != NULL_MOVE do best_move = move

		// Calculated time elapsed and nodes per second for info statement
		elapsed := time.tick_since(s.start)
		ms := i64(elapsed / time.Millisecond)
		nps := ms > 0 ? i64(s.nodes) * 1000 / ms : 0
		
		buf: [5]u8
		if is_mate_score(score) {
			plies := MATE - abs(score)
			mate_in := (plies + 1) / 2
			fmt.printf("info depth %d score mate %d time %d nodes %d nps %d pv %s\n",
				depth, score > 0 ? mate_in : -mate_in, ms, s.nodes, nps, move_to_uci(best_move, &buf))
		} else {

			fmt.printf("info depth %d score cp %d time %d nodes %d nps %d pv %s\n",
				depth, score, ms, s.nodes, nps, move_to_uci(best_move, &buf))
		}

		if limits.time_budget > 0 && time.tick_since(s.start) > limits.time_budget / 2 do break

		if stopped || is_mate_score(score) do break

	}

	return best_move

}

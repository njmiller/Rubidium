package main

import "core:fmt"
import "core:sync"
import "core:time"

INF :: 32000
MATE :: 31000

KILLER_1 :: 900_000
KILLER_2 :: 800_000
HISTORY_MAX :: 16384

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
	killers: [MAX_PLY][2]Move,
	quiet_history: [Color][64][64]int,
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

store_killer :: proc(s: ^SearchState, ply: int, move: Move) {
	if move_equal(s.killers[ply][0], move) do return
	s.killers[ply][1] = s.killers[ply][0]
	s.killers[ply][0] = move
}

update_history :: proc(s: ^SearchState, move: Move, bonus: int) {
	h := &s.quiet_history[move.piece.color][move.pos_init][move.pos_final]
	h^ += bonus - h^ * abs(bonus) / HISTORY_MAX
}

// https://en.wikipedia.org/wiki/Negamax
negamax :: proc(s: ^SearchState, pos: ^GamePosition, depth, ply, alpha, beta: int) -> int {
	s.nodes += 1
	check_limits(s)

	if should_stop() do return 0

	if ply > 0 {
		// Draw by 50-move rule or repetition
		if pos.halfmove >= 100 || is_repetition(&s.history, pos.hash, pos.halfmove) do return 0
	}

	if ply >= MAX_PLY do return eval_position(pos)

	// Adding hash key to history
	s.history.keys[s.history.len] = pos.hash
	s.history.len += 1
	defer s.history.len -= 1

	if depth == 0 do return quiesce(s, pos, ply, alpha, beta)

	score : int
	alpha := alpha
	alpha_orig := alpha
	
	// Transposition table probe
	tt_move: u16 = 0
	if e, hit := tt_probe(pos.hash); hit {
		tt_move = e.move
		if ply > 0 && int(e.depth) >= depth {
			tt_score := score_from_tt(int(e.score), ply)
			switch e.bound {
				case .Exact: return tt_score
				case .Lower: if tt_score >= beta do return tt_score
				case .Upper: if tt_score <= alpha do return tt_score
				case .None:
			}
		}
	}


	all_moves := gen_moves(pos)

	// Order: TT move, captures (MVV-LVA), killers, other quiets
	for i in 0..<all_moves.n {
		m := all_moves.moves[i]
		if pack_move(m) == tt_move {
			all_moves.scores[i] = max(int)
		} else if !m.is_capture {
			if move_equal(m, s.killers[ply][0]) do all_moves.scores[i] = KILLER_1
			else if move_equal(m, s.killers[ply][1]) do all_moves.scores[i] = KILLER_2
			else do all_moves.scores[i] = s.quiet_history[m.piece.color][m.pos_init][m.pos_final]
		}
	}

	maxscore := -INF
	best_move := NULL_MOVE
	legal_moves := 0
	for i in 0..<all_moves.n {
		move := pick_next_move(&all_moves, i)

		mi := apply_move_inplace(move, pos)

		if !is_in_check(move.piece.color, pos) {
			legal_moves += 1

			score = -negamax(s, pos, depth-1, ply+1, -beta, -alpha)
			if score > maxscore {
				maxscore = score
				if score > alpha {
					alpha = score
					best_move = move
				}
			}
		}
		undo_move_inplace(move, mi, pos)

		if alpha >= beta {
			if !move.is_capture {
				store_killer(s, ply, move)
				update_history(s, move, min(depth * depth, HISTORY_MAX))
			}
			break
		}

	}

	if legal_moves == 0 {
		// Checkmate if we are in check, otherwise it is stalemate
		return is_in_check(pos.turn, pos) ? -(MATE - ply) : 0
	}

	// Transpotion table store
	if !should_stop() {
		bound: Bound
		if maxscore <= alpha_orig {
			bound = .Upper
		} else if maxscore >= beta {
			bound = .Lower
		} else {
			bound = .Exact
		}
		tt_store(pos.hash, best_move, maxscore, depth, bound, ply)
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

		if should_stop() {
			// An unfinished search still has to return a legal move
			if best_move == NULL_MOVE do best_move = move
			break
		}

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

	tt_age += 1

	best_move := NULL_MOVE
	for depth in 1..=limits.depth {
		move, score := search_root(&s, pos, depth, best_move)

		// Don't trust a partial iteration. Kepp the last completed one
		// (unless we have nothing yet)
		if should_stop() {
			if best_move == NULL_MOVE do best_move = move
			break
		}
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

		if is_mate_score(score) do break

	}

	return best_move

}

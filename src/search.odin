package main

import "core:fmt"
import "core:sync"
import "core:time"
import "core:math"

INF :: 32000
MATE :: 31000
MATE_BOUND :: MATE - MAX_PLY // scores beyond this are mate scores

MAX_PLY :: 128
MAX_GAME_PLY :: 1024

MOVE_OVERHEAD :: 30 * time.Millisecond

FP_MAX_DEPTH :: 6
FP_BASE :: 100
FP_MARGIN :: 75 // centipawns per ply of remaining depth

RFP_MAX_DEPTH :: 7
RFP_MARGIN :: 80 // centipawns per ply of remaining depth

lmr_table: [64][64]int

stop_flag : bool

SearchLimits :: struct {
	depth: int,
	soft_time: time.Duration, // don't start a new iteration after this (0 = no limit)
	hard_time: time.Duration, // abort the search at this point (0 = no limit)
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

@(init)
init_lmr :: proc "contextless" () {
	// Construct a table that determines the late move reduction depth
	// based on current depth and move's ordered position
	for d in 1..<64 {
		for m in 1..<64 {
			lmr_table[d][m] = int(0.75 + math.ln(f64(d)) * math.ln(f64(m)) / 2.25)
		}
	}
}

check_limits :: proc(s: ^SearchState) {
	if s.nodes & 2047 != 0 do return

	over_time := s.limits.hard_time > 0 && time.tick_since(s.start) >= s.limits.hard_time
	over_nodes := s.limits.nodes > 0 && s.nodes >= s.limits.nodes

	if over_time || over_nodes do sync.atomic_store_explicit(&stop_flag, true, .Relaxed)
}

time_limits :: proc(time_left_ms, inc_ms, movestogo: int) -> (soft, hard: time.Duration) {
	left := time.Duration(max(time_left_ms, 0)) * time.Millisecond
	inc := time.Duration(max(inc_ms, 0)) * time.Millisecond
	mtg := movestogo > 0 ? movestogo : 25 // sudden death: assume ~25 moves left

	// Never plan past the flag
	max_time := max(left - MOVE_OVERHEAD, time.Millisecond)

	base := left / time.Duration(mtg) + inc * 3 / 4

	// Hard limit: room for an iteration started just before the soft limit
	// to finish, but never more than half the remaining time
	hard = min(base * 3, max_time / 2)
	soft = min(base, hard)

	return max(soft, time.Millisecond), max(hard, time.Millisecond)
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

history_push :: #force_inline proc(h: ^History, key: u64) {
	h.keys[h.len] = key
	h.len += 1
}

is_mate_score :: #force_inline proc(s: int) -> bool {
	return abs(s) > MATE_BOUND
}

// Returns the TT score and true if the entry is deep enough and its bound
// lets us cut at this node
tt_cutoff :: #force_inline proc(e: ^TTEntry, depth, ply, alpha, beta: int) -> (int, bool) {
	if int(e.depth) < depth do return 0, false

	score := score_from_tt(int(e.score), ply)
	switch e.bound {
	case .Exact: return score, true
	case .Lower: return score, score >= beta
	case .Upper: return score, score <= alpha
	case .None:
	}
	return 0, false
}

// Reverse futility pruning: at shallow depth, if static eval beats beta by a
// depth-scaled margin, assume the opponent can't recover
rfp_ok :: #force_inline proc(depth, static_eval, beta: int) -> bool {
	return depth <= RFP_MAX_DEPTH && !is_mate_score(beta) &&
		static_eval - RFP_MARGIN * depth >= beta
}

// Null move pruning needs enough depth, an eval already above beta, and
// non-pawn material (to avoid zugzwang)
null_move_ok :: #force_inline proc(pos: ^GamePosition, depth, static_eval, beta: int) -> bool {
	return depth >= 3 && static_eval >= beta && has_non_pawn_material(pos, pos.turn)
}

// Futility pruning: static eval so far below alpha that a quiet move is
// unlikely to make up the difference
futile :: #force_inline proc(depth, static_eval, alpha: int) -> bool {
	return depth <= FP_MAX_DEPTH && static_eval + FP_BASE + FP_MARGIN * depth <= alpha
}

// Late move reduction, reduced less for moves with good history. Always
// leaves at least one ply of depth
lmr_reduction :: #force_inline proc(depth, move_num, order_score: int) -> int {
	r := lmr_table[min(depth, 63)][min(move_num, 63)] - order_score / 8192
	return clamp(r, 0, depth - 2)
}

bound_for :: #force_inline proc(score, alpha_orig, beta: int) -> Bound {
	if score <= alpha_orig do return .Upper
	if score >= beta do return .Lower
	return .Exact
}

// https://en.wikipedia.org/wiki/Negamax
negamax :: proc(
	s: ^SearchState,
	pos: ^GamePosition,
	depth: int,
	ply: int,
	alpha: int,
	beta: int,
	allow_null := true,
) -> int {
	s.nodes += 1
	check_limits(s)

	if should_stop() do return 0

	if ply > 0 {
		// Draw by 50-move rule or repetition
		if pos.halfmove >= 100 || is_repetition(&s.history, pos.hash, pos.halfmove) do return 0
	}

	if ply >= MAX_PLY do return eval_position(pos)

	history_push(&s.history, pos.hash)
	defer s.history.len -= 1

	if depth <= 0 do return quiesce(s, pos, ply, alpha, beta)

	in_check := is_in_check(pos.turn, pos)

	score : int
	alpha := alpha
	alpha_orig := alpha

	// Transposition table probe
	tt_move: u16 = 0
	if e, hit := tt_probe(pos.hash); hit {
		tt_move = e.move
		if ply > 0 {
			if tt_score, cut := tt_cutoff(e, depth, ply, alpha, beta); cut do return tt_score
		}
	}

	pv_node := beta - alpha > 1
	can_prune_node := !pv_node && !in_check

	// Static eval for pruning decisions. Not meaningful when in check
	static_eval := in_check ? -INF : eval_position(pos)

	if can_prune_node && rfp_ok(depth, static_eval, beta) do return static_eval

	if can_prune_node && allow_null && null_move_ok(pos, depth, static_eval, beta) {
		R := 3 + depth / 6
		ni := apply_null_move(pos)
		null_score := -negamax(s, pos, max(depth - 1 - R, 0), ply+1, -beta, -beta+1, false)
		undo_null_move(ni, pos)

		if should_stop() do return 0

		if null_score >= beta {
			// Don't return an unproven mate score from a null move search
			return is_mate_score(null_score) ? beta : null_score
		}
	}

	all_moves : MoveList = ---
	gen_moves(pos, &all_moves)
	score_moves(s, &all_moves, pos, ply, tt_move)

	maxscore := -INF
	best_move := NULL_MOVE
	legal_moves := 0
	quiets_tried: [256]Move = ---
	n_quiets := 0
	for i in 0..<all_moves.n {
		move := pick_next_move(&all_moves, i)
		quiet := is_quiet(move)

		mi, legal := try_move(move, pos)
		if !legal do continue

		legal_moves += 1
		gives_check := is_in_check(pos.turn, pos) // pos.turn is opponent now

		// Shallow-depth pruning of quiet moves. Never prune the first move,
		// and stop pruning if every line searched so far gets us mated
		can_prune := can_prune_node && quiet && !gives_check &&
			legal_moves > 1 && maxscore > -MATE_BOUND

		if can_prune && futile(depth, static_eval, alpha) {
			undo_move_inplace(move, mi, pos)
			continue
		}

		if legal_moves == 1 {
			// First move: full window
			score = -negamax(s, pos, depth-1, ply+1, -beta, -alpha)
		} else {
			// Late move reductions
			r := 0
			is_killer := all_moves.scores[i] >= KILLER_2 && all_moves.scores[i] < CAPTURE_BASE

			if depth >= 3 && legal_moves >= 4 && quiet && !is_killer && !in_check && !gives_check {
				r = lmr_reduction(depth, legal_moves, all_moves.scores[i])
			}

			// Reduced depth, null window
			score = -negamax(s, pos, depth-1-r, ply+1, -alpha-1, -alpha)

			// Reduced search beat alpha: verify at full depth
			if r > 0 && score > alpha {
				score = -negamax(s, pos, depth-1, ply+1, -alpha-1, -alpha)
			}

			// Beat alpha at full depth but didn't fail high; get its exact score
			if score > alpha && score < beta {
				score = -negamax(s, pos, depth-1, ply+1, -beta, -alpha)
			}
		}
		undo_move_inplace(move, mi, pos)

		if quiet {
			quiets_tried[n_quiets] = move
			n_quiets += 1
		}

		if score > maxscore {
			maxscore = score
			if score > alpha {
				alpha = score
				best_move = move
			}
		}

		if alpha >= beta {
			if quiet {
				bonus := min(depth * depth, HISTORY_MAX)
				store_killer(s, ply, move)
				update_history(s, move, bonus)

				// Penalize quiets tried before cutoff
				for j in 0..<n_quiets-1 do update_history(s, quiets_tried[j], -bonus)
			}
			break
		}

	}

	if legal_moves == 0 {
		// Checkmate if we are in check, otherwise it is stalemate
		return in_check ? -(MATE - ply) : 0
	}

	// Transposition table store
	if !should_stop() {
		tt_store(pos.hash, best_move, maxscore, depth, bound_for(maxscore, alpha_orig, beta), ply)
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

	ml : MoveList = ---
	gen_moves(pos, &ml)
	mvv_lva(&ml, pos)

	for i in 0..<ml.n {
		move := pick_next_move(&ml, i)

		// Only captures and queen promotions
		if ml.scores[i] < CAPTURE_BASE do break

		mi, legal := try_move(move, pos)
		if !legal do continue

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
	history_push(&s.history, pos.hash)
	defer s.history.len -= 1

	ml : MoveList = ---
	gen_moves(pos, &ml)
	mvv_lva(&ml, pos)

	// Search the previous iteration's best move first. This makes alpha-beta
	// cut much more, and it means a partial iteration still searches the best move
	if prev_best != NULL_MOVE {
		for i in 0..<ml.n {
			if move_equal(ml.moves[i], prev_best) {
				ml.scores[i] = max(int)
				break
			}
		}
	}

	legal_moves := 0
	for i in 0..<ml.n {
		move := pick_next_move(&ml, i)

		mi, legal := try_move(move, pos)
		if !legal do continue
		legal_moves += 1

		score: int
		if legal_moves == 1 {
			score = -negamax(s, pos, depth-1, 1, -beta, -alpha)
		} else {
			score = -negamax(s, pos, depth-1, 1, -alpha-1, -alpha)
			if score > alpha && score < beta {
				score = -negamax(s, pos, depth-1, 1, -beta, -alpha)
			}
		}
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

	stability := 0
	best_move := NULL_MOVE
	for depth in 1..=limits.depth {
		move, score := search_root(&s, pos, depth, best_move)

		// Don't trust a partial iteration. Kepp the last completed one
		// (unless we have nothing yet)
		if should_stop() {
			if best_move == NULL_MOVE do best_move = move
			break
		}
		if move != NULL_MOVE {
			stability = move_equal(move, best_move) ? min(stability + 1, 4) : 0
			best_move = move
		}

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

		// Stable best move: stop sooner.
		// Changing best move: allow more time
		STABILITY_SCALE := [5]f64{1.5, 1.2, 1.0, 0.85, 0.7}
		soft := time.Duration(f64(limits.soft_time) * STABILITY_SCALE[stability])
		if limits.soft_time > 0 && time.tick_since(s.start) >= soft do break
		
		if is_mate_score(score) do break

	}

	return best_move

}

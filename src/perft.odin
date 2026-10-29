package main

import "core:fmt"

PerftStats :: struct {
	nodes:            u64,
	captures:         u64,
	en_passant:       u64,
	castles:          u64,
	promotions:       u64,
	checks:           u64,
	checkmates:       u64,
	discovery_checks: u64,
	double_checks:    u64,
}

perft :: proc(depth: int, position: ^GamePosition, stats: ^PerftStats) {
	// if depth == 0 do return 1
	if depth == 0 {
		stats.nodes += 1
		return
	}

	move_list : MoveList = ---
	gen_moves(position, &move_list)

	for i in 0..<move_list.n {
		move := move_list.moves[i]
		info, legal := try_move(move, position)
		if !legal do continue

		if depth == 1 {
			// Only tally leaf-move properties
			if move.is_capture do stats.captures += 1
			if info.is_en_passant do stats.en_passant += 1
			if move.promotion != .Pawn do stats.promotions += 1
			if info.is_castle do stats.castles += 1
			if is_in_check(opp_color(move.piece.color), position) do stats.checks += 1
		}
		perft(depth - 1, position, stats)

		undo_move_inplace(move, info, position)
	}

	return
}

perft_divide :: proc(depth: int, position: ^GamePosition) -> u64 {
	if depth <= 0 do return 0

	total_nodes: u64 = 0
	display_position(position^)

	move_list : MoveList = ---
	gen_moves(position, &move_list)

	fmt.println("NMoves:", move_list.n)

	fmt.printf("\n--- Perft Divide Depth %d ---\n", depth)
	for i in 0..<move_list.n {
		move := move_list.moves[i]
		info, legal := try_move(move, position)
		if !legal do continue

		stats : PerftStats
		perft(depth - 1, position, &stats)
		total_nodes += stats.nodes

		// Print move in UCI format (e.g. e2e4)
		buf: [5]u8
		s := move_to_uci(move, &buf)
		fmt.printf("%s: %d ", s, stats.nodes)
		fmt.println(move.piece.color, move.piece.piecetype)

		undo_move_inplace(move, info, position)
	}

	fmt.printf("\nTotal leaf nodes: %d\n", total_nodes)

	return total_nodes
}

run_perft :: proc(fen: string, depth: int) {
	pos := process_fen(fen)

	perft_divide(depth, &pos)
}

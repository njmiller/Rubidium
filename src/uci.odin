package main

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

Engine :: struct {
	pos: GamePosition,
	history: History, // hashes of positions before pos
}

engine: Engine

SearchJob :: struct {
	pos: GamePosition,
	history: History,
	limits: SearchLimits,
}

job: SearchJob
search_thread: ^thread.Thread

start_search :: proc(limits: SearchLimits) {
	stop_search() // don't let two searches run at once

	job = SearchJob{engine.pos, engine.history, limits}
	sync.atomic_store_explicit(&stop_flag, false, .Relaxed)
	search_thread = thread.create_and_start_with_poly_data(&job, search_worker)
}

stop_search :: proc() {
	if search_thread == nil do return
	sync.atomic_store_explicit(&stop_flag, true, .Relaxed)
	thread.destroy(search_thread) // joins, then frees
	search_thread = nil
}

search_worker :: proc(job: ^SearchJob) {
	best := search(&job.pos, &job.history, job.limits)

	// For "go infinite" (and later "ponder"), don't send bestmove until the GUI says stop
	if job.limits.infinite {
		for !sync.atomic_load_explicit(&stop_flag, .Relaxed) do time.sleep(time.Millisecond)
	}

	buf: [5]u8
	fmt.printf("bestmove %s\n", move_to_uci(best, &buf))
}

move_to_uci :: proc(m: Move, buf: ^[5]u8) -> string {

	if m == NULL_MOVE do return string("0000")

	buf[0] = 'a' + u8(m.pos_init % 8)
	buf[1] = '1' + u8(m.pos_init / 8)

	buf[2] = 'a' + u8(m.pos_final % 8)
	buf[3] = '1' + u8(m.pos_final / 8)

	n := 4
	switch m.promotion {
		case .Pawn, .King:
		case .Knight:
			buf[4]= 'n'
		case .Bishop:
			buf[4] = 'b'
		case .Rook:
			buf[4] = 'r'
		case .Queen:
			buf[4] = 'q'
	}

	if m.promotion != .Pawn do n = 5

	return string(buf[:n])
}

read_uci_gui :: proc(input: string) -> bool {
	trimmed := strings.trim_space(input)
	tokens := strings.split(trimmed, " ")
	defer delete(tokens)

	if len(tokens) == 0 {
		return true
	}

	command := tokens[0]

	switch command {
	case "uci":
		handle_uci()
	case "isready":
		handle_isready()
	case "ucinewgame":
		handle_ucinewgame()
	case "position":
		handle_position(tokens[1:])
	case "go":
		handle_go(tokens[1:])
	case "stop":
		handle_stop()
	case "quit":
		handle_quit()
		return false
	case:
	// Unknown command, ignore silently per UCI spec
	}

	return true
}

handle_uci :: proc() {
	fmt.println("id name Rubidium")
	fmt.println("id author Nathan Miller")
	fmt.println("uciok")
}

handle_isready :: proc() {
	fmt.println("readyok")
}

handle_ucinewgame :: proc() {
	stop_search()

	// Reset engine state for new game
	engine.pos = gen_newgame()
	engine.history.len = 0
}

handle_position :: proc(args: []string) {
	stop_search()

	if len(args) == 0 do return

	idx := 0

	switch args[0] {
		case "startpos":
			engine.pos = gen_newgame()
			idx = 1
		case "fen" :
			idx = 1
			for idx < len(args) && args[idx] != "moves" do idx += 1
			engine.pos = process_fen(strings.join(args[1:idx], " ", context.temp_allocator))
		case:
			return
	}
	engine.history.len = 0

	if idx < len(args) && args[idx] == "moves" do idx += 1

	for tok in args[idx:] {
		if len(tok) < 4 do break

		if engine.history.len >= MAX_GAME_PLY do break

		m := parse_uci_move(&engine.pos, tok)
		engine.history.keys[engine.history.len] = engine.pos.hash
		engine.history.len += 1
		apply_move_inplace(m, &engine.pos)

	}
}

next_int :: proc(args: []string, i: ^int, current: int) -> int {
	i^ += 1
	if i^ >= len(args) do return current
	return strconv.parse_int(args[i^]) or_else current
}

handle_go :: proc(args: []string) {
	// Parse search parameters
	wtime, btime, winc, binc, movestogo, movetime: int
	has_clock := false

	limits := SearchLimits{depth = MAX_PLY}

	for i := 0; i < len(args); i += 1 {
		switch args[i] {
		case "wtime":
			// Parse white time in milliseconds
			wtime = next_int(args, &i, 0)
			has_clock = true
		case "btime":
			// Parse black time in milliseconds  
			btime = next_int(args, &i, 0)
			has_clock = true
		case "winc":
			// Parse white increment
			winc = next_int(args, &i, 0)
		case "binc":
			// Parse black increment
			binc = next_int(args, &i, 0)
		case "movestogo":
			// Parse moves to go
			movestogo = next_int(args, &i, 0)
		case "depth":
			// Parse search depth
			limits.depth = next_int(args, &i, limits.depth)
		case "nodes":
			// Parse node limit
			limits.nodes = next_int(args, &i, limits.nodes)
		case "movetime":
			// Parse exact search time
			movetime = next_int(args, &i, 0)
		case "infinite":
			// Search until stop command
			limits.infinite = true
		}
	}

	my_time, my_inc := wtime, winc
	if engine.pos.turn == .Black do my_time, my_inc = btime, binc

	switch {
		case limits.infinite:
			// no time limit, wait for stop
		case movetime > 0:
			limits.time_budget = max(time.Duration(movetime) * time.Millisecond - MOVE_OVERHEAD, time.Millisecond)
		case has_clock:
			limits.time_budget = time_budget(my_time, my_inc, movestogo)
	}

	// Start the search with the parsed limits
	start_search(limits)
}

handle_stop :: proc() {
	// Stop current search
	stop_search()
}

handle_quit :: proc() {
	// Clean up and exit
	stop_search()
}

uci_square_to_index :: proc(square: string) -> int {
	if len(square) != 2 {
		return -1
	}

	file := int(square[0]) - int('a')
	rank := int(square[1]) - int('1')

	if file < 0 || file > 7 || rank < 0 || rank > 7 {
		return -1
	}

	return rank * 8 + file
}

parse_uci_move :: proc(pos: ^GamePosition, move_str: string) -> Move {
	pos_init_int := uci_square_to_index(move_str[:2])
	pos_final_int := uci_square_to_index(move_str[2:4])

	promo := PieceType.Pawn
	if len(move_str) >= 5 {
		switch move_str[4] {
			case 'q': promo = .Queen
			case 'r': promo = .Rook
			case 'b': promo = .Bishop
			case 'n': promo = .Knight
		}
	}

	// The moving piece comes from the mailbox; a piece on the final square
	// means the move is a capture
	piece, _ := piece_at(pos, pos_init_int)
	_, is_capture := piece_at(pos, pos_final_int)

	return Move{pos_init_int, pos_final_int, piece, is_capture, promo}
}

package main

import "core:fmt"
import "core:strings"

Engine :: struct {
	pos: GamePosition,
	history: History, // hashes of positions before pos
}

engine: Engine

move_to_uci :: proc(m: Move, buf: ^[5]u8) -> string {

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
	// Reset engine state for new game
	engine.pos = gen_newgame()
	engine.history.len = 0
}

handle_position :: proc(args: []string) {
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
		if engine.history.len >= MAX_GAME_PLY do break

		m := parse_uci_move(&engine.pos, tok)
		engine.history.keys[engine.history.len] = engine.pos.hash
		engine.history.len += 1
		apply_move_inplace(m, &engine.pos)

	}
}

handle_go :: proc(args: []string) {
	// Parse search parameters
	wtime := -1
	btime := -1
	winc := 0
	binc := 0
	movestogo := 0
	depth := -1
	nodes := -1
	movetime := -1

	for i := 0; i < len(args); i += 2 {
		if i + 1 >= len(args) {
			break
		}

		switch args[i] {
		case "wtime":
		// Parse white time in milliseconds
		case "btime":
		// Parse black time in milliseconds  
		case "winc":
		// Parse white increment
		case "binc":
		// Parse black increment
		case "movestogo":
		// Parse moves to go
		case "depth":
		// Parse search depth
		case "nodes":
		// Parse node limit
		case "movetime":
		// Parse exact search time
		case "infinite":
			// Search until stop command
			i -= 1 // No parameter follows
		}
	}

	// Start search with parsed parameters
	// This should run in a separate thread
	best_move := "e2e4" // Placeholder
	fmt.printf("bestmove %s\n", best_move)
}

handle_stop :: proc() {
	// Stop current search
}

handle_quit :: proc() {
	// Clean up and exit
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

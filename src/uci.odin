package main

import "core:fmt"
import "core:strings"

read_uci_gui :: proc(input: string) {
	trimmed := strings.trim_space(input)
	tokens := strings.split(trimmed, " ")
	defer delete(tokens)

	if len(tokens) == 0 {
		return
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
	case:
	// Unknown command, ignore silently per UCI spec
	}
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
}

handle_position :: proc(args: []string) {
	if len(args) == 0 {
		return
	}

	if args[0] == "startpos" {
		pos := gen_newgame()
		moves_start := -1
		for arg, i in args {
			if arg == "moves" {
				moves_start = i + 1
				break
			}
		}

		if moves_start != -1 && moves_start < len(args) {
			// Apply moves from starting position
			for i := moves_start; i < len(args); i += 1 {
				// Apply move args[i]
			}
		}
	} else if args[0] == "fen" {
		// Parse FEN string - typically the next 6 tokens
		if len(args) >= 7 {
			fen_parts := args[1:7]
			// Parse FEN position

			moves_start := -1
			for arg, i in args {
				if arg == "moves" {
					moves_start = i + 1
					break
				}
			}

			if moves_start != -1 && moves_start < len(args) {
				// Apply moves from FEN position
				for i := moves_start; i < len(args); i += 1 {
					// Apply move args[i]
				}
			}
		}
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

process_uci_move_color :: proc(pos: GamePosition, pos_str: string) -> Color {
	square_idx := uci_square_to_index(pos_str)
	if square_idx == -1 {
		return .White // Invalid square, return default
	}

	square_bb := BitBoard(1) << uint(square_idx)

	// Check if white piece is on this square
	if (pos.white.AllPieces & square_bb) != 0 {
		return .White
	}

	// Check if black piece is on this square  
	if (pos.black.AllPieces & square_bb) != 0 {
		return .Black
	}

	// No piece on square, return default
	return .White
}

determine_piece :: proc(pos: PositionOneColor, sq_bb: BitBoard) -> PieceType {
	if pos.Pawns & sq_bb != 0 {
		return .Pawn
	} else if pos.Knights & sq_bb != 0 {
		return .Knight
	} else if pos.Bishops & sq_bb != 0 {
		return .Bishop
	} else if pos.Rooks & sq_bb != 0 {
		return .Rook
	} else if pos.Queens & sq_bb != 0 {
		return .Queen
	} else if pos.King & sq_bb != 0 {
		return .King
	}

	// fmt.println("Error in determining piece")
	return .Pawn
}
process_uci_move :: proc(pos: GamePosition, move_str: string) -> Move {
	pos_init := move_str[:2]
	pos_final := move_str[2:]

	is_capture := false
	piece_type: PieceType

	// Determine which color is moving
	// TODO: Should know this from GamePosition and is not a part of
	// the Move structure
	check_color := process_uci_move_color(pos, pos_init)
	// move_out: Move

	pos_init_int := uci_square_to_index(pos_init)
	pos_final_int := uci_square_to_index(pos_final)

	// Check whether a piece of the opposite color is on the final square
	// If so, it is a capture
	sq_bb := sq_to_bb(pos_final_int)
	sq_bb_i := sq_to_bb(pos_init_int)

	if check_color == .White {
		if pos.black.AllPieces & sq_bb != 0 do is_capture = true
		piece_type = determine_piece(pos.white, sq_bb_i)
	} else {
		if pos.white.AllPieces & sq_bb != 0 do is_capture = true
		piece_type = determine_piece(pos.black, sq_bb_i)
	}

	piece_tmp := Piece{piece_type, check_color}

	move_out := Move{pos_init_int, pos_final_int, piece_tmp, is_capture}

	return move_out
}

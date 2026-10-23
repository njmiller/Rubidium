package main

import "core:bufio"
import "core:fmt"
import "core:log"
import "core:flags"
import "core:os"

process_fen :: proc(fen: string) -> GamePosition {
	pos_out: GamePosition
	pos_out = empty_position()

	col, row: uint

	nchars := len(fen)

	idx := 0
	col = 1
	row = 8
	for {
		sq := rank_file_to_sq(int(row) - 1, int(col) - 1)

		switch fen[idx] {
		case '1' ..= '8':
			col += uint(fen[idx] - 48) - 1
		case '/':
			idx += 1
			continue
		case:
			if p, ok := char_to_piece(fen[idx]); ok do put_piece(&pos_out, p, sq)
		}

		idx += 1
		col += 1

		if row == 1 && col > 8 do break

		if col == 9 {
			row = row - 1
			col = 1
		}

	}

	//NOTE: Still need to do processing of castling
	idx += 1
	if fen[idx] == 'w' {
		pos_out.turn = .White
	} else if fen[idx] == 'b' {
		pos_out.turn = .Black
	} else {
		panic("Issue with FEN color")
	}

	idx += 2
	pos_out.castling = {}
	is_castling := true
	for is_castling {
		switch fen[idx] {
		case 'K':
			pos_out.castling += {.WHITEKINGSIDE}
		case 'Q':
			pos_out.castling += {.WHITEQUEENSIDE}
		case 'k':
			pos_out.castling += {.BLACKKINGSIDE}
		case 'q':
			pos_out.castling += {.BLACKQUEENSIDE}
		case ' ':
			is_castling = false
		}
		idx += 1
	}

	is_enpassant := true
	ep_rank: int
	ep_file: int
	for is_enpassant {
		switch fen[idx] {
		case '-':
			pos_out.en_passant = -1
			is_enpassant = false
			idx += 1
		case ' ':
			pos_out.en_passant = rank_file_to_sq(ep_rank, ep_file)
			is_enpassant = false
		case 'a' ..= 'h':
			ep_file = int(fen[idx]) - int('a')
		case '1' ..= '8':
			ep_rank = int(fen[idx]) - int('1')
		}
		idx += 1
	}

	// Since halfmove and movenum can be omitted from some FEN strings
	if idx < nchars {
		is_hm := true
		hm := 0
		for is_hm {
			switch fen[idx] {
			case ' ':
				is_hm = false
			case '0' ..= '9':
				hm = 10 * hm + int(fen[idx]) - int('0')
			}
			idx += 1
		}
		pos_out.halfmove = hm

		nfen := len(fen)
		movenum := 0
		for i in idx ..< nfen {
			movenum = 10 * movenum + int(fen[i]) - int('0')
		}
		pos_out.movenum = movenum
	}

	pos_out.hash = compute_hash(&pos_out)

	return pos_out
}

run_perft :: proc(fen: string, depth: int) {
	pos := process_fen(fen)

	perft_divide(depth, &pos)
}

main_uci :: proc() {
	s: bufio.Scanner

	bufio.scanner_init(&s, os.to_stream(os.stdin))
	defer bufio.scanner_destroy(&s)

	for bufio.scanner_scan(&s) {
		line := bufio.scanner_text(&s)
		if !read_uci_gui(line) do break

		// Move this inside handle_position???
		free_all(context.temp_allocator)
	}

	return
}

main :: proc() {
	if len(os.args) < 2 {
		main_uci()
		os.exit(0)
	}

	switch os.args[1] {
		case "perft":
			Perft_Options :: struct {
				fen:   string `args:"pos=0,required" usage:"FEN string (quote it)."`,
				depth: int    `args:"pos=1,required" usage:"Search depth"`,
			}
			opts: Perft_Options
			flags.parse_or_exit(&opts, os.args[1:], .Unix)
			run_perft(opts.fen, opts.depth)
		case:
			fmt.println("Bad option")
			os.exit(1)
	}
}

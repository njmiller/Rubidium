package main

import "core:fmt"
import "core:log"
import "core:flags"
import "core:os"

process_fen :: proc(fen: string) -> GamePosition {
	pos_out: GamePosition
	bb_tmp: BitBoard
	shift: uint
	pos_out = empty_position()

	col, row: uint

	nchars := len(fen)

	idx := 0
	col = 1
	row = 8
	for {
		shift = 8 * (row - 1) + (col - 1)

		rank : int = auto_cast row - 1
		file : int = auto_cast col - 1
		rank_bl := 7 - rank

		sq := rank_file_to_sq(rank, file)
		sq_bl := rank_file_to_sq(rank_bl, file) 

		bb_tmp = BitBoard(1) << shift

		switch fen[idx] {
		case 'r':
			pos_out.black.Rooks = pos_out.black.Rooks | bb_tmp
			pos_out.material[.Black] += PIECE_VALUE[.Rook]
			pos_out.psqt_mid[.Black] += rook_square_table[sq_bl]
			pos_out.psqt_end[.Black] += rook_square_table[sq_bl]
			pos_out.phase += PHASE_WEIGHT[.Rook]
		case 'p':
			pos_out.black.Pawns = pos_out.black.Pawns | bb_tmp
			pos_out.material[.Black] += PIECE_VALUE[.Pawn]
			pos_out.psqt_mid[.Black] += pawn_square_table[sq_bl]
			pos_out.psqt_end[.Black] += pawn_square_table[sq_bl]
			pos_out.phase += PHASE_WEIGHT[.Pawn]
		case 'n':
			pos_out.black.Knights = pos_out.black.Knights | bb_tmp
			pos_out.material[.Black] += PIECE_VALUE[.Knight]
			pos_out.psqt_mid[.Black] += knight_square_table[sq_bl]
			pos_out.psqt_end[.Black] += knight_square_table[sq_bl]
			pos_out.phase += PHASE_WEIGHT[.Knight]
		case 'b':
			pos_out.black.Bishops = pos_out.black.Bishops | bb_tmp
			pos_out.material[.Black] += PIECE_VALUE[.Bishop]
			pos_out.psqt_mid[.Black] += bishop_square_table[sq_bl]
			pos_out.psqt_end[.Black] += bishop_square_table[sq_bl]
			pos_out.phase += PHASE_WEIGHT[.Bishop]
		case 'q':
			pos_out.black.Queens = pos_out.black.Queens | bb_tmp
			pos_out.material[.Black] += PIECE_VALUE[.Queen]
			pos_out.psqt_mid[.Black] += queen_square_table[sq_bl]
			pos_out.psqt_end[.Black] += queen_square_table[sq_bl]
			pos_out.phase += PHASE_WEIGHT[.Queen]
		case 'k':
			pos_out.black.King = pos_out.black.King | bb_tmp
			pos_out.material[.Black] += PIECE_VALUE[.King]
			pos_out.psqt_mid[.Black] += king_square_mid[sq_bl]
			pos_out.psqt_end[.Black] += king_square_end[sq_bl]
			pos_out.phase += PHASE_WEIGHT[.King]
		case 'R':
			pos_out.white.Rooks = pos_out.white.Rooks | bb_tmp
			pos_out.material[.White] += PIECE_VALUE[.Rook]
			pos_out.psqt_mid[.White] += rook_square_table[sq]
			pos_out.psqt_end[.White] += rook_square_table[sq]
			pos_out.phase += PHASE_WEIGHT[.Rook]
		case 'P':
			pos_out.white.Pawns = pos_out.white.Pawns | bb_tmp
			pos_out.material[.White] += PIECE_VALUE[.Pawn]
			pos_out.psqt_mid[.White] += pawn_square_table[sq]
			pos_out.psqt_end[.White] += pawn_square_table[sq]
			pos_out.phase += PHASE_WEIGHT[.Pawn]
		case 'N':
			pos_out.white.Knights = pos_out.white.Knights | bb_tmp
			pos_out.material[.White] += PIECE_VALUE[.Knight]
			pos_out.psqt_mid[.White] += knight_square_table[sq]
			pos_out.psqt_end[.White] += knight_square_table[sq]
			pos_out.phase += PHASE_WEIGHT[.Knight]
		case 'B':
			pos_out.white.Bishops = pos_out.white.Bishops | bb_tmp
			pos_out.material[.White] += PIECE_VALUE[.Bishop]
			pos_out.psqt_mid[.White] += bishop_square_table[sq]
			pos_out.psqt_end[.White] += bishop_square_table[sq]
			pos_out.phase += PHASE_WEIGHT[.Bishop]
		case 'Q':
			pos_out.white.Queens = pos_out.white.Queens | bb_tmp
			pos_out.material[.White] += PIECE_VALUE[.Queen]
			pos_out.psqt_mid[.White] += queen_square_table[sq]
			pos_out.psqt_end[.White] += queen_square_table[sq]
			pos_out.phase += PHASE_WEIGHT[.Queen]
		case 'K':
			pos_out.white.King = pos_out.white.King | bb_tmp
			pos_out.material[.White] += PIECE_VALUE[.King]
			pos_out.psqt_mid[.White] += king_square_mid[sq]
			pos_out.psqt_end[.White] += king_square_end[sq]
			pos_out.phase += PHASE_WEIGHT[.King]
		case '1' ..= '8':
			col += uint(fen[idx] - 48) - 1
		case '/':
			idx += 1
			continue
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

	pos_out.black.AllPieces =
		pos_out.black.King |
		pos_out.black.Queens |
		pos_out.black.Rooks |
		pos_out.black.Knights |
		pos_out.black.Bishops |
		pos_out.black.Pawns

	pos_out.white.AllPieces =
		pos_out.white.King |
		pos_out.white.Queens |
		pos_out.white.Rooks |
		pos_out.white.Knights |
		pos_out.white.Bishops |
		pos_out.white.Pawns

	pos_out.hash = compute_hash(&pos_out)

	return pos_out
}

run_perft :: proc(fen: string, depth: int) {
	fmt.println(fen)
	fmt.println(depth)

	pos := process_fen(fen)

	perft_divide(depth, &pos)
}

main_uci :: proc() {
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

package main

import "core:fmt"
import "core:log"
import "core:math/bits"
import "core:strconv"

process_fen :: proc(fen: string) -> GamePosition {
	pos_out: GamePosition
	bb_tmp: BitBoard
	shift: uint
	pos_out = empty_position()

	col, row: uint

	idx := 0
	col = 1
	row = 8
	for {
		shift = 8 * (row - 1) + (col - 1)
		bb_tmp = BitBoard(1) << shift

		switch fen[idx] {
		case 'r':
			pos_out.black.Rooks = pos_out.black.Rooks | bb_tmp
		case 'p':
			pos_out.black.Pawns = pos_out.black.Pawns | bb_tmp
		case 'n':
			pos_out.black.Knights = pos_out.black.Knights | bb_tmp
		case 'b':
			pos_out.black.Bishops = pos_out.black.Bishops | bb_tmp
		case 'q':
			pos_out.black.Queens = pos_out.black.Queens | bb_tmp
		case 'k':
			pos_out.black.King = pos_out.black.King | bb_tmp
		case 'R':
			pos_out.white.Rooks = pos_out.white.Rooks | bb_tmp
		case 'P':
			pos_out.white.Pawns = pos_out.white.Pawns | bb_tmp
		case 'N':
			pos_out.white.Knights = pos_out.white.Knights | bb_tmp
		case 'B':
			pos_out.white.Bishops = pos_out.white.Bishops | bb_tmp
		case 'Q':
			pos_out.white.Queens = pos_out.white.Queens | bb_tmp
		case 'K':
			pos_out.white.King = pos_out.white.King | bb_tmp
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

	return pos_out
}

main :: proc() {

	context.logger = log.create_console_logger()

	pos: GamePosition
	fen: string = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	bb_tmp: BitBoard
	bb_out, occ: BitBoard
	mask: BitBoard
	i: int
	//pos = process_fen(fen)
	//generate_magics()
	init_knight_moves()
	init_king_moves()
	init_magic_bitboards()
	defer free_magic_bitboards()


	occ = BitBoard(1) << 16
	occ |= BitBoard(1) << 17
	occ |= BitBoard(1) << 18
	occ |= BitBoard(1) << 10
	occ |= BitBoard(1) << 2

	fmt.println("FFF:", bits.count_ones(u64(occ)))
	/*
    occ |= BitBoard(1) << 0

    fmt.println("Occupancy")
    display_bitboard(occ)

    bb_tmp = get_rook_moves(0, occ)
    fmt.println("Rook")
    display_bitboard(bb_tmp)

    bb_tmp = get_bishop_moves(0, occ)
    fmt.println("Bishop")
    display_bitboard(bb_tmp)

    /*
    bb_out = init_slider_move(1, occ, false)
    display_bitboard(bb_out)
    fmt.println("")
    bb_out = init_slider_move(1, occ, true)
    display_bitboard(bb_out)
    */

    
    mask = rmask(0)
    display_bitboard(mask)
    mask = get_rook_mask(0)
    display_bitboard(mask)
    */
	sq: int = 0

	//mask = rmask(sq)
	//display_bitboard(mask)
	//mask = get_rook_mask(sq)
	//display_bitboard(mask)

	/*
    n : int = magic_rook_shifts[sq]
    bb_tmp = index_to_bb(sq, n, mask)
    //tmp = batt(27)
    /*
    for i in 0..<100 {
        bb_tmp = index_to_bb(i, 12, mask)
        fmt.println("I = ", i)
        display_bitboard(bb_tmp)
    }
    */
    */
	//generate_magics()

	/*
    bb_tmp = BitBoard(1) << 22 | BitBoard(1) << 10 | BitBoard(1) << 0
    fmt.println("AAA", bb_tmp)
    i = pop_first_bit(&bb_tmp)
    fmt.println("BBB", i, bb_tmp)
    i = pop_first_bit(&bb_tmp)
    fmt.println("BBB", i, bb_tmp)
    i = pop_first_bit(&bb_tmp)
    fmt.println("BBB", i, bb_tmp)
    */

	pos = gen_newgame()

	// display_position(pos)
	// fmt.println(perft(1, &pos))
	perft_divide(1, &pos)
	// fmt.println(perft(2, &pos))

}

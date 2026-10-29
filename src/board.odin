package main

import "core:fmt"

idx_A1 :: 0
idx_B1 :: 1
idx_C1 :: 2
idx_D1 :: 3
idx_E1 :: 4
idx_F1 :: 5
idx_G1 :: 6
idx_H1 :: 7
idx_A2 :: 8
idx_B2 :: 9
idx_C2 :: 10
idx_D2 :: 11
idx_E2 :: 12
idx_F2 :: 13
idx_G2 :: 14
idx_H2 :: 15
idx_A3 :: 16
idx_B3 :: 17
idx_C3 :: 18
idx_D3 :: 19
idx_E3 :: 20
idx_F3 :: 21
idx_G3 :: 22
idx_H3 :: 23
idx_A4 :: 24
idx_B4 :: 25
idx_C4 :: 26
idx_D4 :: 27
idx_E4 :: 28
idx_F4 :: 29
idx_G4 :: 30
idx_H4 :: 31
idx_A5 :: 32
idx_B5 :: 33
idx_C5 :: 34
idx_D5 :: 35
idx_E5 :: 36
idx_F5 :: 37
idx_G5 :: 38
idx_H5 :: 39
idx_A6 :: 40
idx_B6 :: 41
idx_C6 :: 42
idx_D6 :: 43
idx_E6 :: 44
idx_F6 :: 45
idx_G6 :: 46
idx_H6 :: 47
idx_A7 :: 48
idx_B7 :: 49
idx_C7 :: 50
idx_D7 :: 51
idx_E7 :: 52
idx_F7 :: 53
idx_G7 :: 54
idx_H7 :: 55
idx_A8 :: 56
idx_B8 :: 57
idx_C8 :: 58
idx_D8 :: 59
idx_E8 :: 60
idx_F8 :: 61
idx_G8 :: 62
idx_H8 :: 63

GamePosition :: struct {
	bb:         [Color][PieceType]BitBoard,
	occupied:   [Color]BitBoard,   // union of bb[color]
	board:      [64]Maybe(Piece),  // mailbox for O(1) piece lookup by square
	castling:   bit_set[Castling], // Says what castling is available
	en_passant: int, // What square is available for en passant capture
	turn:       Color,
	halfmove:   int,
	movenum:    int,

	// Fields for evaluation that update on move/unmove
	psqt_mid:   [Color]int, // piece-square tables
	psqt_end:   [Color]int, // endgame piece-square table
	phase:      int,        // 0 = endgame, MAX_PHASE = midgame
	hash:       u64,        // Zobrish hash
}

Castling :: enum {
	WHITEKINGSIDE,
	WHITEQUEENSIDE,
	BLACKKINGSIDE,
	BLACKQUEENSIDE,
}

Color :: enum u8 {
	White,
	Black,
}

opp_color :: #force_inline proc "contextless" (color: Color) -> Color {
	if color == .White do return .Black

	return .White
}

PieceType :: enum u8 {
	Pawn,
	Knight,
	Bishop,
	Rook,
	Queen,
	King,
}

// FEN/display characters indexed by int(color) * 6 + int(piecetype)
PIECE_CHARS := "PNBRQKpnbrqk"

Piece :: struct {
	piecetype: PieceType,
	color:     Color,
}

empty_position :: proc() -> GamePosition {
	pos: GamePosition

	pos.castling = {}
	pos.en_passant = -1

	return pos
}

piece_at :: #force_inline proc(pos: ^GamePosition, sq: int) -> (Piece, bool) {
	return pos.board[sq].?
}

all_occupied :: #force_inline proc(pos: ^GamePosition) -> BitBoard {
	return pos.occupied[.White] | pos.occupied[.Black]
}

has_non_pawn_material :: #force_inline proc(pos: ^GamePosition, color: Color) -> bool {
	bb := &pos.bb[color]
	return (bb[.Knight] | bb[.Bishop] | bb[.Rook] | bb[.Queen]) != 0
}

char_to_piece :: proc(c: u8) -> (Piece, bool) {
	for i in 0 ..< len(PIECE_CHARS) {
		if PIECE_CHARS[i] == c do return Piece{PieceType(i % 6), Color(i / 6)}, true
	}
	return {}, false
}

piece_to_char :: #force_inline proc(p: Piece) -> u8 {
	return PIECE_CHARS[int(p.color) * 6 + int(p.piecetype)]
}

// put_piece/remove_piece/move_piece are the only procedures that should change
// piece placement: they keep the bitboards, occupancy, mailbox and incremental
// eval fields in sync
put_piece :: proc(pos: ^GamePosition, p: Piece, sq: int) {
	sq_bb := sq_to_bb(sq)
	pos.bb[p.color][p.piecetype] |= sq_bb
	pos.occupied[p.color] |= sq_bb
	pos.board[sq] = p

	pos.phase += PHASE_WEIGHT[p.piecetype]
	pos.psqt_mid[p.color] += psqt_value_mid(p, sq)
	pos.psqt_end[p.color] += psqt_value_end(p, sq)

	pos.hash ~= zobrist.piece[p.color][p.piecetype][sq]
}

remove_piece :: proc(pos: ^GamePosition, sq: int) -> Piece {
	p := pos.board[sq].? or_else panic("remove_piece on empty square")
	sq_bb := sq_to_bb(sq)
	pos.bb[p.color][p.piecetype] &~= sq_bb
	pos.occupied[p.color] &~= sq_bb
	pos.board[sq] = nil

	pos.phase -= PHASE_WEIGHT[p.piecetype]
	pos.psqt_mid[p.color] -= psqt_value_mid(p, sq)
	pos.psqt_end[p.color] -= psqt_value_end(p, sq)

	pos.hash ~= zobrist.piece[p.color][p.piecetype][sq]

	return p
}

move_piece :: proc(pos: ^GamePosition, from: int, to: int) {
	put_piece(pos, remove_piece(pos, from), to)
}

//sq runs from 0 to 63 and rank, file go from 0 to 7
sq_to_rank_file :: #force_inline proc "contextless" (sq: int) -> (int, int) {
	return (sq / 8), (sq % 8)
}

rank_file_to_sq :: #force_inline proc "contextless" (rank: int, file: int) -> int {
	return 8 * rank + file
}

display_position :: proc(position: GamePosition) {
	for rank := 7; rank >= 0; rank -= 1 {
		for file in 0 ..< 8 {
			if p, ok := position.board[rank_file_to_sq(rank, file)].?; ok {
				fmt.print(rune(piece_to_char(p)))
			} else {
				fmt.print('.')
			}
		}
		fmt.print("\n")
	}
}

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

gen_newgame :: proc() -> GamePosition {
	pos := process_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

	return pos
}

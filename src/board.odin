package main

import "core:fmt"
import "base:runtime"
import "base:intrinsics"

BitBoard :: distinct u64

RANK_1: BitBoard : 0x00000000000000FF
RANK_2: BitBoard : 0x000000000000FF00
RANK_3: BitBoard : 0x0000000000FF0000
RANK_4: BitBoard : 0x00000000FF000000
RANK_5: BitBoard : 0x000000FF00000000
RANK_6: BitBoard : 0x0000FF0000000000
RANK_7: BitBoard : 0x00FF000000000000
RANK_8: BitBoard : 0xFF00000000000000

FILE_A: BitBoard : 0x0101010101010101
FILE_B: BitBoard : 0x0202020202020202
FILE_C: BitBoard : 0x0404040404040404
FILE_D: BitBoard : 0x0808080808080808
FILE_E: BitBoard : 0x1010101010101010
FILE_F: BitBoard : 0x2020202020202020
FILE_G: BitBoard : 0x4040404040404040
FILE_H: BitBoard : 0x8080808080808080

EDGE: BitBoard : RANK_1 | RANK_8 | FILE_A | FILE_H

A1: BitBoard : 1 << 0
B1: BitBoard : 1 << 1
C1: BitBoard : 1 << 2
D1: BitBoard : 1 << 3
E1: BitBoard : 1 << 4
F1: BitBoard : 1 << 5
G1: BitBoard : 1 << 6
H1: BitBoard : 1 << 7
A2: BitBoard : 1 << 8
B2: BitBoard : 1 << 9
C2: BitBoard : 1 << 10
D2: BitBoard : 1 << 11
E2: BitBoard : 1 << 12
F2: BitBoard : 1 << 13
G2: BitBoard : 1 << 14
H2: BitBoard : 1 << 15
A3: BitBoard : 1 << 16
B3: BitBoard : 1 << 17
C3: BitBoard : 1 << 18
D3: BitBoard : 1 << 19
E3: BitBoard : 1 << 20
F3: BitBoard : 1 << 21
G3: BitBoard : 1 << 22
H3: BitBoard : 1 << 23
A4: BitBoard : 1 << 24
B4: BitBoard : 1 << 25
C4: BitBoard : 1 << 26
D4: BitBoard : 1 << 27
E4: BitBoard : 1 << 28
F4: BitBoard : 1 << 29
G4: BitBoard : 1 << 30
H4: BitBoard : 1 << 31
A5: BitBoard : 1 << 32
B5: BitBoard : 1 << 33
C5: BitBoard : 1 << 34
D5: BitBoard : 1 << 35
E5: BitBoard : 1 << 36
F5: BitBoard : 1 << 37
G5: BitBoard : 1 << 38
H5: BitBoard : 1 << 39
A6: BitBoard : 1 << 40
B6: BitBoard : 1 << 41
C6: BitBoard : 1 << 42
D6: BitBoard : 1 << 43
E6: BitBoard : 1 << 44
F6: BitBoard : 1 << 45
G6: BitBoard : 1 << 46
H6: BitBoard : 1 << 47
A7: BitBoard : 1 << 48
B7: BitBoard : 1 << 49
C7: BitBoard : 1 << 50
D7: BitBoard : 1 << 51
E7: BitBoard : 1 << 52
F7: BitBoard : 1 << 53
G7: BitBoard : 1 << 54
H7: BitBoard : 1 << 55
A8: BitBoard : 1 << 56
B8: BitBoard : 1 << 57
C8: BitBoard : 1 << 58
D8: BitBoard : 1 << 59
E8: BitBoard : 1 << 60
F8: BitBoard : 1 << 61
G8: BitBoard : 1 << 62
H8: BitBoard : 1 << 63

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
	material:   [Color]int, // sum of piece values per side
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

Zobrist :: struct {
	piece :   [Color][PieceType][64]u64,
	// castle :  [16]u64,
	castle :  [Castling]u64,
	ep_file : [8]u64,
	side :    u64,
}

zobrist : Zobrist

splitmix64 :: proc(state: ^u64) -> u64 {
    state^ += 0x9E3779B97F4A7C15
    z := state^
    z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ~ (z >> 27)) * 0x94D049BB133111EB
    return z ~ (z >> 31)
}

@(init)
init_zobrist :: proc "contextless" () {
	context = runtime.default_context()
	seed: u64 = 0x1234_5678_9ABC_DEF0

    // for p in do for sq in 0..<64 do z.pieces[p][sq] = splitmix64(&seed)
	for &by_type in zobrist.piece {
		for &squares in by_type {
			for &key in squares {
				key = splitmix64(&seed)
			}
		}
	}

    zobrist.side = splitmix64(&seed)
    
	for &key in zobrist.castle do key = splitmix64(&seed)

	for f in 0..<8 do zobrist.ep_file[f]  = splitmix64(&seed)
}

compute_hash :: proc(pos: ^GamePosition) -> u64 {
	h: u64 = 0

	// Pieces
	for color in Color {
		for pt in PieceType {
			bb := pos.bb[color][pt]
			for bb != 0 {
				sq := intrinsics.count_trailing_zeros(bb)
				h ~= zobrist.piece[color][pt][sq]
				bb &= bb - 1
			}
		}
	}
	
	// Side to move
	if pos.turn == .Black do h ~= zobrist.side

	// Castling
	for right in Castling {
		if right in pos.castling do h ~= zobrist.castle[right]
	}

	// En passant
	if pos.en_passant >= 0 do h ~=zobrist.ep_file[pos.en_passant % 8]

	return h
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

	pos.material[p.color] += PIECE_VALUE[p.piecetype]
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

	pos.material[p.color] -= PIECE_VALUE[p.piecetype]
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
sq_to_rank_file :: proc(sq: int) -> (int, int) {
	//return (sq-1) / 8 + 1, (sq-1) % 8 + 1
	return (sq / 8), (sq % 8)
}

rank_file_to_bb :: proc(rank: int, file: int) -> BitBoard {
	sq: int = rank_file_to_sq(rank, file)
	return BitBoard(1) << uint(sq)
}

rank_file_to_sq :: proc(rank: int, file: int) -> int {
	//return (rank-1)*8 + file
	return 8 * rank + file
}

sq_to_bb :: #force_inline proc(sq: int) -> BitBoard {
	return BitBoard(1) << uint(sq)
}

mirror_sq :: proc(sq: int) -> int {
	rank, file: int
	rank, file = sq_to_rank_file(sq)
	rank = 7 - rank
	return rank_file_to_sq(rank, file)
}

display_bitboard :: proc(bitboard: BitBoard) {
	shift: uint
	mask: BitBoard

	for i in 0 ..< 8 {
		for j in 0 ..< 8 {
			shift = uint((7 - i) * 8 + j)
			mask = BitBoard(1) << shift
			if (bitboard & mask) > 0 {
				fmt.print("1")
			} else {
				fmt.print("0")
			}
		}
		fmt.print("\n")
	}
	fmt.print("\n")
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

gen_newgame :: proc() -> GamePosition {
	pos := process_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

	return pos
}

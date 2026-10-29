package main

import "core:math/bits"
import "base:runtime"

// As minimal of info as possible to construct implement move
Move :: struct {
	pos_init:   int,
	pos_final:  int,
	piece:      Piece,
	is_capture: bool,
	promotion:  PieceType, // .Pawn means the move is not a promotion
}

// Structure to hold info needed to undo move. Constructed when
// initial move is done.
MoveInfo :: struct {
	is_capture:    bool,
	is_en_passant: bool,
	is_castle:     bool,
	capture:       Piece,
	castling:      bit_set[Castling],
	en_passant:    int,
	halfmove:      int,
	hash:          u64,
}

MoveList :: struct {
	moves : [256]Move,
	scores : [256]int,
	n : int,
}

NULL_MOVE :: Move{}

NullMoveInfo :: struct {
	en_passant: int,
	halfmove: int,
	hash: u64,
}

knight_moves: [64]BitBoard
king_moves: [64]BitBoard

//Attack lookup tables are pure global state shared by the engine and every
//test, so they are built once at startup
@(init)
init_attack_tables_startup :: proc "contextless" () {
	context = runtime.default_context()
	init_knight_moves()
	init_king_moves()
}

init_knight_moves :: proc() {
	pi: BitBoard
	pos_moves: BitBoard

	//left_side : BitBoard = 1085102592571150095
	//right_side : BitBoard = 17361641481138401520
	//left_two : BitBoard = 217020518514230019
	//right_two : BitBoard = 13889313184910721216

	left_side: BitBoard : FILE_A | FILE_B | FILE_C | FILE_D
	right_side: BitBoard : FILE_E | FILE_F | FILE_G | FILE_H
	left_two: BitBoard : FILE_A | FILE_B
	right_two: BitBoard : FILE_G | FILE_H

	for i in 0 ..< 64 {
		pi = BitBoard(1) << uint(i)
		pos_moves = (pi << 6) | (pi << 10) | (pi << 15) | (pi << 17)
		pos_moves = pos_moves | (pi >> 6) | (pi >> 10) | (pi >> 15) | (pi >> 17)

		if (pi & left_two != 0) {pos_moves = pos_moves & left_side}
		if (pi & right_two != 0) {pos_moves = pos_moves & right_side}

		knight_moves[i] = pos_moves
	}
}

init_king_moves :: proc() {
	pi: BitBoard
	pos_moves: BitBoard

	//left_side : BitBoard = 1085102592571150095
	//right_side : BitBoard = 17361641481138401520
	//left_one : BitBoard = 72340172838076673
	//right_one : BitBoard = 9259542123273814144

	left_side: BitBoard : FILE_A | FILE_B | FILE_C | FILE_D
	right_side: BitBoard : FILE_E | FILE_F | FILE_G | FILE_H

	for i in 0 ..< 64 {
		pi = BitBoard(1) << uint(i)

		pos_moves = (pi << 1) | (pi << 7) | (pi << 8) | (pi << 9)
		pos_moves = pos_moves | (pi >> 1) | (pi >> 7) | (pi >> 8) | (pi >> 9)

		if (pi & FILE_A != 0) {pos_moves = pos_moves & left_side}
		if (pi & FILE_H != 0) {pos_moves = pos_moves & right_side}

		king_moves[i] = pos_moves
	}
}

//Use computation to determine slider moves
init_slider_move :: proc(sq: int, occupied: BitBoard, is_rook: bool) -> BitBoard {
	rank, file, rank_i, file_i: int
	output: BitBoard = 0
	bb_tmp: BitBoard

	rf_max :: 7
	rf_min :: 0

	delta_rook := matrix[2, 2]int{
		0, 1,
		1, 0,
	}
	delta_bishop := matrix[2, 2]int{
		1, 1,
		1, -1,
	}

	delta: matrix[2, 2]int
	if is_rook {
		delta = delta_rook
	} else {
		delta = delta_bishop
	}

	rank_i, file_i = sq_to_rank_file(sq)

	//Maybe a second loop to get rid of copied code
	for i in 0 ..= 1 {
		rank = rank_i
		file = file_i
		for {
			rank += delta[i, 0]
			file += delta[i, 1]
			if (rank > rf_max) || (rank < rf_min) || (file > rf_max) || (file < rf_min) do break
			bb_tmp = rank_file_to_bb(rank, file)
			output |= bb_tmp
			if (bb_tmp & occupied) != 0 do break
		}

		rank = rank_i
		file = file_i
		for {
			rank -= delta[i, 0]
			file -= delta[i, 1]
			if (rank > rf_max) || (rank < rf_min) || (file > rf_max) || (file < rf_min) do break
			bb_tmp = rank_file_to_bb(rank, file)
			output |= bb_tmp
			if (bb_tmp & occupied) != 0 do break
		}
	}

	return output
}

//Magic table stuff is initialized in magics.odin. magic_index is always within
//the square's attack table by construction, so skip the bounds check
get_bishop_moves :: proc(sq: int, occupancy: BitBoard) -> BitBoard #no_bounds_check {
	m := &magic_bishop_table[sq]
	return m.attacks[magic_index(m, occupancy)]
}

get_rook_moves :: proc(sq: int, occupancy: BitBoard) -> BitBoard #no_bounds_check {
	m := &magic_rook_table[sq]
	return m.attacks[magic_index(m, occupancy)]
}

get_queen_moves :: proc(sq: int, occupancy: BitBoard) -> BitBoard {
	return get_bishop_moves(sq, occupancy) | get_rook_moves(sq, occupancy)
}

get_pawn_moves :: proc(
	sq: int,
	color: Color,
	my_pieces: BitBoard,
	opp_pieces: BitBoard,
	en_passant: int,
) -> (
	moves_bb:    BitBoard,
	captures_bb: BitBoard,
) {
	sq_bb := sq_to_bb(sq)

	occupancy := my_pieces | opp_pieces

	// Add the en passant square to the enemies bitboard for capture calculation.
	// Only do this when en passant is actually possible: when en_passant is -1
	// the shift in sq_to_bb would be undefined
	enemy := opp_pieces
	if en_passant >= 0 {
		enemy |= sq_to_bb(en_passant)
	}

	single_push, double_push, cap_left, cap_right: BitBoard
	if color == .White {
		single_push = (sq_bb << 8) & ~occupancy
		double_push = ((single_push & RANK_3) << 8) & ~occupancy
		cap_left = (sq_bb << 7) & enemy & ~FILE_H
		cap_right = (sq_bb << 9) & enemy & ~FILE_A
	} else {
		single_push = (sq_bb >> 8) & ~occupancy
		double_push = ((single_push & RANK_6) >> 8) & ~occupancy
		cap_left = (sq_bb >> 9) & enemy & ~FILE_H
		cap_right = (sq_bb >> 7) & enemy & ~FILE_A
	}

	moves_bb = single_push | double_push
	captures_bb = cap_left | cap_right

	return moves_bb, captures_bb
}

gen_moves :: proc(position: ^GamePosition, move_list: ^MoveList) {
	// This is better than the separate procedures because we only
	// have to loop over a single bitboard
	move_list.n = 0

	us := position.turn
	own := position.occupied[us]
	enemy := position.occupied[opp_color(us)]
	occupancy := own | enemy

	for pt in PieceType {
		pieces := position.bb[us][pt]
		for pieces != 0 {
			sq := pop_first_bit(&pieces)

			moves_bb, captures_bb: BitBoard
			if pt == .Pawn {
				moves_bb, captures_bb = get_pawn_moves(sq, us, own, enemy, position.en_passant)
			} else {
				targets: BitBoard
				#partial switch pt {
				case .Knight:
					targets = knight_moves[sq]
				case .Bishop:
					targets = get_bishop_moves(sq, occupancy)
				case .Rook:
					targets = get_rook_moves(sq, occupancy)
				case .Queen:
					targets = get_queen_moves(sq, occupancy)
				case .King:
					targets = king_moves[sq]
				}
				targets &~= own
				captures_bb = targets & enemy
				moves_bb = targets &~ enemy
			}

			bb_to_moves(move_list, sq, Piece{pt, us}, moves_bb, captures_bb)
		}
	}

	gen_castle_move(move_list, position)

	// Scores are left unset; callers that need ordering score the list
	// themselves (see movepick.odin)
}

//Returns the castling rights that are lost when a move touches sq,
//either as its origin or destination square
castle_rights_mask :: proc(sq: int) -> bit_set[Castling] {
	switch sq {
	case idx_A1:
		return {.WHITEQUEENSIDE}
	case idx_E1:
		return {.WHITEKINGSIDE, .WHITEQUEENSIDE}
	case idx_H1:
		return {.WHITEKINGSIDE}
	case idx_A8:
		return {.BLACKQUEENSIDE}
	case idx_E8:
		return {.BLACKKINGSIDE, .BLACKQUEENSIDE}
	case idx_H8:
		return {.BLACKKINGSIDE}
	}

	return {}
}

gen_castle_move :: proc(move_list: ^MoveList, position: ^GamePosition) {
	color := position.turn
	them := opp_color(color)
	king_sq := color == .White ? idx_E1 : idx_E8
	rank_offset := color == .White ? 0 : 56

	// Can't castle while in check
	if is_square_attacked(king_sq, them, position) do return

	occupancy := all_occupied(position)

	// O-O: f and g files must be empty, and the king can't pass through or
	// land on an attacked square
	if (color == .White && .WHITEKINGSIDE in position.castling) ||
	   (color == .Black && .BLACKKINGSIDE in position.castling) {
		f_sq := rank_offset + 5
		g_sq := rank_offset + 6
		if (occupancy & (sq_to_bb(f_sq) | sq_to_bb(g_sq))) == 0 &&
		   !is_square_attacked(f_sq, them, position) &&
		   !is_square_attacked(g_sq, them, position) {
			add_move_to_list(move_list, Move{king_sq, g_sq, Piece{.King, color}, false, .Pawn})
		}
	}

	// O-O-O: b, c and d files must be empty, and the king can't pass through
	// d or land on c on an attacked square (b1 may be attacked)
	if (color == .White && .WHITEQUEENSIDE in position.castling) ||
	   (color == .Black && .BLACKQUEENSIDE in position.castling) {
		b_sq := rank_offset + 1
		c_sq := rank_offset + 2
		d_sq := rank_offset + 3
		if (occupancy & (sq_to_bb(b_sq) | sq_to_bb(c_sq) | sq_to_bb(d_sq))) == 0 &&
		   !is_square_attacked(d_sq, them, position) &&
		   !is_square_attacked(c_sq, them, position) {
			add_move_to_list(move_list, Move{king_sq, c_sq, Piece{.King, color}, false, .Pawn})
		}
	}
}

//Checks to see if the square sq is attacked by any pieces of by_color
is_square_attacked :: proc(sq: int, by_color: Color, position: ^GamePosition) -> bool {
	opp_bb := &position.bb[by_color]

	// 1. Knight attacks
	if (knight_moves[sq] & opp_bb[.Knight]) != 0 do return true

	// 2. King attacks (prevents moving the king next to the opponent king)
	if (king_moves[sq] & opp_bb[.King]) != 0 do return true

	// 3. Pawn attacks
	rank, file := sq_to_rank_file(sq)
	if by_color == .White {
		// White pawns attack sq from below (e.g from sq-9 and sq-7)
		if file != 0 && rank >= 1 {
			if (opp_bb[.Pawn] & sq_to_bb(sq - 9)) != 0 do return true
		}
		if file != 7 && rank >= 1 {
			if (opp_bb[.Pawn] & sq_to_bb(sq - 7)) != 0 do return true
		}
	} else {
		//Black pawns attack sq from above (e.g from sq+7 and sq+9)
		if file != 0 && rank <= 6 {
			if (opp_bb[.Pawn] & sq_to_bb(sq + 7)) != 0 do return true
		}
		if file != 7 && rank <= 6 {
			if (opp_bb[.Pawn] & sq_to_bb(sq + 9)) != 0 do return true
		}
	}

	// 4. Sliding piece attacks (using magic bitboard lookups)
	occupied := all_occupied(position)

	// Bishops and Queens
	bishop_attacks := get_bishop_moves(sq, occupied)
	if (bishop_attacks & (opp_bb[.Bishop] | opp_bb[.Queen])) != 0 do return true

	// Rooks and Queens
	rook_attacks := get_rook_moves(sq, occupied)
	if (rook_attacks & (opp_bb[.Rook] | opp_bb[.Queen])) != 0 do return true

	return false
}

// To determine check, see whether the king's square is attacked by a piece of the opposing color
is_in_check :: proc(color: Color, position: ^GamePosition) -> bool {
	king_bb := position.bb[color][.King]

	// Handle custom setups with no king (e.q. tests)
	if king_bb == 0 do return false

	king_sq := bits.count_trailing_zeros(u64(king_bb))

	return is_square_attacked(int(king_sq), opp_color(color), position)
}

// If we are in check and we are still in check after all possible generated
// moves, then it is checkmate
is_checkmate :: proc(position: ^GamePosition) -> bool {

	color := position.turn
	if !is_in_check(color, position) do return false

	movelist: MoveList = ---
	gen_moves(position, &movelist)

	for i in 0..<movelist.n {
		move := movelist.moves[i]
		mi := apply_move_inplace(move, position)
		legal := !is_in_check(color, position)
		undo_move_inplace(move, mi, position)
		if legal do return false
	}

	return true
}

add_move_to_list :: proc(ml: ^MoveList, m: Move) {
	ml.moves[ml.n] = m
	ml.n += 1
}

// Move captures to the front of the list and return the number of captures
partition_captures_first :: proc(ml: ^MoveList) -> int {
	ncap := 0
	for i in 0..<ml.n {
		// If it is a capture swap with earliest element in list that is
		// not a capture
		if ml.moves[i].is_capture {
			ml.moves[ncap], ml.moves[i] = ml.moves[i], ml.moves[ncap]
			ncap += 1
		}
	}

	return ncap
}

bb_to_moves :: proc(
	move_list: ^MoveList,
	sq: int,
	piece: Piece,
	moves_bb: BitBoard,
	captures_bb: BitBoard,
) {

	if piece.piecetype == .Pawn {
		bb_to_pawn_moves(move_list, sq, piece, moves_bb, captures_bb)
		return
	}

	bb_tmp: BitBoard
	sq_fin: int
	move: Move

	bb_tmp = moves_bb
	for bb_tmp != 0 {
		sq_fin = pop_first_bit(&bb_tmp) // + 1
		move = Move{sq, sq_fin, piece, false, .Pawn}
		add_move_to_list(move_list, move)
	}

	bb_tmp = captures_bb
	for bb_tmp != 0 {
		sq_fin = pop_first_bit(&bb_tmp) // + 1
		move = Move{sq, sq_fin, piece, true, .Pawn}
		add_move_to_list(move_list, move)
	}

}

//Convert pawn move/capture bitboards into Move structs. Promotion squares
//expand into one move per promotion piece (Q, R, B, N)
bb_to_pawn_moves :: proc(
	move_list: ^MoveList,
	sq: int,
	piece: Piece,
	moves_bb: BitBoard,
	captures_bb: BitBoard,
) {
	bb_tmp: BitBoard
	sq_fin: int

	promotion_pieces := [4]PieceType{.Queen, .Rook, .Bishop, .Knight}

	bb_tmp = moves_bb
	for bb_tmp != 0 {
		sq_fin = pop_first_bit(&bb_tmp)
		if sq_fin < 8 || sq_fin >= 56 {
			for promo in promotion_pieces {
				move := Move{sq, sq_fin, piece, false, promo}
				add_move_to_list(move_list, move)
			}
		} else {
			move := Move{sq, sq_fin, piece, false, .Pawn}
			add_move_to_list(move_list, move)
		}
	}

	bb_tmp = captures_bb
	for bb_tmp != 0 {
		sq_fin = pop_first_bit(&bb_tmp)
		if sq_fin < 8 || sq_fin >= 56 {
			for promo in promotion_pieces {
				move := Move{sq, sq_fin, piece, true, promo}
				add_move_to_list(move_list, move)
			}
		} else {
			move := Move{sq, sq_fin, piece, true, .Pawn}
			add_move_to_list(move_list, move)
		}
	}
}

apply_null_move :: proc(pos: ^GamePosition) -> NullMoveInfo {
	info := NullMoveInfo{pos.en_passant, pos.halfmove, pos.hash}

	pos.turn = opp_color(pos.turn)
	pos.hash ~= zobrist.side

	if pos.en_passant != -1 {
		pos.hash ~= zobrist.ep_file[pos.en_passant % 8]
		pos.en_passant = -1
	}

	// No repetition can span a null move, so stop the repetition scan here
	pos.halfmove = 0

	return info
}

undo_null_move :: proc(info: NullMoveInfo, pos: ^GamePosition) {
	pos.turn = opp_color(pos.turn)
	pos.en_passant = info.en_passant
	pos.halfmove = info.halfmove
	pos.hash = info.hash
}

//In place modifications are probably faster since memory doesn't
//need to be allocated
apply_move_inplace :: proc(move: Move, position: ^GamePosition) -> MoveInfo {
	us := move.piece.color

	info: MoveInfo
	info.castling = position.castling
	info.en_passant = position.en_passant
	info.halfmove = position.halfmove
	info.hash = position.hash

	position.turn = opp_color(us)
	if us == .Black do position.movenum += 1
	position.hash ~= zobrist.side

	// En passant is only valid on the move immediately after a double push
	if position.en_passant != -1 {
		// Remove the previous en_passant file
		position.hash ~= zobrist.ep_file[position.en_passant % 8]
	}
	position.en_passant = -1
	position.halfmove += 1

	// En passant capture: a pawn moving diagonally to an empty square
	capture_sq := move.pos_final
	if move.piece.piecetype == .Pawn && position.board[move.pos_final] == nil &&
	   move.pos_init % 8 != move.pos_final % 8 {
		info.is_en_passant = true
		capture_sq = ep_captured_square(move)
	}

	// Remove any captured piece
	if position.board[capture_sq] != nil {
		position.halfmove = 0
		info.is_capture = true
		info.capture = remove_piece(position, capture_sq)
	}

	if move.promotion != .Pawn {
		remove_piece(position, move.pos_init)
		put_piece(position, Piece{move.promotion, us}, move.pos_final)
	} else {
		move_piece(position, move.pos_init, move.pos_final)
	}

	if move.piece.piecetype == .Pawn {
		position.halfmove = 0
		// Double push makes the skipped square available for en passant
		if abs(move.pos_final - move.pos_init) == 16 {
			position.en_passant = (move.pos_init + move.pos_final) / 2
			position.hash ~= zobrist.ep_file[position.en_passant % 8]
		}
	}

	// Castling: the king moving two files also moves the rook
	if move.piece.piecetype == .King && abs(move.pos_final - move.pos_init) == 2 {
		rook_from, rook_to := castle_rook_squares(move)
		move_piece(position, rook_from, rook_to)
		info.is_castle = true
	}

	// Revoke castling rights for the squares touched by this move
	old_rights := position.castling
	position.castling -= castle_rights_mask(move.pos_init)
	position.castling -= castle_rights_mask(move.pos_final)
	changed := old_rights - position.castling
	for right in Castling {
		if right in changed do position.hash ~= zobrist.castle[right]
	}

	return info
}

// Applies a pseudo-legal move. If it leaves our king in check, it is undone
// and legal is false; otherwise the caller must undo it with the returned info
try_move :: #force_inline proc(move: Move, position: ^GamePosition) -> (info: MoveInfo, legal: bool) {
	info = apply_move_inplace(move, position)
	if is_in_check(move.piece.color, position) {
		undo_move_inplace(move, info, position)
		return info, false
	}
	return info, true
}

// Rook origin and destination squares for a castling king move
castle_rook_squares :: proc(move: Move) -> (rook_from: int, rook_to: int) {
	if move.pos_final > move.pos_init {
		return move.pos_final + 1, move.pos_final - 1
	}
	return move.pos_final - 2, move.pos_final + 1
}

// Init/final position and promotion value are enough to determine
// whether two moves are the same
move_equal :: proc(a, b: Move) -> bool {
	if a.pos_final != b.pos_final do return false
	if a.pos_init != b.pos_init do return false

	if a.promotion != b.promotion do return false

	return true
}

ep_captured_square :: #force_inline proc(move: Move) -> int {
	return move.pos_final + (move.piece.color == .White ? -8 : 8)
}

undo_move_inplace :: proc(move: Move, info: MoveInfo, position: ^GamePosition) {
	us := move.piece.color

	position.turn = us
	if us == .Black do position.movenum -= 1

	// Restore previous en_passant and castling values
	position.en_passant = info.en_passant
	position.castling = info.castling
	position.halfmove = info.halfmove

	// Castling: move the rook back
	if info.is_castle {
		rook_from, rook_to := castle_rook_squares(move)
		move_piece(position, rook_to, rook_from)
	}

	// Remove the promoted piece, the pawn goes back to its origin square
	if move.promotion != .Pawn {
		remove_piece(position, move.pos_final)
		put_piece(position, move.piece, move.pos_init)
	} else {
		move_piece(position, move.pos_final, move.pos_init)
	}

	// The en passant captured pawn sits next to pos_final, not on it
	if info.is_capture {
		capture_sq := info.is_en_passant ? ep_captured_square(move) : move.pos_final
		put_piece(position, info.capture, capture_sq)
	}

	// Restore hash last because put_piece/move_piece updates it
	position.hash = info.hash
}

pack_move :: proc(move: Move) -> u16 {
	// from | to<<6 | promo<<12 (0 = none)

	from : u16 = auto_cast move.pos_init
	to : u16 = auto_cast move.pos_final

	promo : u16 = auto_cast move.promotion

	return from | to<<6 | promo<< 12
}


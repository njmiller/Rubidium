package main

import "core:container/queue"
import "core:fmt"
import "core:math/bits"

// As minimal of info as possible to construct implement move
Move :: struct {
	pos_init:   int,
	pos_final:  int,
	piece:      Piece,
	is_capture: bool,
	// promotion:  PieceType,
}

// Structure to hold info needed to undo move. Constructed when
// initial move is done.
MoveInfo :: struct {
	is_capture: bool,
	capture:    Piece,
	// castle:     bit_set[0 ..< 4],
	castling:   bit_set[Castling],
	en_passant: int,
	halfmove:   int,
}

knight_moves: [64]BitBoard
king_moves: [64]BitBoard

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
	i: int
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

//Magic table stuff is initialized in magics.odin
get_bishop_moves :: proc(sq: int, occupancy: BitBoard) -> BitBoard {
	hash: u64
	hash = u64(occupancy & magic_bishop_table[sq].mask)
	hash *= magic_bishop_table[sq].magic
	hash >>= uint(64 - magic_bishop_table[sq].shift)
	return magic_bishop_table[sq].attacks[hash]
}

get_rook_moves :: proc(sq: int, occupancy: BitBoard) -> BitBoard {
	hash: u64
	hash = u64(occupancy & magic_rook_table[sq].mask)
	hash *= magic_rook_table[sq].magic
	hash >>= uint(64 - magic_rook_table[sq].shift)
	return magic_rook_table[sq].attacks[hash]
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
	moves_bb: BitBoard,
	captures_bb: BitBoard,
	ep_sq: int, // promotions_bb: BitBoard,
) {
	rank, file := sq_to_rank_file(sq)
	sq_bb := sq_to_bb(sq)

	direction: int
	pos_mov_bb: BitBoard
	rank_end, file_end: int
	move_one: bool

	occupancy := my_pieces | opp_pieces

	// Add the en passant square to the enemies bitboard for capture calculation
	ep_sq_bb: BitBoard = sq_to_bb(en_passant)
	enemy := opp_pieces | ep_sq_bb

	moves_bb = 0
	captures_bb = 0


	single_push, double_push, cap_left, cap_right: BitBoard = 0, 0, 0, 0
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

	if double_push != 0 {
		if color == .White {
			ep_sq = sq + 8
		} else {
			ep_sq = sq - 8
		}
	} else do ep_sq = -1

	moves_bb = single_push | double_push
	captures_bb = cap_left | cap_right

	return moves_bb, captures_bb, ep_sq
}

gen_moves :: proc(position: ^GamePosition) -> ^queue.Queue(Move) {
	//This is better than the separate procedures because we only have to loop over a single bitboard
	// moves: queue.Queue(Move)
	moves := new(queue.Queue(Move))
	queue.init(moves)

	pos_bb, moves_bb, captures_bb: BitBoard
	piece: Piece
	color: Color = position.turn

	/*
    if color == .White {
        my_pos = position.White
        opp_pos = position.Black
    } else if color == .Black {
        my_pos = position.Black
        opp_pos = position.White
    }
    */

	my_pos, opp_pos: ^PositionOneColor
	switch color {
	case .White:
		my_pos = &position.white
		opp_pos = &position.black
	case .Black:
		my_pos = &position.black
		opp_pos = &position.white
	}

	//TODO: Maybe do pop_first_bit for quicker move generation. Would need to time it
	//to see if it is faster
	for sq in 0 ..< 64 {
		pos_bb = BitBoard(1) << uint(sq)
		switch {
		case (pos_bb & position.white.Pawns) != 0 && (color == .White):
			// fmt.println("TEST")
			ep_sq: int
			moves_bb, captures_bb, ep_sq = get_pawn_moves(
				sq,
				color,
				my_pos.AllPieces,
				opp_pos.AllPieces,
				position.en_passant,
			)

			piece = Piece{PieceType.Pawn, color}
		case (pos_bb & my_pos.Knights) != 0:
			piece = Piece{PieceType.Knight, color}
			moves_bb = knight_moves[sq] & ~my_pos.AllPieces
			captures_bb = knight_moves[sq] & opp_pos.AllPieces
		case (pos_bb & my_pos.Rooks) != 0:
			piece = Piece{PieceType.Rook, color}
			moves_bb = get_rook_moves(sq, my_pos.AllPieces | opp_pos.AllPieces) & ~my_pos.AllPieces
			captures_bb = moves_bb & opp_pos.AllPieces
			moves_bb = moves_bb & ~captures_bb
		case (pos_bb & my_pos.Bishops) != 0:
			piece = Piece{PieceType.Bishop, color}
			moves_bb =
				get_bishop_moves(sq, my_pos.AllPieces | opp_pos.AllPieces) & ~my_pos.AllPieces
			captures_bb = moves_bb & opp_pos.AllPieces
			moves_bb = moves_bb & ~captures_bb
		case (pos_bb & my_pos.Queens) != 0:
			piece = Piece{PieceType.Queen, color}
			moves_bb =
				get_queen_moves(sq, my_pos.AllPieces | opp_pos.AllPieces) & ~my_pos.AllPieces
			captures_bb = moves_bb & opp_pos.AllPieces
			moves_bb = moves_bb & ~captures_bb
		case (pos_bb & my_pos.King) != 0:
			piece = Piece{PieceType.King, color}
			moves_bb = king_moves[sq] & ~my_pos.AllPieces
			captures_bb = king_moves[sq] & opp_pos.AllPieces
		}
		bb_to_moves(moves, sq, piece, moves_bb, captures_bb)
	}

	check_castle: bool = true
	if check_castle do gen_castle_move(moves, color, my_pos, opp_pos)

	return moves

}

//Free a moves queue
free_moves :: proc(moves: ^queue.Queue(Move)) {
	queue.destroy(moves)
	free(moves)
}

gen_castle_move :: proc(
	moves: ^queue.Queue(Move),
	color: Color,
	my_pos: ^PositionOneColor,
	opp_pos: ^PositionOneColor,
) {

	//O-O
	if color == .White {

	}
	//O-O-O
}

//Checks to see if the square sq is attacked by any pieces of by_color
is_square_attacked :: proc(sq: int, by_color: Color, position: ^GamePosition) -> bool {
	opp_pos := by_color == .White ? &position.white : &position.black

	// 1. Knight attacks
	if (knight_moves[sq] & opp_pos.Knights) != 0 do return true

	// 2. King attacks (prevents moving the king next to the opponent king)
	if (king_moves[sq] & opp_pos.King) != 0 do return true

	// 3. Pawn attacks
	rank, file := sq_to_rank_file(sq)
	if by_color == .White {
		// White pawns attack sq from below (e.g from sq-9 and sq-7)
		if file != 0 && rank >= 1 {
			if (opp_pos.Pawns & sq_to_bb(sq - 9)) != 0 do return true
		}
		if file != 7 && rank >= 1 {
			if (opp_pos.Pawns & sq_to_bb(sq - 7)) != 0 do return true
		}
	} else {
		//Black pawns attack sq from above (e.g from sq+7 and sq+9)
		if file != 0 && rank <= 6 {
			if (opp_pos.Pawns & sq_to_bb(sq + 7)) != 0 do return true
		}
		if file != 7 && rank <= 6 {
			if (opp_pos.Pawns & sq_to_bb(sq + 9)) != 0 do return true
		}
	}

	// 4. Sliding piece attacks (using magic bitboard lookups)
	occupied := position.white.AllPieces | position.black.AllPieces

	// Bishops and Queens
	bishop_attacks := get_bishop_moves(sq, occupied)
	if (bishop_attacks & (opp_pos.Bishops | opp_pos.Queens)) != 0 do return true

	// Rooks and Queens
	rook_attacks := get_rook_moves(sq, occupied)
	if (rook_attacks & (opp_pos.Rooks | opp_pos.Queens)) != 0 do return true

	return false
}

// To determine check, see whether the king's square is attacked by a piece of the opposing color
is_in_check :: proc(color: Color, position: ^GamePosition) -> bool {
	king_bb := color == .White ? position.white.King : position.black.King

	// Handle custom setups with no king (e.q. tests)
	if king_bb == 0 do return false

	king_sq := bits.count_trailing_zeros(u64(king_bb))

	opp_color := color == .White ? Color.Black : Color.White

	return is_square_attacked(int(king_sq), opp_color, position)
}

bb_to_moves :: proc(
	moves: ^queue.Queue(Move),
	sq: int,
	piece: Piece,
	moves_bb: BitBoard,
	captures_bb: BitBoard,
) {

	if piece == .Pawn {
		bb_to_pawn_moves(moves, sq, moves_bb, captures_bb)
		return
	}

	bb_tmp: BitBoard
	sq_fin: int
	move: Move
	flags: bit_set[0 ..< 4] = {}

	bb_tmp = moves_bb
	for bb_tmp != 0 {
		sq_fin = pop_first_bit(&bb_tmp) // + 1
		move = Move{sq, sq_fin, piece, false}
		queue.push_back(moves, move)
	}

	bb_tmp = captures_bb
	for bb_tmp != 0 {
		sq_fin = pop_first_bit(&bb_tmp) // + 1
		move = Move{sq, sq_fin, piece, true}
		queue.push_front(moves, move)
	}

}

/*
apply_move :: proc(move: Move, position_in: GamePosition) -> (GamePosition, MoveInfo) {

	position_out := position_in
	info := apply_move_inplace(move, &position_out)

	return position_out, info
}
*/

//In place modifications are probably faster since memory doesn't
//need to be allocated
apply_move_inplace :: proc(move: Move, position: ^GamePosition) -> MoveInfo {

	sq_bb_init: BitBoard = BitBoard(1) << uint(move.pos_init)
	sq_bb_final: BitBoard = BitBoard(1) << uint(move.pos_final)

	info: MoveInfo
	info.castling = position.castling
	info.en_passant = position.en_passant
	info.halfmove = position.halfmove

	my_pos, opp_pos: ^PositionOneColor
	opp_color: Color
	switch move.piece.color {
	case .White:
		my_pos = &position.white
		opp_pos = &position.black
		opp_color = .Black
		position.turn = .Black
	case .Black:
		my_pos = &position.black
		opp_pos = &position.white
		opp_color = .White
		position.turn = .White
		position.movenum += 1
	}

	// pos_final: uint = auto_cast move.pos_final
	is_capture := (sq_bb_final & opp_pos.AllPieces) != 0
	// is_capture := move.is_capture

	switch move.piece.piecetype {
	case .Pawn:
		position.halfmove = 0
		my_pos.Pawns &~= sq_bb_init
		// Only doing queen promotion right now. Check is final position for pawn in
		// on the first or last rank
		if move.pos_final < 8 || move.pos_final >= 56 {
			my_pos.Queens |= sq_bb_final
		} else {
			my_pos.Pawns |= sq_bb_final
			// Check for en passant square
			if abs(move.pos_final - move.pos_init) == 16 {
				switch move.piece.color {
				case .White:
					position.en_passant = move.pos_init + 8
				case .Black:
					position.en_passant = move.pos_init - 8
				}
			} else {
				position.en_passant = -1
			}
		}
	case .Knight:
		position.halfmove += 1
		my_pos.Knights &~= sq_bb_init
		my_pos.Knights |= sq_bb_final
	case .Bishop:
		position.halfmove += 1
		my_pos.Bishops &~= sq_bb_init
		my_pos.Bishops |= sq_bb_final
	case .Rook:
		position.halfmove += 1
		my_pos.Rooks &~= sq_bb_init
		my_pos.Rooks |= sq_bb_final
	case .Queen:
		position.halfmove += 1
		my_pos.Queens &~= sq_bb_init
		my_pos.Queens |= sq_bb_final
	case .King:
		position.halfmove += 1
		my_pos.King &~= sq_bb_init
		my_pos.King |= sq_bb_final
	case .All:
		panic("Shouldn't have piece type as .All in move")
	}
	my_pos.AllPieces &~= sq_bb_init
	my_pos.AllPieces |= sq_bb_final

	info.is_capture = move.is_capture
	if move.is_capture {
		position.halfmove = 0
		if sq_bb_final & opp_pos.Pawns != 0 {
			opp_pos.Pawns &~= sq_bb_final
			info.capture = {.Pawn, opp_color}
		} else if sq_bb_final & opp_pos.Knights != 0 {
			opp_pos.Knights &~= sq_bb_final
			info.capture = {.Knight, opp_color}
		} else if sq_bb_final & opp_pos.Bishops != 0 {
			opp_pos.Bishops &~= sq_bb_final
			info.capture = {.Bishop, opp_color}
		} else if sq_bb_final & opp_pos.Rooks != 0 {
			opp_pos.Rooks &~= sq_bb_final
			info.capture = {.Rook, opp_color}
		} else if sq_bb_final & opp_pos.Queens != 0 {
			opp_pos.Queens &~= sq_bb_final
			info.capture = {.Queen, opp_color}
		}
		opp_pos.AllPieces &~= sq_bb_final
	}

	return info
}

/*
undo_move :: proc(move: Move, info: MoveInfo, position: GamePosition) -> GamePosition {
	position_tmp := position
	undo_move_inplace(move, info, &position_tmp)
	return position_tmp
}
*/

undo_move_inplace :: proc(move: Move, info: MoveInfo, position: ^GamePosition) {

	sq_bb_init: BitBoard = BitBoard(1) << uint(move.pos_init)
	sq_bb_final: BitBoard = BitBoard(1) << uint(move.pos_final)

	my_pos, opp_pos: ^PositionOneColor
	opp_color: Color
	switch move.piece.color {
	case .White:
		my_pos = &position.white
		opp_pos = &position.black
		opp_color = .Black
		position.turn = .White
	case .Black:
		my_pos = &position.black
		opp_pos = &position.white
		opp_color = .White
		position.turn = .Black
	}

	// Restore previous en_passant and castling values
	position.en_passant = info.en_passant
	position.castling = info.castling
	position.halfmove = info.halfmove

	switch move.piece.piecetype {
	case .Pawn:
		my_pos.Pawns &~= sq_bb_final
		my_pos.Pawns |= sq_bb_init
	case .Knight:
		my_pos.Knights &~= sq_bb_final
		my_pos.Knights |= sq_bb_init
	case .Bishop:
		my_pos.Bishops &~= sq_bb_final
		my_pos.Bishops |= sq_bb_init
	case .Rook:
		my_pos.Rooks &~= sq_bb_final
		my_pos.Rooks |= sq_bb_init
	case .Queen:
		my_pos.Queens &~= sq_bb_final
		my_pos.Queens |= sq_bb_init
	case .King:
		my_pos.King &~= sq_bb_final
		my_pos.King |= sq_bb_init
	case .All:
		panic("Shouldn't have piece type as .All in move")
	}
	my_pos.AllPieces &~= sq_bb_final
	my_pos.AllPieces |= sq_bb_init

	if info.is_capture {
		switch info.capture.piecetype {
		case .Pawn:
			opp_pos.Pawns |= sq_bb_final
		case .Knight:
			opp_pos.Knights |= sq_bb_final
		case .Bishop:
			opp_pos.Bishops |= sq_bb_final
		case .Rook:
			opp_pos.Rooks |= sq_bb_final
		case .Queen:
			opp_pos.Queens |= sq_bb_final
		case .King:
			opp_pos.King |= sq_bb_final
		case .All:
			panic("Should have piece type as .All in move")
		}
		opp_pos.AllPieces |= sq_bb_final
	}

}

perft :: proc(depth: int, position: ^GamePosition) -> u64 {
	if depth == 0 do return 1

	nodes: u64 = 0

	moves := gen_moves(position)
	defer free_moves(moves)

	for queue.len(moves^) > 0 {
		move := queue.pop_front(moves)
		info := apply_move_inplace(move, position)

		// if the move didn't leave our king in check, it is legal
		if !is_in_check(move.piece.color, position) do nodes += perft(depth - 1, position)

		undo_move_inplace(move, info, position)
	}

	return nodes
}

perft_divide :: proc(depth: int, position: ^GamePosition) -> u64 {
	if depth <= 0 do return 0

	total_nodes: u64 = 0
	display_position(position^)
	moves := gen_moves(position)
	defer free(moves)

	fmt.println("NMoves:", queue.len(moves^))

	fmt.printf("\n--- Perft Divide Depth %d ---\n", depth)
	for queue.len(moves^) > 0 {
		move := queue.pop_front(moves)
		info := apply_move_inplace(move, position)

		if !is_in_check(move.piece.color, position) {
			nodes := perft(depth - 1, position)
			total_nodes += nodes

			// Print move in UCI format (e.g. e2e4)
			init_file := 'a' + u8(move.pos_init % 8)
			init_rank := '1' + u8(move.pos_init / 8)

			final_file := 'a' + u8(move.pos_final % 8)
			final_rank := '1' + u8(move.pos_final / 8)

			fmt.printf("%c%c%c%c: %d ", init_file, init_rank, final_file, final_rank, nodes)
			fmt.println(move.piece.color, move.piece.piecetype)
		}

		undo_move_inplace(move, info, position)

	}

	fmt.printf("\nTotal leaf nodes: %d\n", total_nodes)

	return total_nodes
}

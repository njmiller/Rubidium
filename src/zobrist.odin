package main

import "base:runtime"
import "base:intrinsics"

Zobrist :: struct {
	piece :   [Color][PieceType][64]u64,
	// castle :  [16]u64,
	castle :  [Castling]u64,
	ep_file : [8]u64,
	side :    u64,
}

zobrist : Zobrist

splitmix64 :: proc "contextless" (state: ^u64) -> u64 {
    state^ += 0x9E3779B97F4A7C15
    z := state^
    z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ~ (z >> 27)) * 0x94D049BB133111EB
    return z ~ (z >> 31)
}

@(init)
init_zobrist :: proc "contextless" () {
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

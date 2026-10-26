package main

import "core:math/bits"
import "core:slice"

Bound :: enum u8 { None, Exact, Lower, Upper }

TTEntry :: struct {
    key: u64,
    move: u16,
    score: i16,
    depth: i8,
    bound: Bound,
    age: u8,
}

tt: []TTEntry
tt_mask: u64
tt_age: u8 // increment at the start of each search

tt_resize :: proc(mb: int) {
    size_tte := size_of(TTEntry)
    
    total_bytes := mb * 1024 * 1024

    n : uint = auto_cast (total_bytes / size_tte)

    nbits : uint = auto_cast bits.len(n)

    ntte := 1 << (nbits - 1)

    delete(tt)
    tt = make([]TTEntry, ntte)
    tt_mask = u64(ntte - 1)
}

tt_clear :: proc() {
    slice.zero(tt)
}

// Searches for key.
tt_probe :: proc(key: u64) -> (^TTEntry, bool) {
    e := &tt[key & tt_mask]
    return e, e.key == key
}

tt_store :: proc(key: u64, move: Move, score: int, depth: int, bound: Bound, ply: int) {
    e := &tt[key & tt_mask]

    // Keep a deeper entry for a different position, unless its from an older search
    if e.key != key && e.age == tt_age && int(e.depth) > depth do return

    packed := pack_move(move)
    if packed == 0 && e.key == key do packed = e.move

    e^= TTEntry{key, packed, i16(score_to_tt(score, ply)), i8(depth), bound, tt_age}
}

pack_move :: proc(move: Move) -> u16 {
    // from | to<<6 | promo<<12 (0 = none)

    from : u16 = auto_cast move.pos_init
    to : u16 = auto_cast move.pos_final

    promo : u16 = auto_cast move.promotion

    return from | to<<6 | promo<< 12
}

score_to_tt :: proc(score: int, ply: int) -> int {
    if score > MATE - MAX_PLY do return score + ply
    if score < -(MATE - MAX_PLY) do return score - ply

    return score
}

score_from_tt :: proc(score: int, ply: int) -> int {
    if score > MATE - MAX_PLY do return score - ply
    if score < -(MATE - MAX_PLY) do return score + ply

    return score
}
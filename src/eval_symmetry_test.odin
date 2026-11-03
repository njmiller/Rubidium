package main

import "core:strings"
import "core:testing"

swap_case :: proc(c: u8) -> u8 {
    switch c {
    case 'a' ..= 'z': return c - 'a' + 'A'
    case 'A' ..= 'Z': return c - 'A' + 'a'
    }
    return c
}

// Returns the FEN with colors swapped and the board flipped vertically, so the
// side to move sees the same position from the other side of the board
mirror_fen :: proc(fen: string, allocator := context.allocator) -> string {
    fields := strings.fields(fen, context.temp_allocator)
    b := strings.builder_make(allocator)

    // FEN lists rank 8 first, so writing the ranks in reverse flips the board
    ranks := strings.split(fields[0], "/", context.temp_allocator)
    for i := len(ranks) - 1; i >= 0; i -= 1 {
        for j in 0 ..< len(ranks[i]) do strings.write_byte(&b, swap_case(ranks[i][j]))
        if i > 0 do strings.write_byte(&b, '/')
    }

    strings.write_byte(&b, ' ')
    strings.write_byte(&b, fields[1] == "w" ? 'b' : 'w')

    // Each right moves to the other color. Written in the usual KQkq order
    strings.write_byte(&b, ' ')
    if fields[2] == "-" {
        strings.write_byte(&b, '-')
    } else {
        for c in "KQkq" {
            if strings.index_byte(fields[2], swap_case(u8(c))) >= 0 do strings.write_byte(&b, u8(c))
        }
    }

    // En passant target keeps its file and moves between ranks 3 and 6
    strings.write_byte(&b, ' ')
    if fields[3] == "-" {
        strings.write_byte(&b, '-')
    } else {
        strings.write_byte(&b, fields[3][0])
        strings.write_byte(&b, fields[3][1] == '3' ? '6' : '3')
    }

    for i in 4 ..< len(fields) {
        strings.write_byte(&b, ' ')
        strings.write_string(&b, fields[i])
    }

    return strings.to_string(b)
}

@(test)
test_mirror_fen :: proc(t: ^testing.T) {
    m := mirror_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    defer delete(m)
    testing.expect_value(t, m, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")

    fen := "r3k2r/8/8/3pP3/8/8/8/R3K3 w Qk d6 0 2"
    m2 := mirror_fen(fen)
    defer delete(m2)
    testing.expect_value(t, m2, "r3k3/8/8/8/3Pp3/8/8/R3K2R b Kq d3 0 2")

    // Mirroring twice gives back the original
    m3 := mirror_fen(m2)
    defer delete(m3)
    testing.expect_value(t, m3, fen)
}

// The eval is from the side to move's point of view, so a position and its
// color-flipped mirror must score the same. Catches any eval term that treats
// the two colors differently
@(test)
test_eval_symmetry :: proc(t: ^testing.T) {
    fens := [?]string {
        // Start position and kiwipete
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        // Bishop pair for white only
        "4k3/pp3ppp/2n5/8/8/2B5/PP1B1PPP/4K3 w - - 0 1",
        // Rooks on open and semi-open files
        "3r2k1/p1p2ppp/8/8/8/8/PP3PPP/2R1R1K1 w - - 0 1",
        // Passed, isolated and doubled pawns
        "8/5k2/3p4/1P1P4/1P6/8/6K1/8 w - - 0 1",
        // En passant available
        "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3",
        // Queens in the endgame
        "6k1/5pp1/7p/8/3Q4/8/q4PPP/6K1 b - - 0 1",
        // CPW position 4
        "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
    }

    for fen in fens {
        mirrored := mirror_fen(fen)
        defer delete(mirrored)

        pos := process_fen(fen)
        mpos := process_fen(mirrored)

        score, mscore := eval_position(&pos), eval_position(&mpos)
        testing.expectf(t, score == mscore, "eval %d, mirrored eval %d\n  %s\n  %s",
            score, mscore, fen, mirrored)
    }
}

package main

KING_CP :: 100000
QUEEN_CP :: 900
ROOK_CP :: 500
BISHOP_CP :: 330
KNIGHT_CP :: 320
PAWN_CP :: 100

MAX_PHASE :: 24

TEMPO_BONUS :: 10

FILE_MASKS: [8]BitBoard
ADJACENT_FILE_MASKS: [8]BitBoard
PASSED_PAWN_MASKS: [Color][64]BitBoard

// Indexed by relative rank (0 = own back rank, 7 = promotion rank)
PASSED_MG := [8]int{0, 5, 5, 10, 20, 35, 60, 0}
PASSED_EG := [8]int{0, 10, 15, 25, 40, 70, 110, 0}

ISOLATED_MG :: -10
ISOLATED_EG :: -15
DOUBLED_MG :: -10
DOUBLED_EG :: -20

BISHOP_PAIR_MG :: 30
BISHOP_PAIR_EG :: 50

ROOK_OPEN_MG :: 25
ROOK_OPEN_EG :: 10
ROOK_SEMI_MG :: 12
ROOK_SEMI_EG :: 6

// Number of attacked squares at which mobility scores 0. Centering on typical
// counts keeps the term from shifting the overall material balance
MOBILITY_BASE := [PieceType]int{
    .Pawn = 0,
    .Knight = 4,
    .Bishop = 6,
    .Rook = 7,
    .Queen = 13,
    .King = 0,
}

MOBILITY_MG := [PieceType]int{
    .Pawn = 0,
    .Knight = 4,
    .Bishop = 5,
    .Rook = 2,
    .Queen = 1,
    .King = 0,
}

MOBILITY_EG := [PieceType]int{
    .Pawn = 0,
    .Knight = 4,
    .Bishop = 5,
    .Rook = 4,
    .Queen = 2,
    .King = 0,
}

KING_ATTACK_WEIGHT := [PieceType]int{
    .Pawn = 0,
    .Knight = 2,
    .Bishop = 2,
    .Rook = 3,
    .Queen = 5,
    .King = 0,
}

KING_DANGER_DIV :: 4
KING_DANGER_MAX :: 500

SHIELD_1_MG :: 12 // per pawn one rank in front
SHIELD_2_MG :: 6 // per pawn two ranks in front

KING_OPEN_FILE_MG :: 15 // per file next to the king with no friendly pawn
KING_OPEN_FILE_UNITS :: 2 // attacks units per open file next to the king

THREAT_BY_PAWN_MG := [PieceType]int{
    .Pawn = 0,
    .Knight = 40,
    .Bishop = 40,
    .Rook = 45,
    .Queen = 45,
    .King = 0,
}

THREAT_BY_PAWN_EG := [PieceType]int{
    .Pawn = 0,
    .Knight = 25,
    .Bishop = 25,
    .Rook = 30,
    .Queen = 30,
    .King = 0,
}

THREAT_BY_MINOR_MG := [PieceType]int{
    .Pawn = 0,
    .Knight = 0,
    .Bishop = 0,
    .Rook = 30,
    .Queen = 30,
    .King = 0,
}

THREAT_BY_MINOR_EG := [PieceType]int{
    .Pawn = 0,
    .Knight = 0,
    .Bishop = 0,
    .Rook = 20,
    .Queen = 30,
    .King = 0,
}

THREAT_ROOK_ON_QUEEN_MG :: 25
THREAT_ROOK_ON_QUEEN_EG :: 25

GAME_PHASE :: enum u8 {
    Mid,
    End,
}

PHASE_WEIGHT := [PieceType]int {
	.Pawn = 0,
	.Knight = 1,
	.Bishop = 1,
	.Rook = 2,
	.Queen = 4,
	.King = 0,
}

MG_PIECE_VALUE := [PieceType]int {
    .Pawn = 82,
    .Knight = 337,
    .Bishop = 365,
    .Rook = 477,
    .Queen = 1025,
    .King = 0,
}

EG_PIECE_VALUE := [PieceType]int {
    .Pawn = 94,
    .Knight = 281,
    .Bishop = 297,
    .Rook = 512,
    .Queen = 936,
    .King = 0,
}

// https://chessprogramming.org/PeSTO's_Evaluation_Function
psq_tables : [GAME_PHASE][PieceType][64]int

//odinfmt: disable
mg_pawn_table := [64]int {
      0,   0,   0,   0,   0,   0,  0,   0,
     98, 134,  61,  95,  68, 126, 34, -11,
     -6,   7,  26,  31,  65,  56, 25, -20,
    -14,  13,   6,  21,  23,  12, 17, -23,
    -27,  -2,  -5,  12,  17,   6, 10, -25,
    -26,  -4,  -4, -10,   3,   3, 33, -12,
    -35,  -1, -20, -23, -15,  24, 38, -22,
      0,   0,   0,   0,   0,   0,  0,   0,
}

eg_pawn_table := [64]int {
      0,   0,   0,   0,   0,   0,   0,   0,
    178, 173, 158, 134, 147, 132, 165, 187,
     94, 100,  85,  67,  56,  53,  82,  84,
     32,  24,  13,   5,  -2,   4,  17,  17,
     13,   9,  -3,  -7,  -7,  -8,   3,  -1,
      4,   7,  -6,   1,   0,  -5,  -1,  -8,
     13,   8,   8,  10,  13,   0,   2,  -7,
      0,   0,   0,   0,   0,   0,   0,   0,
}

mg_knight_table := [64]int {
    -167, -89, -34, -49,  61, -97, -15, -107,
     -73, -41,  72,  36,  23,  62,   7,  -17,
     -47,  60,  37,  65,  84, 129,  73,   44,
      -9,  17,  19,  53,  37,  69,  18,   22,
     -13,   4,  16,  13,  28,  19,  21,   -8,
     -23,  -9,  12,  10,  19,  17,  25,  -16,
     -29, -53, -12,  -3,  -1,  18, -14,  -19,
    -105, -21, -58, -33, -17, -28, -19,  -23,
}

eg_knight_table := [64]int {
    -58, -38, -13, -28, -31, -27, -63, -99,
    -25,  -8, -25,  -2,  -9, -25, -24, -52,
    -24, -20,  10,   9,  -1,  -9, -19, -41,
    -17,   3,  22,  22,  22,  11,   8, -18,
    -18,  -6,  16,  25,  16,  17,   4, -18,
    -23,  -3,  -1,  15,  10,  -3, -20, -22,
    -42, -20, -10,  -5,  -2, -20, -23, -44,
    -29, -51, -23, -15, -22, -18, -50, -64,
}

mg_bishop_table := [64]int {
    -29,   4, -82, -37, -25, -42,   7,  -8,
    -26,  16, -18, -13,  30,  59,  18, -47,
    -16,  37,  43,  40,  35,  50,  37,  -2,
     -4,   5,  19,  50,  37,  37,   7,  -2,
     -6,  13,  13,  26,  34,  12,  10,   4,
      0,  15,  15,  15,  14,  27,  18,  10,
      4,  15,  16,   0,   7,  21,  33,   1,
    -33,  -3, -14, -21, -13, -12, -39, -21,
}

eg_bishop_table := [64]int {
    -14, -21, -11,  -8, -7,  -9, -17, -24,
     -8,  -4,   7, -12, -3, -13,  -4, -14,
      2,  -8,   0,  -1, -2,   6,   0,   4,
     -3,   9,  12,   9, 14,  10,   3,   2,
     -6,   3,  13,  19,  7,  10,  -3,  -9,
    -12,  -3,   8,  10, 13,   3,  -7, -15,
    -14, -18,  -7,  -1,  4,  -9, -15, -27,
    -23,  -9, -23,  -5, -9, -16,  -5, -17,
}

mg_rook_table := [64]int {
     32,  42,  32,  51, 63,  9,  31,  43,
     27,  32,  58,  62, 80, 67,  26,  44,
     -5,  19,  26,  36, 17, 45,  61,  16,
    -24, -11,   7,  26, 24, 35,  -8, -20,
    -36, -26, -12,  -1,  9, -7,   6, -23,
    -45, -25, -16, -17,  3,  0,  -5, -33,
    -44, -16, -20,  -9, -1, 11,  -6, -71,
    -19, -13,   1,  17, 16,  7, -37, -26,
}

eg_rook_table := [64]int {
    13, 10, 18, 15, 12,  12,   8,   5,
    11, 13, 13, 11, -3,   3,   8,   3,
     7,  7,  7,  5,  4,  -3,  -5,  -3,
     4,  3, 13,  1,  2,   1,  -1,   2,
     3,  5,  8,  4, -5,  -6,  -8, -11,
    -4,  0, -5, -1, -7, -12,  -8, -16,
    -6, -6,  0,  2, -9,  -9, -11,  -3,
    -9,  2,  3, -1, -5, -13,   4, -20,
}

mg_queen_table := [64]int {
    -28,   0,  29,  12,  59,  44,  43,  45,
    -24, -39,  -5,   1, -16,  57,  28,  54,
    -13, -17,   7,   8,  29,  56,  47,  57,
    -27, -27, -16, -16,  -1,  17,  -2,   1,
     -9, -26,  -9, -10,  -2,  -4,   3,  -3,
    -14,   2, -11,  -2,  -5,   2,  14,   5,
    -35,  -8,  11,   2,   8,  15,  -3,   1,
     -1, -18,  -9,  10, -15, -25, -31, -50,
}

eg_queen_table := [64]int {
     -9,  22,  22,  27,  27,  19,  10,  20,
    -17,  20,  32,  41,  58,  25,  30,   0,
    -20,   6,   9,  49,  47,  35,  19,   9,
      3,  22,  24,  45,  57,  40,  57,  36,
    -18,  28,  19,  47,  31,  34,  39,  23,
    -16, -27,  15,   6,   9,  17,  10,   5,
    -22, -23, -30, -16, -16, -23, -36, -32,
    -33, -28, -22, -43,  -5, -32, -20, -41,
}

mg_king_table := [64]int {
    -65,  23,  16, -15, -56, -34,   2,  13,
     29,  -1, -20,  -7,  -8,  -4, -38, -29,
     -9,  24,   2, -16, -20,   6,  22, -22,
    -17, -20, -12, -27, -30, -25, -14, -36,
    -49,  -1, -27, -39, -46, -44, -33, -51,
    -14, -14, -22, -46, -44, -30, -15, -27,
      1,   7,  -8, -64, -43, -16,   9,   8,
    -15,  36,  12, -54,   8, -28,  24,  14,
}

eg_king_table := [64]int {
    -74, -35, -18, -18, -11,  15,   4, -17,
    -12,  17,  14,  17,  17,  38,  23,  11,
     10,  17,  23,  15,  20,  45,  44,  13,
     -8,  22,  24,  27,  26,  33,  26,   3,
    -18,  -4,  21,  24,  27,  23,   9, -11,
    -19,  -3,  11,  21,  23,  16,   7,  -9,
    -27, -11,   4,  13,  14,   4,  -5, -17,
    -53, -34, -21, -11, -28, -14, -24, -43,
}
//odinfmt: enable

@(init)
fill_piece_square_tables :: proc "contextless" () {
    // PeSTO tables are listed a8 first so we need to flip so index 0 = a1

    mg := [PieceType][64]int {
        .Pawn = mg_pawn_table,
        .Knight = mg_knight_table,
        .Bishop = mg_bishop_table,
        .Rook = mg_rook_table,
        .Queen = mg_queen_table,
        .King = mg_king_table,
    }
    
    eg := [PieceType][64]int {
        .Pawn = eg_pawn_table,
        .Knight = eg_knight_table,
        .Bishop = eg_bishop_table,
        .Rook = eg_rook_table,
        .Queen = eg_queen_table,
        .King = eg_king_table,
    }

    for pt in PieceType {
        for sq in 0..<64 {
            psq_tables[.Mid][pt][sq] = MG_PIECE_VALUE[pt] + mg[pt][flip(sq)]
            psq_tables[.End][pt][sq] = EG_PIECE_VALUE[pt] + eg[pt][flip(sq)]
        }
    }
}

@(init)
init_pawn_masks :: proc "contextless" () {
    for f in 0..<8 do FILE_MASKS[f] = FILE_A << uint(f)

    for f in 0..<8 {
        if f > 0 do ADJACENT_FILE_MASKS[f] |= FILE_MASKS[f-1]
        if f < 7 do ADJACENT_FILE_MASKS[f] |= FILE_MASKS[f+1]
    }

    for sq in 0..<64 {
        rank, file := sq_to_rank_file(sq)
        // rank, file := sq / 8, sq % 8
        span := FILE_MASKS[file] | ADJACENT_FILE_MASKS[file]

        // Ranks strictly ahead of the pawn, from each side's point of view
        ahead_white: BitBoard = rank < 7 ? ~BitBoard(0) << uint((rank + 1) * 8) : 0
        ahead_black: BitBoard = rank > 0 ? ~BitBoard(0) >> uint((8 - rank) * 8) : 0
        
        PASSED_PAWN_MASKS[.White][sq] = span & ahead_white
        PASSED_PAWN_MASKS[.Black][sq] = span & ahead_black
    }
}

// Bitboard plus its neighbors on the adjacent files
spread_files :: #force_inline proc(b: BitBoard) -> BitBoard {
    return b | ((b << 1) & ~FILE_A) | ((b >> 1) & ~FILE_H)
}

pawn_shield :: proc(pos: ^GamePosition, color: Color) -> int{
    kbb := pos.bb[color][.King]
    pawns := pos.bb[color][.Pawn]

    front1 := spread_files(color == .White ? kbb << 8 : kbb >> 8)
    front2 := color == .White ? front1 << 8 : front1 >> 8

    return SHIELD_1_MG * count_ones_bb(front1 & pawns) +
        SHIELD_2_MG * count_ones_bb(front2 & pawns)
}

// Squares attacked by parns of the given color
pawn_attacks_bb :: #force_inline proc(pawns: BitBoard, color: Color) -> BitBoard {
    if color == .White {
        return ((pawns << 7) & ~FILE_H) | ((pawns << 9) & ~FILE_A)
    }
    return ((pawns >> 9) & ~FILE_H) | ((pawns >> 7) & ~FILE_A)
}

eval_pawns :: proc(pos: ^GamePosition, color: Color) -> (mg: int, eg: int) {
    ours := pos.bb[color][.Pawn]
    theirs := pos.bb[opp_color(color)][.Pawn]

    bb := ours
    for bb != 0 {
        sq := pop_first_bit(&bb)
        file := sq % 8
        rel_rank := color == .White ? sq / 8 : 7 - (sq / 8)

        if PASSED_PAWN_MASKS[color][sq] & theirs == 0 {
            mg += PASSED_MG[rel_rank]
            eg += PASSED_EG[rel_rank]
        }
        if ADJACENT_FILE_MASKS[file] & ours == 0 {
            mg += ISOLATED_MG
            eg += ISOLATED_EG
        }
    }

    for f in 0..<8 {
        n := count_ones_bb(FILE_MASKS[f] & ours)
        if n > 1 {
            mg += DOUBLED_MG * (n-1)
            eg += DOUBLED_EG * (n-1)
        }
    }

    return
}

eval_rooks :: proc(pos: ^GamePosition, color: Color) -> (mg: int, eg: int) {
    ours := pos.bb[color][.Pawn]
    theirs := pos.bb[opp_color(color)][.Pawn]

    bb := pos.bb[color][.Rook]
    for bb != 0 {
        file := pop_first_bit(&bb) % 8
        if FILE_MASKS[file] & ours != 0 do continue // own pawn on the file

        if FILE_MASKS[file] & theirs == 0 {
            mg += ROOK_OPEN_MG
            eg += ROOK_OPEN_EG
        } else {
            mg += ROOK_SEMI_MG
            eg += ROOK_SEMI_EG
        }
    }

    return
}

eval_mobility :: proc(pos: ^GamePosition, color: Color) -> (mg, eg, attack_units, attackers: int) {
    them := opp_color(color)
    occ := all_occupied(pos)

    // Squares a piece can usefully reach: notout own pieces, not covered by enemy pawns
    area := ~pos.occupied[color] & ~pawn_attacks_bb(pos.bb[them][.Pawn], them)

    // Squares around the enemy king. Empty when there's no king (test setups)
    zone : BitBoard
    if kbb := pos.bb[them][.King]; kbb != 0 {
        tmp := kbb
        zone = king_moves[pop_first_bit(&tmp)] | kbb
    }

    minor_attacks, rook_attacks : BitBoard
    for pt in PieceType {
        if pt == .Pawn || pt == .King do continue

        bb := pos.bb[color][pt]
        for bb != 0 {
            sq := pop_first_bit(&bb)

            attacks: BitBoard
            switch pt {
                case .Knight: attacks = knight_moves[sq]
                case .Bishop: attacks = get_bishop_moves(sq, occ)
                case .Rook: attacks = get_rook_moves(sq, occ)
                case .Queen: attacks = get_queen_moves(sq, occ)
                case .Pawn, .King:
            }

            if pt == .Knight || pt == .Bishop do minor_attacks |= attacks
            else if pt == .Rook do rook_attacks |= attacks

            n := count_ones_bb(attacks & area) - MOBILITY_BASE[pt]
            mg += MOBILITY_MG[pt] * n
            eg += MOBILITY_EG[pt] * n

            if hits := count_ones_bb(attacks & zone); hits > 0 {
                attackers += 1
                attack_units += KING_ATTACK_WEIGHT[pt] * hits
            }
        }
    }

    tmg, teg := eval_threats(pos, color, minor_attacks, rook_attacks)
    mg += tmg
    eg += teg

    return
}

// Bonus for enemy pieces attacked by our cheaper pieces
eval_threats :: proc(pos: ^GamePosition, color: Color, minor_attacks, rook_attacks: BitBoard) -> (mg, eg: int) {
    them := opp_color(color)
    pawn_attacks := pawn_attacks_bb(pos.bb[color][.Pawn], color)

    for pt in PieceType {
        if pt == .Pawn || pt == .King do continue
        targets := pos.bb[them][pt]

        n := count_ones_bb(targets & pawn_attacks)
        mg += THREAT_BY_PAWN_MG[pt] * n
        eg += THREAT_BY_PAWN_EG[pt] * n

        n = count_ones_bb(targets & minor_attacks)
        mg += THREAT_BY_MINOR_MG[pt] * n
        eg += THREAT_BY_MINOR_EG[pt] * n
    }

    n := count_ones_bb(pos.bb[them][.Queen] & rook_attacks)
    mg += THREAT_ROOK_ON_QUEEN_MG * n
    eg += THREAT_ROOK_ON_QUEEN_EG * n

    return
}

// Penalty for the side whose king is attacked. A long attacker isn't a threat
king_danger :: #force_inline proc(units: int, attackers: int) -> int {
    if attackers < 2 do return 0
    return min(units * units / KING_DANGER_DIV, KING_DANGER_MAX)
}

// Penalty for files at and next to the king that have no friendly pawn
king_open_files :: proc(pos: ^GamePosition, color: Color) -> int {
    kbb := pos.bb[color][.King]
    if kbb == 0 do return 0

    tmp := kbb
    kfile := pop_first_bit(&tmp) % 8
    pawns := pos.bb[color][.Pawn]

    open := 0
    for f in max(kfile - 1, 0) ..= min(kfile+1, 7) {
        if FILE_MASKS[f] & pawns == 0 do open += 1
    }

    // return KING_OPEN_FILE_MG * open
    return open
}

eval_position :: proc(pos: ^GamePosition) -> int {
    mid_score := pos.psqt_mid[.White] - pos.psqt_mid[.Black]
    end_score := pos.psqt_end[.White] - pos.psqt_end[.Black]

    w_mg, w_eg := eval_pawns(pos, .White)
    b_mg, b_eg := eval_pawns(pos, .Black)

    mid_score += w_mg - b_mg
    end_score += w_eg - b_eg

    w_rmg, w_reg := eval_rooks(pos, .White)
    b_rmg, b_reg := eval_rooks(pos, .Black)

    mid_score += w_rmg - b_rmg
    end_score += w_reg - b_reg

    w_mmg, w_meg, w_units, w_attackers := eval_mobility(pos, .White)
    b_mmg, b_meg, b_units, b_attackers := eval_mobility(pos, .Black)

    mid_score += w_mmg - b_mmg
    end_score += w_meg - b_meg

    // w_units += KING_OPEN_FILE_UNITS * king_open_files(pos, .Black)
    // b_units += KING_OPEN_FILE_UNITS * king_open_files(pos, .White)

    w_danger := king_danger(w_units, w_attackers)
    b_danger := king_danger(b_units, b_attackers)
    mid_score += w_danger - b_danger

    mid_score += pawn_shield(pos, .White) - pawn_shield(pos, .Black)

    // mid_score -= king_open_files(pos, .White) - king_open_files(pos, .Black)

    phase := clamp(pos.phase, 0, MAX_PHASE)

    if count_ones_bb(pos.bb[.White][.Bishop]) >= 2 {
        mid_score += BISHOP_PAIR_MG
        end_score += BISHOP_PAIR_EG
    }
    if count_ones_bb(pos.bb[.Black][.Bishop]) >= 2 {
        mid_score -= BISHOP_PAIR_MG
        end_score -= BISHOP_PAIR_EG
    }

    // weighted average with full mid weight at MAX_PHASE and full end weight at phase=0
    score := (mid_score * phase + end_score * (MAX_PHASE - phase)) / MAX_PHASE

    // Should be a positive score if the side moving is ahead
    return (pos.turn == .White ? score : -score) + TEMPO_BONUS
}

flip :: #force_inline proc "contextless" (sq: int) -> int {
    return sq ~ 56
}

psqt_square :: #force_inline proc(square: int, color: Color) -> int {
    return color == .White ? square : flip(square) // flip rank, keep file
}

psqt_value_mid :: #force_inline proc(piece: Piece, square: int) -> int {
    return psq_tables[.Mid][piece.piecetype][psqt_square(square, piece.color)]
}

psqt_value_end :: #force_inline proc(piece: Piece, square: int) -> int {
    return psq_tables[.End][piece.piecetype][psqt_square(square, piece.color)]
}
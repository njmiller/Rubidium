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
PASSED_MG := [8]int{0, -4, -9, -9, 17, 24, 35, 0}
PASSED_EG := [8]int{0, 15, 17, 34, 65, 138, 90, 0}

PASSER_ENEMY_KING_EG :: 12 // per square the enemy king is from the stop square, times rank weight
PASSER_OWN_KING_EG :: 7 //per square our king is from the stop square, times rank weight
PASSER_BLOCKED_MG :: 4 // per rank weight when the stop square is occupied
PASSER_BLOCKED_EG :: 17

ISOLATED_MG :: -12
ISOLATED_EG :: -15
DOUBLED_MG :: -2
DOUBLED_EG :: -14

BISHOP_PAIR_MG :: 21
BISHOP_PAIR_EG :: 62

ROOK_OPEN_MG :: 35
ROOK_OPEN_EG :: 3
ROOK_SEMI_MG :: 15
ROOK_SEMI_EG :: 9

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

MOBILITY_MG := [PieceType]int {
    .Pawn = 0,
    .Knight = 7,
    .Bishop = 7,
    .Rook = 3,
    .Queen = 3,
    .King = 0,
}

MOBILITY_EG := [PieceType]int {
    .Pawn = 0,
    .Knight = 4,
    .Bishop = 4,
    .Rook = 4,
    .Queen = 4,
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

SHIELD_1_MG :: 13 // per pawn one rank in front
SHIELD_2_MG :: 6 // per pawn two ranks in front

KING_OPEN_FILE_MG :: 26 // per file next to the king with no friendly pawn
KING_OPEN_FILE_UNITS :: 2 // attacks units per open file next to the king

THREAT_BY_PAWN_MG := [PieceType]int {
    .Pawn = 0,
    .Knight = 47,
    .Bishop = 53,
    .Rook = 71,
    .Queen = 62,
    .King = 0,
}

THREAT_BY_PAWN_EG := [PieceType]int {
    .Pawn = 0,
    .Knight = 15,
    .Bishop = 36,
    .Rook = -8,
    .Queen = -48,
    .King = 0,
}

THREAT_BY_MINOR_MG := [PieceType]int {
    .Pawn = 0,
    .Knight = 18,
    .Bishop = 26,
    .Rook = 44,
    .Queen = 43,
    .King = 0,
}

THREAT_BY_MINOR_EG := [PieceType]int {
    .Pawn = 0,
    .Knight = 20,
    .Bishop = 27,
    .Rook = 6,
    .Queen = 0,
    .King = 0,
}

THREAT_ROOK_ON_QUEEN_MG :: 56
THREAT_ROOK_ON_QUEEN_EG :: 5

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
    .Pawn = 84,
    .Knight = 301,
    .Bishop = 325,
    .Rook = 410,
    .Queen = 864,
    .King = 0,
}

EG_PIECE_VALUE := [PieceType]int {
    .Pawn = 135,
    .Knight = 383,
    .Bishop = 404,
    .Rook = 702,
    .Queen = 1346,
    .King = 0,
}

// https://chessprogramming.org/PeSTO's_Evaluation_Function
psq_tables : [GAME_PHASE][PieceType][64]int

//odinfmt: disable
mg_pawn_table := [64]int {
       0,    0,    0,    0,    0,    0,    0,    0,
      53,   48,   41,   98,   77,   68,   -8,  -18,
      -1,  -12,   16,   22,   34,   60,   33,    2,
     -22,  -19,  -10,  -10,   10,    4,  -12,  -18,
     -27,  -27,  -15,   -2,    1,  -10,  -23,  -28,
     -31,  -26,  -18,  -18,   -2,  -19,   -6,  -27,
     -28,  -26,  -21,  -27,  -12,   -9,    0,  -35,
       0,    0,    0,    0,    0,    0,    0,    0,
}

eg_pawn_table := [64]int {
       0,    0,    0,    0,    0,    0,    0,    0,
      95,   98,  129,   98,  101,  100,  131,  132,
       0,   13,  -11,  -28,  -30,  -22,    3,    5,
      -5,  -11,  -22,  -34,  -33,  -30,  -17,  -18,
     -19,  -19,  -29,  -34,  -36,  -31,  -28,  -29,
     -23,  -25,  -29,  -25,  -26,  -25,  -34,  -32,
     -22,  -24,  -24,  -25,  -16,  -22,  -35,  -33,
       0,    0,    0,    0,    0,    0,    0,    0,
}

mg_knight_table := [64]int {
    -142, -122,  -70,  -34,   -2,  -59, -105,  -95,
     -27,  -12,   -1,   17,    7,   51,   -3,   12,
      -4,   14,   23,   38,   53,   79,   32,   29,
       5,   12,   29,   53,   36,   53,   20,   37,
      -3,    6,   19,   30,   34,   29,   35,   11,
     -20,   -2,    8,   14,   31,   19,   20,    3,
     -27,  -16,   -4,   14,   15,   10,    5,    3,
     -64,  -19,  -23,   -6,   -3,    5,  -16,  -33,
}

eg_knight_table := [64]int {
     -70,  -11,    5,   -8,   -4,  -26,  -14,  -92,
     -10,    4,    9,    7,    1,  -12,   -2,  -31,
       0,    9,   20,   21,   10,   -4,   -2,  -16,
      12,   22,   28,   32,   30,   25,   21,   -1,
      10,   13,   28,   28,   33,   21,   11,    1,
      -7,    4,    9,   22,   20,    4,    1,   -4,
     -14,   -3,    3,    1,    2,    2,  -11,   -4,
     -23,  -28,   -8,   -4,   -2,  -11,  -18,  -27,
}

mg_bishop_table := [64]int {
     -31,  -52,  -51,  -92,  -80,  -67,  -38,  -64,
     -14,  -23,  -15,  -23,  -16,   -1,  -25,   -6,
      -2,   13,    0,   13,   15,   45,   32,   23,
     -13,    1,   11,   31,   21,   19,   -2,   -4,
      -6,  -10,    9,   28,   25,    4,    0,    5,
      -5,   19,   16,   17,   20,   19,   19,   14,
      14,   15,   25,    8,   18,   25,   34,   19,
       0,   25,    5,   -3,    2,    0,   13,   18,
}

eg_bishop_table := [64]int {
       5,   11,    6,   17,   15,    0,    3,   -6,
     -10,    5,    2,    6,   -3,   -1,    1,  -13,
      10,    2,    6,   -2,    1,    1,    1,    4,
       5,   11,    4,   15,    5,    9,    8,    4,
      -1,    8,   12,    8,    6,    8,    6,  -12,
      -3,    5,    5,   10,   14,    5,   -2,  -10,
      -5,  -14,  -14,   -3,   -2,   -8,   -8,  -25,
     -22,   -3,  -14,   -4,   -7,    0,  -15,  -40,
}

mg_rook_table := [64]int {
      -5,  -14,  -13,  -17,   -7,   18,   11,   28,
     -13,  -13,    2,   16,    5,   38,   32,   48,
     -22,    5,   -1,    0,   28,   42,   82,   41,
     -25,  -11,  -11,   -7,   -1,   14,   23,    9,
     -33,  -33,  -23,  -15,  -14,  -15,    8,   -9,
     -32,  -28,  -21,  -20,   -9,    0,   28,    4,
     -29,  -25,  -13,   -9,   -3,    5,   21,  -15,
     -12,   -9,   -6,    3,    8,    8,   11,   -4,
}

eg_rook_table := [64]int {
      12,   17,   22,   18,   13,   12,   17,    9,
      15,   24,   26,   16,   17,    7,    5,   -5,
      16,   13,   14,   12,   -1,   -7,  -11,  -12,
      19,   13,   18,   14,    0,   -6,   -3,   -4,
      10,   10,    7,    5,    2,   -1,   -9,  -10,
      -1,   -2,   -5,   -2,   -9,  -17,  -33,  -27,
     -11,   -6,   -6,   -8,  -15,  -21,  -30,  -23,
      -6,   -9,   -3,  -11,  -17,  -13,  -18,  -19,
}

mg_queen_table := [64]int {
     -41,  -51,  -29,  -10,  -12,   -6,   42,  -12,
      -5,  -31,  -31,  -43,  -40,    7,   -2,   47,
      -2,   -8,  -10,   -5,    2,   39,   49,   40,
     -16,   -8,   -9,  -10,   -9,    2,    8,    9,
      -7,  -14,   -9,   -1,   -1,   -3,    7,   11,
      -7,   -1,    1,   -2,    3,   10,   19,   13,
      -2,    1,    8,   15,   13,   21,   27,   27,
     -10,   -4,    4,   10,    9,   -2,    9,    1,
}

eg_queen_table := [64]int {
      -2,   19,   33,   28,   31,   30,  -27,    3,
     -21,   10,   44,   66,   84,   40,   23,   10,
     -13,   -4,   27,   41,   56,   39,    6,    8,
      -1,    4,   14,   37,   50,   43,   42,   22,
     -18,    9,    9,   22,   24,   23,   14,    9,
     -33,  -11,   -4,   -4,    2,   -1,  -13,  -23,
     -42,  -37,  -33,  -34,  -27,  -50,  -75,  -90,
     -37,  -41,  -38,  -30,  -42,  -43,  -61,  -64,
}

mg_king_table := [64]int {
      66,   82,   71,  -48,  -37,   16,  118,  206,
     -69,   20,  -10,   74,   39,   25,   93,   64,
     -92,   41,  -25,  -46,   -1,   67,   50,   -2,
     -47,  -36,  -70, -121, -109,  -62,  -54, -114,
     -60,  -36,  -59, -103,  -90,  -54,  -60, -124,
     -12,   27,  -19,  -36,  -30,  -27,    4,  -30,
      68,   40,   32,    1,   -1,   11,   54,   50,
      52,   79,   69,  -12,   42,    7,   65,   65,
}

eg_king_table := [64]int {
     -91,  -54,  -34,    7,    0,    4,  -15, -105,
      -5,   13,   22,    7,   24,   43,   28,    9,
       9,   21,   33,   44,   46,   39,   38,   15,
      -3,   21,   40,   51,   53,   47,   39,   24,
     -13,    9,   27,   43,   40,   29,   20,   13,
     -27,   -9,    7,   18,   18,   12,   -3,  -11,
     -42,  -20,  -12,   -3,    1,   -6,  -22,  -36,
     -75,  -59,  -40,  -23,  -43,  -26,  -54,  -83,
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

    n1 := count_ones_bb(front1 & pawns)
    n2 := count_ones_bb(front2 & pawns)
    trace_add(F_SHIELD_1, color, n1)
    trace_add(F_SHIELD_2, color, n2)

    return SHIELD_1_MG * n1 + SHIELD_2_MG * n2
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
            trace_add(F_PASSED + rel_rank, color)
        }
        if ADJACENT_FILE_MASKS[file] & ours == 0 {
            mg += ISOLATED_MG
            eg += ISOLATED_EG
            trace_add(F_ISOLATED, color)
        }
    }

    for f in 0..<8 {
        n := count_ones_bb(FILE_MASKS[f] & ours)
        if n > 1 {
            mg += DOUBLED_MG * (n-1)
            eg += DOUBLED_EG * (n-1)
            trace_add(F_DOUBLED, color, n - 1)
        }
    }

    return
}

// Number of king moves between two squares
square_distance :: #force_inline proc(a, b: int) -> int {
    return max(abs(a% 8 - b % 8), abs(a / 8 - b / 8))
}

// King proximity and blockers for passed pawns. Kept out of eval_pawns because
// it depends on more than the pawns
eval_passers :: proc(pos: ^GamePosition, color: Color) -> (mg, eg: int) {
    them := opp_color(color)
    ours := pos.bb[color][.Pawn]
    theirs := pos.bb[them][.Pawn]
    occ := all_occupied(pos)

    // Test setups can lack a king. Skip the distance tersm then
    our_kbb, their_kbb := pos.bb[color][.King], pos.bb[them][.King]
    have_kings := our_kbb != 0 && their_kbb != 0
    our_king := have_kings ? pop_first_bit(&our_kbb) : 0
    their_king := have_kings ? pop_first_bit(&their_kbb) : 0

    bb := ours
    for bb != 0 {
        sq := pop_first_bit(&bb)
        if PASSED_PAWN_MASKS[color][sq] & theirs != 0 do continue

        rel_rank := color == .White ? sq / 8 : 7 - (sq / 8)
        weight := rel_rank - 2 // 0 on ranks 2-3, up to 4 on the 7th
        if weight <= 0 do continue

        stop := color == .White ? sq + 8 : sq - 8

        if have_kings {
            their_dist := square_distance(their_king, stop)
            our_dist := square_distance(our_king, stop)
            eg += weight * (PASSER_ENEMY_KING_EG * their_dist - PASSER_OWN_KING_EG * our_dist)
            trace_add(F_PASSER_ENEMY_KING, color, weight * their_dist)
            trace_add(F_PASSER_OWN_KING, color, -weight * our_dist)
        }

        if occ & (BitBoard(1) << uint(stop)) != 0 {
            mg -= PASSER_BLOCKED_MG * weight
            eg -= PASSER_BLOCKED_EG * weight
            trace_add(F_PASSER_BLOCKED, color, -weight)
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
            trace_add(F_ROOK_OPEN, color)
        } else {
            mg += ROOK_SEMI_MG
            eg += ROOK_SEMI_EG
            trace_add(F_ROOK_SEMI, color)
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
            trace_add(F_MOBILITY + int(pt), color, n)

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
        trace_add(F_THREAT_BY_PAWN + int(pt), color, n)

        n = count_ones_bb(targets & minor_attacks)
        mg += THREAT_BY_MINOR_MG[pt] * n
        eg += THREAT_BY_MINOR_EG[pt] * n
        trace_add(F_THREAT_BY_MINOR + int(pt), color, n)
    }

    n := count_ones_bb(pos.bb[them][.Queen] & rook_attacks)
    mg += THREAT_ROOK_ON_QUEEN_MG * n
    eg += THREAT_ROOK_ON_QUEEN_EG * n
    trace_add(F_THREAT_ROOK_ON_QUEEN, color, n)

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

    trace_add(F_KING_OPEN_FILE, color, -open) // subtracted in eval_position
    return KING_OPEN_FILE_MG * open
}

eval_position :: proc(pos: ^GamePosition) -> int {
    mid_score := pos.psqt_mid[.White] - pos.psqt_mid[.Black]
    end_score := pos.psqt_end[.White] - pos.psqt_end[.Black]

    w_mg, w_eg := eval_pawns(pos, .White)
    b_mg, b_eg := eval_pawns(pos, .Black)

    mid_score += w_mg - b_mg
    end_score += w_eg - b_eg

    w_pmg, w_peg := eval_passers(pos, .White)
    b_pmg, b_peg := eval_passers(pos, .Black)

    mid_score += w_pmg - b_pmg
    end_score += w_peg - b_peg

    w_rmg, w_reg := eval_rooks(pos, .White)
    b_rmg, b_reg := eval_rooks(pos, .Black)

    mid_score += w_rmg - b_rmg
    end_score += w_reg - b_reg

    w_mmg, w_meg, w_units, w_attackers := eval_mobility(pos, .White)
    b_mmg, b_meg, b_units, b_attackers := eval_mobility(pos, .Black)

    mid_score += w_mmg - b_mmg
    end_score += w_meg - b_meg

    w_danger := king_danger(w_units, w_attackers)
    b_danger := king_danger(b_units, b_attackers)
    mid_score += w_danger - b_danger
    when TUNE {
        trace_danger = w_danger - b_danger
    }

    mid_score += pawn_shield(pos, .White) - pawn_shield(pos, .Black)

    mid_score -= king_open_files(pos, .White) - king_open_files(pos, .Black)

    phase := clamp(pos.phase, 0, MAX_PHASE)

    if count_ones_bb(pos.bb[.White][.Bishop]) >= 2 {
        mid_score += BISHOP_PAIR_MG
        end_score += BISHOP_PAIR_EG
        trace_add(F_BISHOP_PAIR, .White)
    }
    if count_ones_bb(pos.bb[.Black][.Bishop]) >= 2 {
        mid_score -= BISHOP_PAIR_MG
        end_score -= BISHOP_PAIR_EG
        trace_add(F_BISHOP_PAIR, .Black)
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

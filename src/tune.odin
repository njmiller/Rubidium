package main

import "core:bufio"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "core:time"

// Texel tuner. Build with -define:TUNE=true so the eval records which weights
// fired, then run `rubidium tune <file>` on quiet positions labeled with game
// results. Prints the tuned weights as Odin source to paste into eval.odin

TUNE :: #config(TUNE, false)

// Index of each tunable eval weight. Every weight has an mg and an eg value
F_MATERIAL :: 0                               // [PieceType]
F_PSQT :: F_MATERIAL + 6                      // [PieceType][64], white's view, a1 = 0
F_PASSED :: F_PSQT + 6 * 64                   // [8] by relative rank
F_PASSER_ENEMY_KING :: F_PASSED + 8
F_PASSER_OWN_KING :: F_PASSER_ENEMY_KING + 1
F_PASSER_BLOCKED :: F_PASSER_OWN_KING + 1
F_ISOLATED :: F_PASSER_BLOCKED + 1
F_DOUBLED :: F_ISOLATED + 1
F_BISHOP_PAIR :: F_DOUBLED + 1
F_ROOK_OPEN :: F_BISHOP_PAIR + 1
F_ROOK_SEMI :: F_ROOK_OPEN + 1
F_MOBILITY :: F_ROOK_SEMI + 1                 // [PieceType]
F_THREAT_BY_PAWN :: F_MOBILITY + 6            // [PieceType] of the attacked piece
F_THREAT_BY_MINOR :: F_THREAT_BY_PAWN + 6     // [PieceType] of the attacked piece
F_THREAT_ROOK_ON_QUEEN :: F_THREAT_BY_MINOR + 6
F_SHIELD_1 :: F_THREAT_ROOK_ON_QUEEN + 1
F_SHIELD_2 :: F_SHIELD_1 + 1
F_KING_OPEN_FILE :: F_SHIELD_2 + 1
NUM_FEATURES :: F_KING_OPEN_FILE + 1

// How often each weight fired in the last eval, white minus black. Material
// and PSQT come from the incremental fields, so the tuner adds those itself.
// Only written in TUNE builds
trace: [NUM_FEATURES]int
trace_danger: int // king danger, white minus black. Quadratic, so the tuner holds it fixed

trace_add :: #force_inline proc(f: int, color: Color, n := 1) {
    when TUNE {
        trace[f] += color == .White ? n : -n
    }
}

Params :: [NUM_FEATURES]f64

Coef :: struct {
    index: u16,
    value: i16,
}

Entry :: struct {
    start:     u32, // first coefficient in the shared coefs array
    count:     u16,
    mg_weight: f32, // phase / MAX_PHASE
    result:    f32, // 1 white win, 0.5 draw, 0 black win
    fixed:     f32, // king danger and tempo, which the tuner doesn't change
}

Tuner :: struct {
    entries: [dynamic]Entry,
    coefs:   [dynamic]Coef,
}

// Which halves of a weight exist in the eval. The rest stay at 0
tunable :: proc(f: int) -> (mg, eg: bool) {
    switch f {
    case F_PASSER_ENEMY_KING, F_PASSER_OWN_KING: return false, true
    case F_SHIELD_1, F_SHIELD_2, F_KING_OPEN_FILE: return true, false
    }
    return true, true
}

// The weights currently in eval.odin
init_params :: proc(mg, eg: ^Params) {
    set :: proc(mg, eg: ^Params, f: int, m, e: int) {
        mg[f], eg[f] = f64(m), f64(e)
    }

    for pt in PieceType {
        p := int(pt)
        set(mg, eg, F_MATERIAL + p, MG_PIECE_VALUE[pt], EG_PIECE_VALUE[pt])
        for sq in 0 ..< 64 {
            set(mg, eg, F_PSQT + p * 64 + sq,
                psq_tables[.Mid][pt][sq] - MG_PIECE_VALUE[pt],
                psq_tables[.End][pt][sq] - EG_PIECE_VALUE[pt])
        }
        set(mg, eg, F_MOBILITY + p, MOBILITY_MG[pt], MOBILITY_EG[pt])
        set(mg, eg, F_THREAT_BY_PAWN + p, THREAT_BY_PAWN_MG[pt], THREAT_BY_PAWN_EG[pt])
        set(mg, eg, F_THREAT_BY_MINOR + p, THREAT_BY_MINOR_MG[pt], THREAT_BY_MINOR_EG[pt])
    }
    for r in 0 ..< 8 do set(mg, eg, F_PASSED + r, PASSED_MG[r], PASSED_EG[r])

    set(mg, eg, F_PASSER_ENEMY_KING, 0, PASSER_ENEMY_KING_EG)
    set(mg, eg, F_PASSER_OWN_KING, 0, PASSER_OWN_KING_EG)
    set(mg, eg, F_PASSER_BLOCKED, PASSER_BLOCKED_MG, PASSER_BLOCKED_EG)
    set(mg, eg, F_ISOLATED, ISOLATED_MG, ISOLATED_EG)
    set(mg, eg, F_DOUBLED, DOUBLED_MG, DOUBLED_EG)
    set(mg, eg, F_BISHOP_PAIR, BISHOP_PAIR_MG, BISHOP_PAIR_EG)
    set(mg, eg, F_ROOK_OPEN, ROOK_OPEN_MG, ROOK_OPEN_EG)
    set(mg, eg, F_ROOK_SEMI, ROOK_SEMI_MG, ROOK_SEMI_EG)
    set(mg, eg, F_THREAT_ROOK_ON_QUEEN, THREAT_ROOK_ON_QUEEN_MG, THREAT_ROOK_ON_QUEEN_EG)
    set(mg, eg, F_SHIELD_1, SHIELD_1_MG, 0)
    set(mg, eg, F_SHIELD_2, SHIELD_2_MG, 0)
    set(mg, eg, F_KING_OPEN_FILE, KING_OPEN_FILE_MG, 0)
}

// Game result from a Zurichess style `c9 "1-0";` or a `[1.0]` tag
parse_result :: proc(line: string) -> (result: f32, ok: bool) {
    switch {
    case strings.contains(line, "1/2-1/2"), strings.contains(line, "[0.5]"): return 0.5, true
    case strings.contains(line, "1-0"), strings.contains(line, "[1.0]"): return 1, true
    case strings.contains(line, "0-1"), strings.contains(line, "[0.0]"): return 0, true
    }
    return
}

// Evals the position, records its coefficients and checks that the linear
// model with the current weights reproduces eval_position
add_position :: proc(tuner: ^Tuner, fen: string, result: f32, mg, eg: ^Params) -> (matches: bool) {
    pos := process_fen(fen)

    trace = {}
    trace_danger = 0
    score := eval_position(&pos)

    for color in Color {
        sign := color == .White ? 1 : -1
        for pt in PieceType {
            bb := pos.bb[color][pt]
            trace[F_MATERIAL + int(pt)] += sign * count_ones_bb(bb)
            for bb != 0 {
                sq := psqt_square(pop_first_bit(&bb), color)
                trace[F_PSQT + int(pt) * 64 + sq] += sign
            }
        }
    }

    w := f64(clamp(pos.phase, 0, MAX_PHASE)) / MAX_PHASE
    tempo := pos.turn == .White ? TEMPO_BONUS : -TEMPO_BONUS
    e := Entry {
        start     = u32(len(tuner.coefs)),
        mg_weight = f32(w),
        result    = result,
        fixed     = f32(f64(trace_danger) * w + f64(tempo)),
    }
    for c, i in trace {
        if c == 0 do continue
        append(&tuner.coefs, Coef{u16(i), i16(c)})
        e.count += 1
    }
    append(&tuner.entries, e)

    white_score := pos.turn == .White ? score : -score
    return abs(linear_eval(tuner, e, mg, eg) - f64(white_score)) <= 1
}

load_positions :: proc(tuner: ^Tuner, path: string, mg, eg: ^Params) -> bool {
    f, err := os.open(path)
    if err != nil {
        fmt.eprintln("Can't open", path, err)
        return false
    }
    defer os.close(f)

    s: bufio.Scanner
    bufio.scanner_init(&s, os.to_stream(f))
    defer bufio.scanner_destroy(&s)

    skipped, mismatched := 0, 0
    for bufio.scanner_scan(&s) {
        defer free_all(context.temp_allocator)
        line := bufio.scanner_text(&s)

        fields := strings.fields(line, context.temp_allocator)
        result, ok := parse_result(line)
        if !ok || len(fields) < 4 {
            skipped += 1
            continue
        }

        // Only the first four fields. The clocks don't affect the eval
        fen := fmt.tprintf("%s %s %s %s 0 1", fields[0], fields[1], fields[2], fields[3])
        if !add_position(tuner, fen, result, mg, eg) {
            if mismatched < 5 do fmt.eprintln("Trace doesn't match eval_position:", fen)
            mismatched += 1
        }
    }

    fmt.eprintfln("Loaded %d positions, skipped %d lines", len(tuner.entries), skipped)
    if mismatched > 0 {
        fmt.eprintfln("%d positions where the trace doesn't match eval_position. Check the trace_add calls", mismatched)
        return false
    }
    return len(tuner.entries) > 0
}

sigmoid :: #force_inline proc(x: f64) -> f64 {
    return 1 / (1 + math.exp(-x))
}

// White's eval of one position under the given weights
linear_eval :: #force_inline proc(tuner: ^Tuner, e: Entry, mg, eg: ^Params) -> f64 {
    w := f64(e.mg_weight)
    score := f64(e.fixed)
    for c in tuner.coefs[e.start:][:e.count] {
        score += f64(c.value) * (mg[c.index] * w + eg[c.index] * (1 - w))
    }
    return score
}

// Mean squared error between predicted and actual results
total_error :: proc(tuner: ^Tuner, mg, eg: ^Params, k: f64) -> f64 {
    sum := 0.0
    for e in tuner.entries {
        diff := sigmoid(k * linear_eval(tuner, e, mg, eg)) - f64(e.result)
        sum += diff * diff
    }
    return sum / f64(len(tuner.entries))
}

// Gradient of the error, up to a constant factor (Adam doesn't need it)
compute_gradient :: proc(tuner: ^Tuner, mg, eg: ^Params, k: f64, grad_mg, grad_eg: ^Params) {
    grad_mg^, grad_eg^ = {}, {}
    for e in tuner.entries {
        s := sigmoid(k * linear_eval(tuner, e, mg, eg))
        d := (s - f64(e.result)) * s * (1 - s)
        w := f64(e.mg_weight)
        for c in tuner.coefs[e.start:][:e.count] {
            g := d * f64(c.value)
            grad_mg[c.index] += g * w
            grad_eg[c.index] += g * (1 - w)
        }
    }
}

// Scale that best maps the starting eval to results. Found once and then held
// fixed, so tuning changes the weights and not the scale
fit_k :: proc(tuner: ^Tuner, mg, eg: ^Params) -> f64 {
    best_k, best := 0.0, max(f64)
    lo, hi, step := 0.001, 0.02, 0.001
    for _ in 0 ..< 4 {
        for k := lo; k <= hi; k += step {
            if err := total_error(tuner, mg, eg, k); err < best {
                best, best_k = err, k
            }
        }
        lo, hi, step = max(best_k - step, step / 10), best_k + step, step / 10
    }
    return best_k
}

ADAM_BETA1 :: 0.9
ADAM_BETA2 :: 0.999
ADAM_EPS :: 1e-8

adam_step :: #force_inline proc(p, m, v: ^f64, g, lr: f64, t: int) {
    m^ = ADAM_BETA1 * m^ + (1 - ADAM_BETA1) * g
    v^ = ADAM_BETA2 * v^ + (1 - ADAM_BETA2) * g * g
    m_hat := m^ / (1 - math.pow(ADAM_BETA1, f64(t)))
    v_hat := v^ / (1 - math.pow(ADAM_BETA2, f64(t)))
    p^ -= lr * m_hat / (math.sqrt(v_hat) + ADAM_EPS)
}

run_tune :: proc(path: string, epochs: int, lr: f64) {
    mg, eg: Params
    init_params(&mg, &eg)

    tuner: Tuner
    defer {
        delete(tuner.entries)
        delete(tuner.coefs)
    }
    if !load_positions(&tuner, path, &mg, &eg) do os.exit(1)

    k := fit_k(&tuner, &mg, &eg)
    fmt.eprintfln("K = %.5f, starting error %.6f", k, total_error(&tuner, &mg, &eg, k))

    tune_mg, tune_eg: [NUM_FEATURES]bool
    for f in 0 ..< NUM_FEATURES do tune_mg[f], tune_eg[f] = tunable(f)

    grad_mg, grad_eg, m_mg, m_eg, v_mg, v_eg: Params
    start := time.tick_now()
    for epoch in 1 ..= epochs {
        compute_gradient(&tuner, &mg, &eg, k, &grad_mg, &grad_eg)
        for f in 0 ..< NUM_FEATURES {
            if tune_mg[f] do adam_step(&mg[f], &m_mg[f], &v_mg[f], grad_mg[f], lr, epoch)
            if tune_eg[f] do adam_step(&eg[f], &m_eg[f], &v_eg[f], grad_eg[f], lr, epoch)
        }

        if epoch % 100 == 0 || epoch == epochs {
            fmt.eprintfln("epoch %d  error %.6f  %.0fs", epoch, total_error(&tuner, &mg, &eg, k),
                time.duration_seconds(time.tick_since(start)))
        }
    }

    normalize_psqt(&mg)
    normalize_psqt(&eg)
    print_params(&mg, &eg)
}

// Moves each table's average into the piece value so the tables stay centered
// on 0. Doesn't change any eval: every piece adds both. Kings always cancel, so
// their average just goes away
normalize_psqt :: proc(p: ^Params) {
    for pt in PieceType {
        // Pawns never stand on the first or last rank
        lo, hi := pt == .Pawn ? 8 : 0, pt == .Pawn ? 56 : 64
        base := F_PSQT + int(pt) * 64

        sum := 0.0
        for sq in lo ..< hi do sum += p[base + sq]
        mean := sum / f64(hi - lo)

        for sq in lo ..< hi do p[base + sq] -= mean
        if pt != .King do p[F_MATERIAL + int(pt)] += mean
    }
}

PIECE_NAMES := [PieceType]string {
    .Pawn   = "pawn",
    .Knight = "knight",
    .Bishop = "bishop",
    .Rook   = "rook",
    .Queen  = "queen",
    .King   = "king",
}

rounded :: #force_inline proc(x: f64) -> int {
    return int(math.round(x))
}

print_piece_array :: proc(name: string, p: ^Params, base: int) {
    fmt.printfln("%s := [PieceType]int {{", name)
    for pt in PieceType do fmt.printfln("    .%v = %d,", pt, rounded(p[base + int(pt)]))
    fmt.println("}\n")
}

print_scalar :: proc(name: string, f: int, mg, eg: ^Params) {
    has_mg, has_eg := tunable(f)
    if has_mg do fmt.printfln("%s_MG :: %d", name, rounded(mg[f]))
    if has_eg do fmt.printfln("%s_EG :: %d", name, rounded(eg[f]))
}

print_params :: proc(mg, eg: ^Params) {
    print_piece_array("MG_PIECE_VALUE", mg, F_MATERIAL)
    print_piece_array("EG_PIECE_VALUE", eg, F_MATERIAL)

    // PeSTO layout: a8 first
    fmt.println("//odinfmt: disable")
    for pt in PieceType {
        for phase in GAME_PHASE {
            p := phase == .Mid ? mg : eg
            fmt.printfln("%s_%s_table := [64]int {{", phase == .Mid ? "mg" : "eg", PIECE_NAMES[pt])
            for row in 0 ..< 8 {
                fmt.print("   ")
                for col in 0 ..< 8 {
                    // %4d pads with zeros, so right-align by hand
                    s := fmt.tprintf("%d,", rounded(p[F_PSQT + int(pt) * 64 + flip(row * 8 + col)]))
                    fmt.printf(" %s%s", strings.repeat(" ", max(5 - len(s), 0), context.temp_allocator), s)
                }
                fmt.println()
            }
            fmt.println("}\n")
        }
    }
    fmt.println("//odinfmt: enable\n")

    for p, i in ([2]^Params{mg, eg}) {
        fmt.printf("PASSED_%s := [8]int{{", i == 0 ? "MG" : "EG")
        for r in 0 ..< 8 do fmt.printf(r == 0 ? "%d" : ", %d", rounded(p[F_PASSED + r]))
        fmt.println("}")
    }
    fmt.println()

    print_scalar("PASSER_ENEMY_KING", F_PASSER_ENEMY_KING, mg, eg)
    print_scalar("PASSER_OWN_KING", F_PASSER_OWN_KING, mg, eg)
    print_scalar("PASSER_BLOCKED", F_PASSER_BLOCKED, mg, eg)
    print_scalar("ISOLATED", F_ISOLATED, mg, eg)
    print_scalar("DOUBLED", F_DOUBLED, mg, eg)
    print_scalar("BISHOP_PAIR", F_BISHOP_PAIR, mg, eg)
    print_scalar("ROOK_OPEN", F_ROOK_OPEN, mg, eg)
    print_scalar("ROOK_SEMI", F_ROOK_SEMI, mg, eg)
    print_scalar("THREAT_ROOK_ON_QUEEN", F_THREAT_ROOK_ON_QUEEN, mg, eg)
    print_scalar("SHIELD_1", F_SHIELD_1, mg, eg)
    print_scalar("SHIELD_2", F_SHIELD_2, mg, eg)
    print_scalar("KING_OPEN_FILE", F_KING_OPEN_FILE, mg, eg)
    fmt.println()

    print_piece_array("MOBILITY_MG", mg, F_MOBILITY)
    print_piece_array("MOBILITY_EG", eg, F_MOBILITY)
    print_piece_array("THREAT_BY_PAWN_MG", mg, F_THREAT_BY_PAWN)
    print_piece_array("THREAT_BY_PAWN_EG", eg, F_THREAT_BY_PAWN)
    print_piece_array("THREAT_BY_MINOR_MG", mg, F_THREAT_BY_MINOR)
    print_piece_array("THREAT_BY_MINOR_EG", eg, F_THREAT_BY_MINOR)
}

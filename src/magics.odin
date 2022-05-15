package main

import "core:fmt"
import "core:math/rand"


a : rand.Rand = rand.create(1123)
random_u64_fewbits :: proc() -> BitBoard {
    return BitBoard(rand.uint64(&a) & rand.uint64(&a) & rand.uint64(&a))
}

count_ones :: proc(b : BitBoard) -> int {
    r : int = 0
    bp : BitBoard = b
    for (bp > 0) {
        r = r + 1
        bp = bp & (bp-1)
    }
    return r
}

BitTable := [64]int{
    63, 30, 3, 32, 25, 41, 22, 33, 15, 50, 42, 13, 11, 53, 19, 34, 61, 29, 2,
  51, 21, 43, 45, 10, 18, 47, 1, 54, 9, 57, 0, 35, 62, 31, 40, 4, 49, 5, 52,
  26, 60, 6, 23, 44, 46, 27, 56, 16, 7, 39, 48, 24, 59, 14, 12, 55, 38, 28,
  58, 20, 37, 17, 36, 8}

pop_first_bit :: proc(bb : ^BitBoard) -> int {
    b : BitBoard = bb^ ~ (bb^-1)
    fold : u32 = u32((b & 0xffffffff) ~ (b >> 32))
    bb^ = bb^ & (bb^-1)
    return BitTable[(fold * 0x783a9b23) >> 26]
}

index_to_bb :: proc(index : int, bits : int, m : BitBoard) -> BitBoard {
    i, j : int
    mp : BitBoard = m
    result : BitBoard = 0
    for i in 0..<bits {
        j = pop_first_bit(&mp)
        if(index & (1 << u64(i)) != 0) {
            result = result | (1 << u64(j))
        }
    }
    return result
}

rmask :: proc(sq : int) -> BitBoard {
    result : BitBoard = 0
    rk, fl : int = sq/8, sq%8
    i : BitBoard = 1
    
    for r := rk+1; r <= 6; r += 1 do result |= (i << u64(fl + r*8))
    for r := rk-1; r >= 1; r -= 1 do result |= (i << u64(fl + r*8))
    for f := fl+1; f <= 6; f += 1 do result |= (i << u64(f + rk*8))
    for f := fl-1; f >= 1; f -= 1 do result |= (i << u64(f + rk*8))

    return result
}

bmask :: proc(sq : int) -> BitBoard {
    result : BitBoard = 0
    rk, fl : int = sq/8, sq%8
    i : BitBoard = 1

    for r, f := rk+1, fl+1; r<=6 && f<=6; r, f = r+1, f+1 do result |= (i << u64(f+r*8))
    for r, f := rk+1, fl-1; r<=6 && f>=1; r, f = r+1, f-1 do result |= (i << u64(f+r*8))
    for r, f := rk-1, fl+1; r>=1 && f<=6; r, f = r-1, f+1 do result |= (i << u64(f+r*8))
    for r, f := rk-1, fl-1; r>=1 && f>=1; r, f = r-1, f-1 do result |= (i << u64(f+r*8))
    return result 
}

ratt :: proc(sq : int, block : BitBoard) -> BitBoard {
    result, i : BitBoard = 0, 1
    rk, fl : int = sq/8, sq%8

    for r := rk+1; r <= 7; r=r+1 {
        result |= (i << u64(fl+r*8))
        if(block & (i << u64(fl+r*8)) != 0) do break
    }
    for r := rk-1; r >= 0; r=r-1 {
        result |= (i << u64(fl+r*8))
        if(block & (i << u64(fl+r*8)) != 0) do break
    }
    for f := fl+1; f <= 7; f=f+1 {
        result |= (i << u64(f+rk*8))
        if(block & (i << u64(f+rk*8)) != 0) do break
    }
    for f := fl-1; f >= 0; f=f-1 {
        result |= (i << u64(f+rk*8))
        if(block & (i << u64(f+rk*8)) != 0) do break
    }
    return result
}

batt :: proc(sq : int, block : BitBoard) -> BitBoard {
    result, i : BitBoard = 0, 1
    rk, fl : int = sq/8, sq%8
    for r, f := rk+1, fl+1; r <= 7 && f <= 7; r, f = r+1, f+1 {
        result |= (i << u64(f+r*8))
        if(block & (i << u64(f+r*8)) != 0) do break
    }
    for r, f := rk+1, fl-1; r <= 7 && f >= 0; r, f = r+1, f-1 {
        result |= (i << u64(f+r*8))
        if(block & (i << u64(f+r*8)) != 0) do break
    }
    for r, f := rk-1, fl+1; r >= 0 && f <= 7; r, f = r-1, f+1 {
        result |= (i << u64(f+r*8))
        if(block & (i << u64(f+r*8)) != 0) do break
    }
    for r, f := rk-1, fl-1; r >= 0 && f >= 0; r, f = r-1, f-1 {
        result |= (i << u64(f+r*8))
        if(block & (i << u64(f+r*8)) != 0) do break
    }

    return result
}

transform :: proc(b : BitBoard, magic : BitBoard, bits : int) -> int {
    return int((b*magic) >> u64(64 - bits))
}

find_magic :: proc(sq : int, m : int, bishop : bool) -> BitBoard {
    mask, magic : BitBoard
    b, a, used : [4096]BitBoard
    i, j, k, n : int
    fail : bool

    mask = bishop ? bmask(sq) : rmask(sq)
    n = count_ones(mask)

    for i = 0; i < (1 << u64(n)); i=i+1 {
        b[i] = index_to_bb(i, n, mask)
        a[i] = bishop ? batt(sq, b[i]) : ratt(sq, b[i])
    }
    for k = 0; k < 100000000; k=k+1 {
        magic = random_u64_fewbits()
        if(count_ones((mask * magic) & 0xFF00000000000000) < 6) do continue
        for i = 0; i < 4096; i=i+1 do used[i] = 0
        for i, fail = 0, false; !fail && i < (1 << u64(n)); i=i+1 {
            j = transform(b[i], magic, m)
            if(used[j] == 0) do used[j] = a[i]
            else if(used[j] != a[i]) do fail = true
        }
        if !fail do return magic
    }
    fmt.println("***Failed***")
    return 0
}

RBits := [64]int{
    12, 11, 11, 11, 11, 11, 11, 12,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    12, 11, 11, 11, 11, 11, 11, 12,
}
  
  BBits := [64]int{
    6, 5, 5, 5, 5, 5, 5, 6,
    5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 7, 7, 7, 7, 5, 5,
    5, 5, 7, 9, 9, 7, 5, 5,
    5, 5, 7, 9, 9, 7, 5, 5,
    5, 5, 7, 7, 7, 7, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5,
    6, 5, 5, 5, 5, 5, 5, 6,
}

generate_magics :: proc() {
    square : int
    magic_val : BitBoard

    fmt.println("RMagic = ")
    for square = 0; square < 64; square += 1 {
        magic_val = find_magic(square, RBits[square], false)
        fmt.println(square, ": ", magic_val)
    }
    fmt.println("BMagic = ")
    for square = 0; square < 64; square += 1 {
        magic_val = find_magic(square, BBits[square], true)
        fmt.println(square, ": ", magic_val)
    }
}
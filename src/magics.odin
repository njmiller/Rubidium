package main

import "core:fmt"
import "core:math/bits"
import "core:math/rand"
import "base:runtime"

//Shifts are equal to the number of bits needed to describe
//all the possible permutations for the occupancy. 
magic_rook_shifts := [64]int {
	12,
	11,
	11,
	11,
	11,
	11,
	11,
	12,
	11,
	10,
	10,
	10,
	10,
	10,
	10,
	11,
	11,
	10,
	10,
	10,
	10,
	10,
	10,
	11,
	11,
	10,
	10,
	10,
	10,
	10,
	10,
	11,
	11,
	10,
	10,
	10,
	10,
	10,
	10,
	11,
	11,
	10,
	10,
	10,
	10,
	10,
	10,
	11,
	11,
	10,
	10,
	10,
	10,
	10,
	10,
	11,
	12,
	11,
	11,
	11,
	11,
	11,
	11,
	12,
}

magic_bishop_shifts := [64]int {
	6,
	5,
	5,
	5,
	5,
	5,
	5,
	6,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	7,
	7,
	7,
	7,
	5,
	5,
	5,
	5,
	7,
	9,
	9,
	7,
	5,
	5,
	5,
	5,
	7,
	9,
	9,
	7,
	5,
	5,
	5,
	5,
	7,
	7,
	7,
	7,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	5,
	6,
	5,
	5,
	5,
	5,
	5,
	5,
	6,
}

//Taken from Avalanche source code, will modify with my own later on.
magic_rook_numbers := [64]u64 {
	0xA180022080400230,
	0x0040100040022000,
	0x0080088020001002,
	0x0080080280841000,
	0x4200042010460008,
	0x04800A0003040080,
	0x0400110082041008,
	0x008000A041000880,
	0x10138001A080C010,
	0x0000804008200480,
	0x00010011012000C0,
	0x0022004128102200,
	0x000200081201200C,
	0x202A001048460004,
	0x0081000100420004,
	0x4000800380004500,
	0x0000208002904001,
	0x0090004040026008,
	0x0208808010002001,
	0x2002020020704940,
	0x8048010008110005,
	0x6820808004002200,
	0x0A80040008023011,
	0x00B1460000811044,
	0x4204400080008EA0,
	0xB002400180200184,
	0x2020200080100380,
	0x0010080080100080,
	0x2204080080800400,
	0x0000A40080360080,
	0x02040604002810B1,
	0x008C218600004104,
	0x8180004000402000,
	0x488C402000401001,
	0x4018A00080801004,
	0x1230002105001008,
	0x8904800800800400,
	0x0042000C42003810,
	0x008408110400B012,
	0x0018086182000401,
	0x2240088020C28000,
	0x001001201040C004,
	0x0A02008010420020,
	0x0010003009010060,
	0x0004008008008014,
	0x0080020004008080,
	0x0282020001008080,
	0x50000181204A0004,
	0x48FFFE99FECFAA00,
	0x48FFFE99FECFAA00,
	0x497FFFADFF9C2E00,
	0x613FFFDDFFCE9200,
	0xFFFFFFE9FFE7CE00,
	0xFFFFFFF5FFF3E600,
	0x0010301802830400,
	0x510FFFF5F63C96A0,
	0xEBFFFFB9FF9FC526,
	0x61FFFEDDFEEDAEAE,
	0x53BFFFEDFFDEB1A2,
	0x127FFFB9FFDFB5F6,
	0x411FFFDDFFDBF4D6,
	0x0801000804000603,
	0x0003FFEF27EEBE74,
	0x7645FFFECBFEA79E,
}

magic_bishop_numbers := [64]u64 {
	0xFFEDF9FD7CFCFFFF,
	0xFC0962854A77F576,
	0x5822022042000000,
	0x2CA804A100200020,
	0x0204042200000900,
	0x2002121024000002,
	0xFC0A66C64A7EF576,
	0x7FFDFDFCBD79FFFF,
	0xFC0846A64A34FFF6,
	0xFC087A874A3CF7F6,
	0x1001080204002100,
	0x1810080489021800,
	0x0062040420010A00,
	0x5028043004300020,
	0xFC0864AE59B4FF76,
	0x3C0860AF4B35FF76,
	0x73C01AF56CF4CFFB,
	0x41A01CFAD64AAFFC,
	0x040C0422080A0598,
	0x4228020082004050,
	0x0200800400E00100,
	0x020B001230021040,
	0x7C0C028F5B34FF76,
	0xFC0A028E5AB4DF76,
	0x0020208050A42180,
	0x001004804B280200,
	0x2048020024040010,
	0x0102C04004010200,
	0x020408204C002010,
	0x02411100020080C1,
	0x102A008084042100,
	0x0941030000A09846,
	0x0244100800400200,
	0x4000901010080696,
	0x0000280404180020,
	0x0800042008240100,
	0x0220008400088020,
	0x04020182000904C9,
	0x0023010400020600,
	0x0041040020110302,
	0xDCEFD9B54BFCC09F,
	0xF95FFA765AFD602B,
	0x1401210240484800,
	0x0022244208010080,
	0x1105040104000210,
	0x2040088800C40081,
	0x43FF9A5CF4CA0C01,
	0x4BFFCD8E7C587601,
	0xFC0FF2865334F576,
	0xFC0BF6CE5924F576,
	0x80000B0401040402,
	0x0020004821880A00,
	0x8200002022440100,
	0x0009431801010068,
	0xC3FFB7DC36CA8C89,
	0xC3FF8A54F4CA2C89,
	0xFFFFFCFCFD79EDFF,
	0xFC0863FCCB147576,
	0x040C000022013020,
	0x2000104000420600,
	0x0400000260142410,
	0x0800633408100500,
	0xFC087E8E4BB2F736,
	0x43FF9E4EF4CA2C89,
}

// Total attack entries over all squares: sum of 1 << bits for each square
ROOK_ATTACK_TABLE_SIZE :: 102400
BISHOP_ATTACK_TABLE_SIZE :: 5248

magic_table :: struct {
	mask:    BitBoard,
	magic:   u64,
	shift:   uint,       // right shift that leaves the index: 64 - number of index bits
	attacks: []BitBoard, // this square's section of rook_attacks/bishop_attacks
}

magic_bishop_table: [64]magic_table
magic_rook_table: [64]magic_table

rook_attacks: [ROOK_ATTACK_TABLE_SIZE]BitBoard
bishop_attacks: [BISHOP_ATTACK_TABLE_SIZE]BitBoard

magic_index :: #force_inline proc(m: ^magic_table, occupancy: BitBoard) -> u64 {
	return (u64(occupancy & m.mask) * m.magic) >> m.shift
}

//The magic tables are global and used by every part of the engine and by any
//test that runs move generation, so they are built exactly once at startup.
//The test runner executes tests on multiple threads, so per-test init/free of
//these tables would race
@(init)
init_magic_tables_startup :: proc "contextless" () {
	context = runtime.default_context()

	rook_offset, bishop_offset := 0, 0
	for sq in 0 ..< 64 {
		rook_offset += init_slider_magic(&magic_rook_table[sq], rook_attacks[:], rook_offset, sq, true)
		bishop_offset += init_slider_magic(&magic_bishop_table[sq], bishop_attacks[:], bishop_offset, sq, false)
	}
	assert(rook_offset == ROOK_ATTACK_TABLE_SIZE && bishop_offset == BISHOP_ATTACK_TABLE_SIZE)
}

//Should be same as rmask and bmask (though input differs by 1, i.e. this code starts at sq=1, while
//rmask and bmask start at 0)
get_bishop_mask :: proc(sq: int) -> BitBoard {
	rank, file: int = sq_to_rank_file(sq)
	RANKS: [8]BitBoard = {RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8}
	FILES: [8]BitBoard = {FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H}
	edge_mask: BitBoard = ((RANK_1 | RANK_8) & ~RANKS[rank]) | ((FILE_A | FILE_H) & ~FILES[file])
	return init_slider_move(sq, BitBoard(0), false) & ~edge_mask
}

get_rook_mask :: proc(sq: int) -> BitBoard {
	rank, file: int = sq_to_rank_file(sq)
	RANKS: [8]BitBoard = {RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8}
	FILES: [8]BitBoard = {FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H}
	edge_mask: BitBoard = ((RANK_1 | RANK_8) & ~RANKS[rank]) | ((FILE_A | FILE_H) & ~FILES[file])
	return init_slider_move(sq, BitBoard(0), true) & ~edge_mask
}

//Fill one square's magic entry, using backing[offset:] for its attack table.
//Returns the number of entries used so the caller can advance the offset
init_slider_magic :: proc(m: ^magic_table, backing: []BitBoard, offset: int, sq: int, is_rook: bool) -> int {
	bits := is_rook ? magic_rook_shifts[sq] : magic_bishop_shifts[sq]
	count := 1 << uint(bits)

	m.mask = is_rook ? get_rook_mask(sq) : get_bishop_mask(sq)
	m.magic = is_rook ? magic_rook_numbers[sq] : magic_bishop_numbers[sq]
	m.shift = uint(64 - bits)
	m.attacks = backing[offset:offset + count]

	//Every occupancy subset of the mask maps to an index. A valid magic only
	//lets subsets with the same attack set share an index
	for i in 0 ..< count {
		occupancy := index_to_bb(i, bits, m.mask)
		m.attacks[magic_index(m, occupancy)] = init_slider_move(sq, occupancy, is_rook)
	}

	return count
}


random_u64_fewbits :: proc() -> u64 {
	// return rand.uint64(a2) & rand.uint64(a2) & rand.uint64(a2)
	return rand.uint64() & rand.uint64() & rand.uint64()
}

index_to_bb :: proc(index: int, bits: int, m: BitBoard) -> BitBoard {
	// i, j: int
	mp: BitBoard = m
	result: BitBoard = 0
	for i in 0 ..< bits {
		j := pop_first_bit(&mp)
		if (index & (1 << u64(i)) != 0) {
			result = result | (1 << u64(j))
		}
	}
	return result
}

//This just calculates the hash
transform :: proc(b: BitBoard, magic: u64, bits: int) -> int {
	return int((u64(b) * magic) >> u64(64 - bits))
}

find_magic :: proc(sq: int, m: int, bishop: bool) -> u64 {
	magic: u64
	b, a, used: [4096]BitBoard
	i2: int
	fail: bool

	mask := bishop ? get_bishop_mask(sq) : get_rook_mask(sq)
	n := bishop ? magic_bishop_shifts[sq] : magic_rook_shifts[sq]
	nperm := int(1 << uint(n))


	//Loop over all permutations for this square and calculate the moves for each
	//permutation
	for i in 0 ..< nperm {
		b[i] = index_to_bb(i, n, mask)
		a[i] = init_slider_move(sq, b[i], !bishop)
	}

	//Randomly determine a magic number and check to see if it is valid
	//(i.e. if permutations with different sets of valid moves have the same hash, 
	//then it is not a valid magic number)
	//If it is not valid, try again. We keep trying until we find a valid magic number.
	//The limit on the number of tries is large enough so that we should always find a magic number
	for _ in 0 ..< 100000000 {
		magic = random_u64_fewbits()
		//if (count_ones_u64((u64(mask) * magic) & 0xFF00000000000000) < 6) do continue
		if (bits.count_ones((u64(mask) * magic) & 0xFF00000000000000) < 6) do continue
		for i in 0 ..< 4096 do used[i] = 0
		for i2, fail = 0, false; !fail && i2 < nperm; i2 = i2 + 1 {
			j := transform(b[i2], magic, m)
			if (used[j] == 0) do used[j] = a[i2]
			else if (used[j] != a[i2]) do fail = true
		}
		if !fail do return magic
	}
	fmt.println("***Failed***")
	return 0
}

generate_magics :: proc() {	
	fmt.println("RMagic = ")
	for square in 0 ..< 64 {
		magic_val2 := find_magic(square, magic_rook_shifts[square], false)
		fmt.println(square, ": ", magic_val2)
	}

	fmt.println("BMagic = ")
	for square in 0 ..< 64 {
		magic_val2 := find_magic(square, magic_bishop_shifts[square], true)
		fmt.println(square, ": ", magic_val2)
	}
}

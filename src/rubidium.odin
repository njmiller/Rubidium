package main

import "core:bufio"
import "core:fmt"
import "core:flags"
import "core:os"

main_uci :: proc() {
	defer stop_search()

	s: bufio.Scanner

	bufio.scanner_init(&s, os.to_stream(os.stdin))
	defer bufio.scanner_destroy(&s)

	tt_resize(64)

	for bufio.scanner_scan(&s) {
		line := bufio.scanner_text(&s)
		if !read_uci_gui(line) do break

		// Move this inside handle_position???
		free_all(context.temp_allocator)
	}

	return
}

main :: proc() {
	if len(os.args) < 2 {
		main_uci()
		os.exit(0)
	}

	switch os.args[1] {
		case "perft":
			Perft_Options :: struct {
				fen:   string `args:"pos=0,required" usage:"FEN string (quote it)."`,
				depth: int    `args:"pos=1,required" usage:"Search depth"`,
			}
			opts: Perft_Options
			flags.parse_or_exit(&opts, os.args[1:], .Unix)
			run_perft(opts.fen, opts.depth)
		case "tune":
			when TUNE {
				Tune_Options :: struct {
					data:   string `args:"pos=0,required" usage:"Quiet positions with game results, one per line"`,
					epochs: int    `usage:"Gradient descent passes over the data"`,
					lr:     f64    `usage:"Adam learning rate, in centipawns per step"`,
				}
				opts := Tune_Options{epochs = 2000, lr = 1.0}
				flags.parse_or_exit(&opts, os.args[1:], .Unix)
				run_tune(opts.data, opts.epochs, opts.lr)
			} else {
				fmt.eprintln("Build with -define:TUNE=true to tune")
				os.exit(1)
			}
		case:
			fmt.println("Bad option")
			os.exit(1)
	}
}

module main

import os
import src

// Entry point: displays grammar, prompts for input, runs derivation and shows parse tree
fn main() {
	for {
		// Clear screen if supported: skipping to maximize portability
		print_grammar()
		input_str := os.input('Enter a string to recognize (or type END to quit): ').trim_space()
		if input_str.to_upper() == 'END' {
			println('\nGoodbye!\n')
			return
		}

		// Lex + Parse + Derivation
	mut lexer := src.new_lexer(input_str)
	tokens, lex_err := lexer.lex_all()
		if lex_err.len > 0 {
			// Report first lexical error (display all lines below if multiple)
			println('\nDerivation unsuccessful (lexical error):')
			for e in lex_err {
				println('Error: ' + e)
			}
			_ = os.input('\nPress Enter to continue...')
			continue
		}

	mut parser := src.new_parser(tokens)
	root, derivation, perr := parser.parse_graph_with_derivation()
		if perr.len > 0 {
			println('\nDerivation unsuccessful (syntax error):')
			for e in perr {
				println('Error: ' + e)
			}
			_ = os.input('\nPress Enter to continue...')
			continue
		}

		// Success: show derivation steps and the final generated sentence
		println('\nLEFTMOST DERIVATION:')
		formatted_derivation := src.format_derivation(derivation)
		for s in formatted_derivation {
			println(s)
		}
		// Final sentence
	final_sentence := src.tokens_to_sentence(tokens)
		println('\nFinal generated sentence: ' + final_sentence)
		println('\nThe string is ACCEPTED by the grammar.')
		_ = os.input('\nPress Enter to show the parse tree...')

		// Draw parse tree
		println('\nPARSE TREE:')
	println(src.render_tree(root))
		_ = os.input('\nPress Enter to continue...')
	}
}

// Prints the grammar in BNF form
fn print_grammar() {
	println('\nLANGUAGE RECOGNIZER — Grammar (BNF)')
	println('------------------------------------')
	println('<graph>   →    HI <draw> BYE')
	println('<draw>    →    <action>')
	println('             | <action> ; <draw>')
	println('<action>  →    bar <x><y>,<y>')
	println('             | line <x><y>,<x><y>')
	println('             | fill <x><y>')
	println('<x>       →    A | B | C | D | E')
	println('<y>       →    1 | 2 | 3 | 4 | 5\n')
	println('Examples of accepted strings:')
	println('  HI bar D2,5; fill A2; line B4,D2 BYE\n')
}
module main

import os
import src

/* V Language Recognizer - Main Entry Point
 * 
 * This program implements a language recognizer for a simple drawing command grammar
 * It performs lexical analysis, parsing, and generates leftmost derivations with parse trees
 * 
 * Grammar structure:
 * - <graph>   → HI <draw> BYE
 * - <draw>    → <action> | <action> ; <draw>
 * - <action>  → bar <x><y>,<y> | line <x><y>,<x><y> | fill <x><y>
 * - <x>       → A | B | C | D | E
 * - <y>       → 1 | 2 | 3 | 4 | 5 */
fn main() {
	// Main program loop - continues until user types 'END'
	for {
		// Display the grammar rules for user reference
		print_grammar()
		
		// Get user input and normalize by trimming whitespace
		input_str := os.input('Enter a string to recognize (END to quit): ').trim_space()
		
		// Check for exit condition (case-insensitive)
		if input_str.to_upper() == 'END' {
			println('\n╔══════════════════════════════════════╗')
			println('║                                      ║')
			println('║              GOODBYE!                ║')
			println('║                                      ║')
			println('║      Thank you for using the         ║')
			println('║       V Language Recognizer!         ║')
			println('║                                      ║')
			println('╚══════════════════════════════════════╝\n')
			return
		}

		// PHASE 1: LEXICAL ANALYSIS
		// Create lexer instance and tokenize the input string
		mut lexer := src.new_lexer(input_str)
		tokens, lex_err := lexer.lex_all()
		
		// Handle lexical errors (invalid tokens, unrecognized symbols, etc.)
		if lex_err.len > 0 {
			println('\nDerivation unsuccessful (lexical error):')
			// Display all lexical errors found during tokenization
			for e in lex_err {
				println('Error: ' + e)
			}
			_ = os.input('\nPress Enter to continue...')
			continue
		}

		// PHASE 2: SYNTAX ANALYSIS & DERIVATION GENERATION
		// Create parser with tokenized input and attempt to parse according to grammar
		mut parser := src.new_parser(tokens)
		root, derivation, perr := parser.parse_graph_with_derivation()
		
		// Handle syntax errors (grammar violations, unexpected tokens, etc.)
		if perr.len > 0 {
			println('\nDerivation unsuccessful (syntax error):')
			// Display all parsing errors encountered
			for e in perr {
				println('Error: ' + e)
			}
			_ = os.input('\nPress Enter to continue...')
			continue
		}

		// PHASE 3: SUCCESS - DISPLAY RESULTS
		// Display Success Message
		println('\nThe input string was successfully recognized!')

		// Show the leftmost derivation steps that led to acceptance
		println('\n╔══════════════════════════════════════╗')
		println('║          LEFTMOST DERIVATION         ║')
		println('╚══════════════════════════════════════╝')
		formatted_derivation := src.format_derivation(derivation)
		for s in formatted_derivation {
			println(s)
		}
		
		_ = os.input('\nPress Enter to view the Parse Tree...')

		// PHASE 4: PARSE TREE VISUALIZATION
		// Display the hierarchical structure of the parsed input
		println('\n╔══════════════════════════════════════╗')
		println('║              PARSE TREE              ║')
		println('╚══════════════════════════════════════╝')
		println(src.render_tree(root))
		_ = os.input('\nPress Enter to continue...')
	}
}

/* Display the grammar rules in Backus-Naur Form (BNF)
 * Shows the formal grammar definition and provides examples of valid strings
 * This helps users understand what input formats are acceptable */
fn print_grammar() {
	println('\n╔════════════════════════════════════════════════════════╗')
	println('║                  V LANGUAGE RECOGNIZER                 ║')
	println('║                     FOR BNF GRAMMAR                    ║')
	println('╠════════════════════════════════════════════════════════╣')
	println('║                                                        ║')
	println('║           <graph>   →    HI <draw> BYE                 ║')
	println('║           <draw>    →    <action>                      ║')
	println('║                          | <action> ; <draw>           ║')
	println('║           <action>  →    bar <x><y>,<y>                ║')
	println('║                          | line <x><y>,<x><y>          ║')
	println('║                          | fill <x><y>                 ║')
	println('║           <x>       →    A | B | C | D | E             ║')
	println('║           <y>       →    1 | 2 | 3 | 4 | 5             ║')
	println('║                                                        ║')
	println('╠════════════════════════════════════════════════════════╣')
	println('║                        EXAMPLE:                        ║')
	println('║                                                        ║')
	println('║       ↳ HI bar D2,5; fill A2; line B4,D2 BYE           ║')
	println('║                                                        ║')
	println('╚════════════════════════════════════════════════════════╝')
	println('')
}
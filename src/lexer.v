module src

/* Lexical Analyzer Module
 * 
 * This module implements tokenization for the drawing command language
 * It converts raw input strings into a sequence of tokens that can be parsed
 * 
 * The lexer handles:
 * - Keywords (HI, BYE, bar, line, fill)
 * - Variables (A-E for X coordinates, 1-5 for Y coordinates)
 * - Punctuation (comma, semicolon)
 * - Error detection for invalid symbols and out-of-range values */

/* Token Types - All possible token kinds in the grammar
 * 
 * Each token represents a terminal symbol in the grammar or special markers */
pub enum TokenKind {
	hi      // Start keyword "HI"
	bye     // End keyword "BYE"
	bar     // Action keyword "bar" - draws a vertical bar
	line    // Action keyword "line" - draws a line between two points
	fill    // Action keyword "fill" - fills a position
	xletter // X coordinate variables: A, B, C, D, E
	ydigit  // Y coordinate values: 1, 2, 3, 4, 5
	comma   // Separator "," between coordinates
	semicol // Statement separator ";" between actions
	eof     // End of file marker
}

/* Token Structure
 * 
 * Represents a single lexical unit with its type, literal value, and position
 * Used by the parser to understand the structure of the input */
pub struct Token {
	pub:
		kind TokenKind // The type of token (keyword, variable, punctuation, etc.)
		lit  string    // The actual text from the input (e.g., "HI", "A", ",")
		pos  int       // Character position in original string (0-based indexing)
}

/* Lexical Analyzer (Tokenizer)
 * 
 * Processes input character by character to identify tokens
 * Maintains current position and handles whitespace, keywords, and symbols */
pub struct Lexer {
	input string // The complete input string to tokenize
	mut:
		i int    // Current character position (mutable for advancing through input)
}

// Create a new lexer instance
pub fn new_lexer(input string) Lexer {
	return Lexer{ input: input, i: 0 }
}

// Check if lexer has reached end of input
pub fn (mut l Lexer) eof() bool { return l.i >= l.input.len }

/* Peek at the next character without advancing position
 * Used for lookahead to provide better error messages
 */
fn (l &Lexer) get_next_char() string {
	if l.i + 1 < l.input.len {
		return l.input[l.i + 1..l.i + 2]
	}
	return ''
}

// Character classification functions for lexical analysis

/* Check if character is whitespace (space, tab, newline, carriage return) */
fn is_space(c u8) bool { return c == ` ` || c == `\t` || c == `\n` || c == `\r` }

/* Check if character is a valid X coordinate variable (A-E) */
fn is_xletter(c u8) bool { return c >= `A` && c <= `E` }

/* Check if character is a valid Y coordinate digit (1-5) */
fn is_ydigit(c u8) bool { return c >= `1` && c <= `5` }

/* Main tokenization function
 * 
 * Processes the entire input string and converts it into tokens.
 * Handles all valid grammar symbols and detects various error conditions.
 * 
 * Error detection includes:
 * - Invalid variable names (letters outside A-E range)
 * - Invalid coordinate values (digits outside 1-5 range)
 * - Unrecognized symbols and punctuation
 * - Invalid action keywords */
pub fn (mut l Lexer) lex_all() ([]Token, []string) {
	mut tokens := []Token{}   // Accumulator for valid tokens
	mut errors := []string{}  // Accumulator for error messages
	
	// Main tokenization loop - process each character
	for !l.eof() {
		c := l.input[l.i]        // Current character
		
		// Skip whitespace characters
		if is_space(c) {
			l.i++
			continue
		}
		
		start := l.i             // Remember start position for error reporting
		// ALPHABETIC CHARACTERS: Keywords, actions, and variables
		// Process sequences of letters (both uppercase and lowercase)
		if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) {
			word_start := l.i
			mut word_end := l.i
			
			// Read the complete word (sequence of letters)
			for !l.eof() {
				ch := l.input[word_end]
				if (ch >= `A` && ch <= `Z`) || (ch >= `a` && ch <= `z`) {
					word_end++
				} else {
					break  // Stop at first non-letter
				}
				if word_end >= l.input.len { break }
			}
			
			word := l.input[word_start..word_end]  // Extract the complete word
			wlow := word.to_lower()               // Convert to lowercase for comparison
			// Match against known keywords (case-insensitive)
			match wlow {
				'hi' {   // Program start marker
					tokens << Token{ kind: .hi, lit: word, pos: word_start }
					l.i = word_end
				}
				'bye' {  // Program end marker
					tokens << Token{ kind: .bye, lit: word, pos: word_start }
					l.i = word_end
				}
				'bar' {  // Draw vertical bar action
					tokens << Token{ kind: .bar, lit: word, pos: word_start }
					l.i = word_end
				}
				'line' { // Draw line between points action
					tokens << Token{ kind: .line, lit: word, pos: word_start }
					l.i = word_end
				}
				'fill' { // Fill position action
					tokens << Token{ kind: .fill, lit: word, pos: word_start }
					l.i = word_end
				}
				else {   // Not a keyword - check if it's a valid variable or error
					// Check if it's a valid X coordinate variable (single letter A-E)
					if word.len == 1 && is_xletter(word[0]) {
						tokens << Token{ kind: .xletter, lit: word, pos: word_start }
						l.i = word_end
					} else if word.len == 1 && (word[0] >= `A` && word[0] <= `Z`) {
						// Single uppercase letter but outside valid X range (not A-E)
						// Provide context-aware error messages
						next_char := l.get_next_char()
						if next_char.len > 0 && (next_char[0] >= `0` && next_char[0] <= `9`) {
							// Invalid variable followed by digit (e.g., "F3")
							errors << "${word}${next_char} contains an error - variable '${word}' is not valid"
						} else {
							// Invalid variable not followed by digit
							errors << "${word} contains an error - variable '${word}' should be A-E and followed by a digit 1-5"
						}
						l.i = word_end
					} else {
						// Multi-character word that's not a keyword = invalid action
						errors << "action '${word}' not valid"
						l.i = word_end
					}
				}
			}
			// Position is already updated in each match branch above
			continue
		}

		// PUNCTUATION CHARACTERS
		// Handle grammar separators and delimiters
		if c == `,` {
			// Comma separates coordinate pairs (e.g., "A1,B2")
			tokens << Token{ kind: .comma, lit: ',', pos: start }
			l.i++
			continue
		}
		if c == `;` {
			// Semicolon separates multiple actions
			tokens << Token{ kind: .semicol, lit: ';', pos: start }
			l.i++
			continue
		}
		
		// VALID Y COORDINATE DIGITS (1-5)
		if is_ydigit(c) {
			tokens << Token{ kind: .ydigit, lit: l.input[l.i..l.i+1], pos: start }
			l.i++
			continue
		}

		// INVALID DIGITS AND NUMERIC SEQUENCES
		// Handle digits that are outside the valid Y coordinate range
		if c >= `0` && c <= `9` {
			// Digits 6-9 are invalid Y coordinates
			if c >= `6` && c <= `9` {
				// Provide context-aware error messages
				if l.i > 0 && ((l.input[l.i-1] >= `A` && l.input[l.i-1] <= `Z`) || (l.input[l.i-1] >= `a` && l.input[l.i-1] <= `z`)) {
					// Invalid digit following a letter (e.g., "A7")
					errors << "${l.input[l.i-1..l.i+1]} contains an error - value '${l.input[l.i..l.i+1]}' is not valid"
				} else {
					// Standalone invalid digit
					errors << "${l.input[l.i..l.i+1]} contains an error - value '${l.input[l.i..l.i+1]}' is not valid"
				}
				l.i++
				continue
			}
			
			// Handle digit 0 and multi-digit numbers (also invalid)
			dstart := l.i
			mut dend := l.i+1
			// Collect the complete numeric sequence
			for dend < l.input.len && (l.input[dend] >= `0` && l.input[dend] <= `9`) {
				dend++
			}
			val := l.input[dstart..dend]
			errors << "${val} contains the unrecognized value ${val}"
			l.i = dend
			continue
		}

		// UNRECOGNIZED SYMBOLS
		// Any character that doesn't fit the grammar
		errors << "${l.input[l.i..l.i+1]} contains an error - symbol '${l.input[l.i..l.i+1]}' not valid"
		l.i++
	}
	
	// Add end-of-file marker to complete the token stream
	tokens << Token{ kind: .eof, lit: '', pos: l.input.len }
	return tokens, errors
}


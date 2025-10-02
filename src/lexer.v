module src

/* Lexical Analyzer Module
 * 
 * This module implements tokenization for the drawing command language
 * It converts raw input strings into a sequence of tokens that can be parsed
 *  The lexer handles:
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
	bar     // Action keyword "bar"
	line    // Action keyword "line"
	fill    // Action keyword "fill"
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

/* Check if character is a valid X coordinate variable (A-E, case insensitive) */
fn is_xletter(c u8) bool { 
	// Normalize to uppercase for consistent checking
	ch_upper := if c >= `a` && c <= `z` { c - 32 } else { c }
	return ch_upper >= `A` && ch_upper <= `E`
}

/* Check if character is a valid Y coordinate digit (1-5) */
fn is_ydigit(c u8) bool { return c >= `1` && c <= `5` }

/* Error Information Structure
 * 
 * Stores detailed information about lexical errors for intelligent grouping */
struct ErrorInfo {
	pos int           // Position in input string
	error_type string // Type of error ('invalid_y', 'invalid_x', 'unrecognized', etc.)
	value string      // The problematic value
	context string    // Surrounding context
}

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
	mut raw_errors := []ErrorInfo{}  // Detailed error information for grouping
	
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
				// Normalize to uppercase for consistent checking
				ch_upper := if ch >= `a` && ch <= `z` { ch - 32 } else { ch }
				if ch_upper >= `A` && ch_upper <= `Z` {
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
					// Normalize to uppercase for consistent display
					tokens << Token{ kind: .hi, lit: 'HI', pos: word_start }
					l.i = word_end
				}
				'bye' {  // Program end marker
					// Normalize to uppercase for consistent display
					tokens << Token{ kind: .bye, lit: 'BYE', pos: word_start }
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
					// Check if it's a valid X coordinate variable (single letter A-E, case insensitive)
					if word.len == 1 && is_xletter(word[0]) {
						// Normalize to uppercase for consistent storage
						normalized_lit := word.to_upper()
						tokens << Token{ kind: .xletter, lit: normalized_lit, pos: word_start }
						l.i = word_end
					} else if word.len == 1 {
						// Normalize character for checking
						ch := word[0]
						ch_upper := if ch >= `a` && ch <= `z` { ch - 32 } else { ch }
						if ch_upper >= `A` && ch_upper <= `Z` {
							// Single letter but outside valid X range (not A-E)
							// Provide context-aware error messages
							next_char := l.get_next_char()
							if next_char.len > 0 && (next_char[0] >= `0` && next_char[0] <= `9`) {
								// Invalid variable followed by digit (e.g., "F3" or "f3")
								raw_errors << ErrorInfo{
									pos: word_start
									error_type: 'invalid_x_with_digit'
									value: word.to_upper()
									context: "${word}${next_char}"
								}
							} else {
								// Invalid variable not followed by digit
								raw_errors << ErrorInfo{
									pos: word_start
									error_type: 'invalid_x_standalone'
									value: word.to_upper()
									context: word
								}
							}
						}
						l.i = word_end
					} else {
						// Multi-character word that's not a keyword = invalid action
						raw_errors << ErrorInfo{
							pos: word_start
							error_type: 'invalid_action'
							value: word
							context: word
						}
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
				// Collect detailed error information for intelligent grouping
				if l.i > 0 && ((l.input[l.i-1] >= `A` && l.input[l.i-1] <= `Z`) || (l.input[l.i-1] >= `a` && l.input[l.i-1] <= `z`)) {
					// Invalid digit following a letter (e.g., "A7")
					raw_errors << ErrorInfo{
						pos: l.i - 1
						error_type: 'invalid_y_after_x'
						value: l.input[l.i..l.i+1]
						context: l.input[l.i-1..l.i+1]
					}
				} else {
					// Standalone invalid digit
					raw_errors << ErrorInfo{
						pos: l.i
						error_type: 'invalid_y_standalone'
						value: l.input[l.i..l.i+1]
						context: l.input[l.i..l.i+1]
					}
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
			raw_errors << ErrorInfo{
				pos: dstart
				error_type: 'unrecognized_value'
				value: val
				context: val
			}
			l.i = dend
			continue
		}

		// UNRECOGNIZED SYMBOLS
		// Any character that doesn't fit the grammar
		raw_errors << ErrorInfo{
			pos: l.i
			error_type: 'unrecognized_symbol'
			value: l.input[l.i..l.i+1]
			context: l.input[l.i..l.i+1]
		}
		l.i++
	}
	
	// Add end-of-file marker to complete the token stream
	tokens << Token{ kind: .eof, lit: '', pos: l.input.len }
	
	// Process raw errors to group related coordinate errors
	errors = l.process_errors(raw_errors)
	
	return tokens, errors
}

/* Process raw errors to group related coordinate errors
 * 
 * This function analyzes the collected error information and groups
 * related Y-coordinate errors in coordinate sequences (e.g., "d9,8") */
fn (l &Lexer) process_errors(raw_errors []ErrorInfo) []string {
	mut processed := []string{}
	mut i := 0
	
	for i < raw_errors.len {
		error := raw_errors[i]
		
		// Check if this is an invalid Y coordinate that might be part of a sequence
		if error.error_type in ['invalid_y_after_x', 'invalid_y_standalone'] {
			// Look ahead to see if there are more Y coordinate errors in a sequence
			mut grouped_errors := [error]
			mut j := i + 1
			
			// Collect consecutive Y coordinate errors that form a sequence
			for j < raw_errors.len {
				next_error := raw_errors[j]
				
				// Check if next error is also an invalid Y and part of the same coordinate sequence
				if next_error.error_type in ['invalid_y_after_x', 'invalid_y_standalone'] {
					// Simple heuristic: if positions are close together (within 3 characters)
					// they're likely part of the same coordinate sequence
					if next_error.pos - grouped_errors.last().pos <= 3 {
						grouped_errors << next_error
						j++
					} else {
						break
					}
				} else {
					break
				}
			}
			
			// Generate appropriate error message
			if grouped_errors.len > 1 {
				// Multiple Y coordinate errors - group them
				mut invalid_values := []string{}
				mut start_pos := grouped_errors[0].pos
				mut end_pos := grouped_errors.last().pos + grouped_errors.last().value.len
				
				for err in grouped_errors {
					invalid_values << "'${err.value}'"
				}
				
				context := l.input[start_pos..end_pos]
				values_str := if invalid_values.len == 2 {
					'${invalid_values[0]} and ${invalid_values[1]}'
				} else {
					invalid_values[..invalid_values.len-1].join(', ') + ' and ' + invalid_values.last()
				}
				
				processed << "${context} contains an error - <y> values ${values_str} are not valid"
				i = j  // Skip all processed errors
			} else {
				// Single Y coordinate error - use individual message
				err := grouped_errors[0]
				if err.error_type == 'invalid_y_after_x' {
					processed << "${err.context} contains an error - value '${err.value}' is not valid"
				} else {
					processed << "${err.context} contains an error - value '${err.value}' is not valid"
				}
				i++
			}
		} else {
			// Handle other error types individually
			match error.error_type {
				'invalid_x_with_digit' {
					processed << "${error.context} contains an error - variable '${error.value}' is not valid"
				}
				'invalid_x_standalone' {
					processed << "${error.context} contains an error - variable '${error.value}' should be A-E and followed by a digit 1-5"
				}
				'invalid_action' {
					processed << "action '${error.value}' not valid"
				}
				'unrecognized_value' {
					processed << "${error.value} is an unrecognized value"
				}
				'unrecognized_symbol' {
					processed << "${error.context} contains an error - symbol '${error.value}' not valid"
				}
				else {
					// Fallback for unknown error types
					processed << "${error.context} contains an error"
				}
			}
			i++
		}
	}
	
	return processed
}


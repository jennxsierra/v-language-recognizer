module src

// Token kinds
pub enum TokenKind {
	hi
	bye
	bar
	line
	fill
	xletter // A-E
	ydigit  // 1-5
	comma   // ,
	semicol // ;
	eof
}

pub struct Token {
	pub:
		kind TokenKind
		lit  string
		pos  int // index in original string (0-based)
}

// Simple lexer
pub struct Lexer {
	input string
	mut:
		i int
}

pub fn new_lexer(input string) Lexer {
	return Lexer{ input: input, i: 0 }
}

pub fn (mut l Lexer) eof() bool { return l.i >= l.input.len }

fn is_space(c u8) bool { return c == ` ` || c == `\t` || c == `\n` || c == `\r` }

fn is_xletter(c u8) bool { return c >= `A` && c <= `E` }
fn is_ydigit(c u8) bool { return c >= `1` && c <= `5` }

// Returns all tokens or lexical errors (as messages)
pub fn (mut l Lexer) lex_all() ([]Token, []string) {
	mut tokens := []Token{}
	mut errors := []string{}
	for !l.eof() {
		c := l.input[l.i]
		if is_space(c) {
			l.i++
			continue
		}
		start := l.i
		// identifiers/keywords (letters) — read the whole word first
		if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) {
			word_start := l.i
			mut word_end := l.i
			for !l.eof() {
				ch := l.input[word_end]
				if (ch >= `A` && ch <= `Z`) || (ch >= `a` && ch <= `z`) {
					word_end++
				} else {
					break
				}
				if word_end >= l.input.len { break }
			}
			word := l.input[word_start..word_end]
			wlow := word.to_lower()
			match wlow {
				'hi' {
					tokens << Token{ kind: .hi, lit: word, pos: word_start }
				}
				'bye' {
					tokens << Token{ kind: .bye, lit: word, pos: word_start }
				}
				'bar' {
					tokens << Token{ kind: .bar, lit: word, pos: word_start }
				}
				'line' {
					tokens << Token{ kind: .line, lit: word, pos: word_start }
				}
				'fill' {
					tokens << Token{ kind: .fill, lit: word, pos: word_start }
				}
				else {
					// If it's a single letter and uppercase A-E -> X token
					if word.len == 1 && is_xletter(word[0]) {
						tokens << Token{ kind: .xletter, lit: word, pos: word_start }
					} else if word.len == 1 && (word[0] >= `A` && word[0] <= `Z`) {
						// Single uppercase letter but not in valid X range (A-E)
						errors << "variable '${word}' not valid - X variables must be A, B, C, D, or E"
					} else {
						// Unknown identifier/action
						errors << "action '${word}' not valid"
					}
				}
			}
			l.i = word_end
			continue
		}

		// punctuation
		if c == `,` {
			tokens << Token{ kind: .comma, lit: ',', pos: start }
			l.i++
			continue
		}
		if c == `;` {
			tokens << Token{ kind: .semicol, lit: ';', pos: start }
			l.i++
			continue
		}
		// Y digit (1-5)
		if is_ydigit(c) {
			tokens << Token{ kind: .ydigit, lit: l.input[l.i..l.i+1], pos: start }
			l.i++
			continue
		}

		// Other characters (digits outside 1-5, punctuation, etc.)
		if c >= `0` && c <= `9` {
			// collect run of digits for better error messages
			dstart := l.i
			mut dend := l.i+1
			for dend < l.input.len && (l.input[dend] >= `0` && l.input[dend] <= `9`) {
				dend++
			}
			val := l.input[dstart..dend]
			errors << "${val} contains the unrecognized value ${val}"
			l.i = dend
			continue
		}

		// Any other symbol
		errors << "${l.input[l.i..l.i+1]} contains an error – symbol '${l.input[l.i..l.i+1]}' not valid"
		l.i++
	}
	tokens << Token{ kind: .eof, lit: '', pos: l.input.len }
	return tokens, errors
}


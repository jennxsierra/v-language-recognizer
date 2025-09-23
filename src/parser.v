module src

// Leftmost derivation parser producing a parse tree and derivation steps

// Public parse entry combines root tree, derivation, and errors
pub struct ParseResult {
	pub:
		root       &TreeNode = unsafe { nil }
		derivation []string
		errors     []string
}

pub struct Parser {
	tokens []Token
	mut:
		i int
		steps []string
}

pub fn new_parser(tokens []Token) Parser {
	return Parser{ tokens: tokens, i: 0, steps: []string{} }
}

fn (mut p Parser) at_end() bool { return p.i >= p.tokens.len }
fn (mut p Parser) peek() Token { return p.tokens[p.i] }
fn (mut p Parser) advance() Token { t := p.tokens[p.i]; p.i++; return t }

// Tokens to sentence (for final output)
pub fn tokens_to_sentence(tokens []Token) string {
	mut s := ''
	mut prev_kind := TokenKind.eof
	for t in tokens {
		if t.kind == .eof { break }
		match t.kind {
			.comma {
				s += ','
			}
			.semicol {
				s += ';'
				// add a space after semicolon if not end
				s += ' '
			}
			else {
				// add space except when joining X+Y as a single token (e.g., D2)
				if s.len > 0 && prev_kind !in [.comma, .semicol] && !(prev_kind == .xletter && t.kind == .ydigit) {
					s += ' '
				}
				s += t.lit
			}
		}
		prev_kind = t.kind
	}
	return s.trim_space()
}

// Parse with derivation steps
pub fn (mut p Parser) parse_graph_with_derivation() (&TreeNode, []string, []string) {
	p.steps = []string{}
	// Initial sentential form
	p.steps << '<graph>'
	// <graph> → HI <draw> BYE
	mut root := new_node('graph')
	mut hi_node := new_node('HI')
	mut draw_node := new_node('draw')
	mut bye_node := new_node('BYE')
	root.add_child(hi_node)
	root.add_child(draw_node)
	root.add_child(bye_node)
	p.steps << 'HI <draw> BYE'

	// expect HI
	if !p.match_kind(.hi) {
		return root, p.steps, ['Expected HI at the beginning']
	}

	// parse <draw>
	_, derrs := p.parse_draw(mut draw_node)
	if derrs.len > 0 {
		return root, p.steps, derrs
	}

	// expect BYE
	if !p.match_kind(.bye) {
		return root, p.steps, ['Expected BYE at the end']
	}

	// Ensure EOF or trailing spaces only
	if p.peek().kind != .eof {
		// collect unexpected token literal
		t := p.peek()
		return root, p.steps, ['Unexpected token ' + t.lit + ' after BYE']
	}
	return root, p.steps, []string{}
}

fn (mut p Parser) match_kind(k TokenKind) bool {
	if p.peek().kind == k { p.advance(); return true }
	return false
}

// <draw> → <action> | <action> ; <draw>
fn (mut p Parser) parse_draw(mut node TreeNode) (bool, []string) {
	// Replace <draw> by a sequence of <action> separated by ';'
	mut list_node := new_node('draw_list')
	node.add_child(list_node)

	// Before parsing first action, show expansion to <action>
	p.steps << 'HI <action> BYE'
	for {
		mut act_node := new_node('action')
		list_node.add_child(act_node)
		_, errs := p.parse_action(mut act_node)
		if errs.len > 0 { return false, errs }

		// After parsing an action, if next token is ';', show derivation with remaining <draw>
		if p.peek().kind == .semicol {
			// Show: HI <parsed_so_far> ; <draw> BYE
			left := p.since_hi()
			p.steps << 'HI ' + left + ' ; <draw> BYE'
			// consume ';'
			_ = p.match_kind(.semicol)
			mut semi_node := new_node(';')
			list_node.add_child(semi_node)
			continue
		}
		break
	}
	// No more actions; show: HI <parsed_so_far> BYE
	p.steps << 'HI ' + p.since_hi() + ' BYE'
	return true, []string{}
}

// <action> → bar <x><y>,<y>
//          | line <x><y>,<x><y>
//          | fill <x><y>
fn (mut p Parser) parse_action(mut node TreeNode) (bool, []string) {
	t := p.peek()
	match t.kind {
		.bar {
			p.advance()
			node.add_child(new_node('bar'))
			// <x>
			x1 := p.consume_x() or {
				return false, [p.err_expected_x()]
			}
			node.add_child(new_node(x1))
			// <y>
			y1 := p.consume_y() or {
				return false, [p.err_expected_y()]
			}
			node.add_child(new_node(y1))
			// ,
			if !p.match_kind(.comma) {
				return false, ["Expected ',' after ${x1}${y1}"]
			}
			node.add_child(new_node(','))
			// <y>
			y2 := p.consume_y() or {
				return false, [p.err_expected_y()]
			}
			node.add_child(new_node(y2))
			return true, []string{}
		}
		.line {
			p.advance()
			node.add_child(new_node('line'))
			// <x><y>
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			node.add_child(new_node(x1))
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			node.add_child(new_node(y1))
			if !p.match_kind(.comma) { return false, ["Expected ',' after ${x1}${y1}"] }
			node.add_child(new_node(','))
			x2 := p.consume_x() or { return false, [p.err_expected_x()] }
			node.add_child(new_node(x2))
			y2 := p.consume_y() or { return false, [p.err_expected_y()] }
			node.add_child(new_node(y2))
			return true, []string{}
		}
		.fill {
			p.advance()
			node.add_child(new_node('fill'))
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			node.add_child(new_node(x1))
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			node.add_child(new_node(y1))
			return true, []string{}
		}
		else {
			if t.kind == .eof { return false, ['Unexpected end of input while parsing <action>'] }
			return false, ['action ' + t.lit + ' not valid']
		}
	}
}

fn (mut p Parser) consume_x() !string {
	t := p.peek()
	if t.kind == .xletter { p.advance(); return t.lit }
	if t.kind == .ydigit { return error(t.lit + " contains an error – variable '" + t.lit + "' is not valid") }
	return error('Expected X letter (A-E)')
}

fn (mut p Parser) consume_y() !string {
	t := p.peek()
	if t.kind == .ydigit { p.advance(); return t.lit }
	if t.kind == .xletter { return error(t.lit + " contains an error – variable '" + t.lit + "' is not valid") }
	return error('Expected Y digit (1-5)')
}

fn (mut p Parser) err_expected_x() string {
	t := p.peek()
	if t.kind == .ydigit { return t.lit + ' contains the unrecognized value ' + t.lit }
	if t.kind == .eof { return 'Unexpected end of input – expected X letter (A-E)' }
	return t.lit + " contains an error – variable '" + t.lit + "' is not valid"
}

fn (mut p Parser) err_expected_y() string {
	t := p.peek()
	if t.kind == .xletter { return t.lit + " contains an error – variable '" + t.lit + "' is not valid" }
	if t.kind == .eof { return 'Unexpected end of input – expected Y digit (1-5)' }
	// If digit but not 1-5 would be caught by lexer, but include generic
	return t.lit + ' contains the unrecognized value ' + t.lit
}

// Utility to show derivation progress based on consumed tokens
fn (p &Parser) since_hi() string {
	// Build sentence from tokens consumed so far AFTER 'HI' and before BYE
	mut s := ''
	mut prev := TokenKind.eof
	for j in 0 .. p.i {
		if j == 0 { continue } // skip HI position
		t := p.tokens[j]
		if t.kind == .eof || t.kind == .bye { break }
		match t.kind {
			.comma { s += ',' }
			.semicol { s += ';'; s += ' ' }
			else {
				// add space except when joining X+Y
				if s.len > 0 && prev !in [.comma, .semicol] && !(prev == .xletter && t.kind == .ydigit) { s += ' ' }
				s += t.lit
			}
		}
		prev = t.kind
	}
	return s.trim_space()
}


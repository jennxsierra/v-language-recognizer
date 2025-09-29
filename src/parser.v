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

// Format derivation steps with numbering and arrows
pub fn format_derivation(steps []string) []string {
	mut formatted := []string{}
	for i, step in steps {
		if i == 0 {
			// First step with step number
			formatted << '01 ${step}\t→ ${steps[1]}'
		} else if i == 1 {
			// Skip - already handled in step 0
			continue
		} else {
			// Format subsequent steps with proper numbering
			num := if i < 10 { '0${i}' } else { '${i}' }
			formatted << '${num}\t\t→ ${step}'
		}
	}
	return formatted
}

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

// Parse with detailed leftmost derivation
pub fn (mut p Parser) parse_graph_with_derivation() (&TreeNode, []string, []string) {
	p.steps = []string{}
	p.steps << '<graph>'
	p.steps << 'HI <draw> BYE'
	
	// Build parse tree
	mut root := new_node('<graph>')
	mut hi_node := new_node('HI')
	mut draw_node := new_node('<draw>')
	mut bye_node := new_node('BYE')
	root.add_child(hi_node)
	root.add_child(draw_node)
	root.add_child(bye_node)

	// expect HI
	if !p.match_kind(.hi) {
		return root, p.steps, ['Expected HI at the beginning']
	}

	// Generate dynamic leftmost derivation based on actual input
	p.generate_dynamic_leftmost_derivation()

	// Reset position and parse for tree
	p.i = 1
	_, derrs := p.parse_draw_for_tree(mut draw_node)
	if derrs.len > 0 {
		return root, p.steps, derrs
	}

	// expect BYE
	if !p.match_kind(.bye) {
		return root, p.steps, ['Expected BYE at the end']
	}

	if p.peek().kind != .eof {
		t := p.peek()
		return root, p.steps, ['Unexpected token ' + t.lit + ' after BYE']
	}
	return root, p.steps, []string{}
}

fn (mut p Parser) generate_dynamic_leftmost_derivation() {
	// Parse the input to generate actions dynamically
	mut actions := p.extract_actions()
	
	mut current_sentence := 'HI '
	mut remaining_actions := actions.len
	
	for i, action in actions {
		is_last_action := (i == actions.len - 1)
		
		// Step: <draw> → <action> ; <draw> or <draw> → <action>
		if is_last_action {
			p.steps << current_sentence + '<action> BYE'
		} else {
			if remaining_actions > 1 {
				p.steps << current_sentence + '<action> ; <draw> BYE'
			}
		}
		
		// Generate steps for this specific action
		current_sentence = p.generate_action_steps(action, current_sentence, is_last_action)
		
		if !is_last_action {
			// After completing an action, show the sentence with ; <draw>
			p.steps << current_sentence + ' ; <draw> BYE'
			current_sentence += '; '
		}
		
		remaining_actions--
	}
	
	// Final step
	p.steps << current_sentence + ' BYE'
}

// Extract actions from the token stream
fn (p &Parser) extract_actions() []ActionInfo {
	mut actions := []ActionInfo{}
	mut i := 1 // Start after HI
	
	for i < p.tokens.len {
		if p.tokens[i].kind == .bye || p.tokens[i].kind == .eof {
			break
		}
		
		if p.tokens[i].kind in [.bar, .line, .fill] {
			action_type := p.tokens[i].kind
			mut params := []string{}
			i++ // move past action keyword
			
			// Collect parameters based on action type
			match action_type {
				.bar {
					// bar <x><y>,<y> = 4 tokens: x, y, comma, y
					if i + 3 < p.tokens.len {
						params << p.tokens[i].lit     // x
						params << p.tokens[i + 1].lit // y
						params << p.tokens[i + 3].lit // y after comma
						i += 4
					}
				}
				.line {
					// line <x><y>,<x><y> = 5 tokens: x, y, comma, x, y
					if i + 4 < p.tokens.len {
						params << p.tokens[i].lit     // x1
						params << p.tokens[i + 1].lit // y1
						params << p.tokens[i + 3].lit // x2
						params << p.tokens[i + 4].lit // y2
						i += 5
					}
				}
				.fill {
					// fill <x><y> = 2 tokens: x, y
					if i + 1 < p.tokens.len {
						params << p.tokens[i].lit     // x
						params << p.tokens[i + 1].lit // y
						i += 2
					}
				}
				else {}
			}
			
			actions << ActionInfo{
				action_type: action_type
				params: params
			}
		}
		
		// Skip semicolon
		if i < p.tokens.len && p.tokens[i].kind == .semicol {
			i++
		}
	}
	
	return actions
}

struct ActionInfo {
	action_type TokenKind
	params      []string
}

fn (mut p Parser) generate_action_steps(action ActionInfo, current_sentence string, is_last bool) string {
	suffix := if is_last { ' BYE' } else { ' ; <draw> BYE' }
	mut result := current_sentence
	
	match action.action_type {
		.bar {
			// <action> → bar <x><y>,<y>
			p.steps << result + 'bar <x><y>,<y>' + suffix
			
			// <x> → specific letter
			p.steps << result + 'bar ${action.params[0]}<y>,<y>' + suffix
			
			// <y> → specific digit
			p.steps << result + 'bar ${action.params[0]}${action.params[1]},<y>' + suffix
			
			// <y> → specific digit
			result += 'bar ${action.params[0]}${action.params[1]},${action.params[2]}'
		}
		.line {
			// <action> → line <x><y>,<x><y>
			p.steps << result + 'line <x><y>,<x><y>' + suffix
			
			// <x> → specific letter
			p.steps << result + 'line ${action.params[0]}<y>,<x><y>' + suffix
			
			// <y> → specific digit
			p.steps << result + 'line ${action.params[0]}${action.params[1]},<x><y>' + suffix
			
			// <x> → specific letter
			p.steps << result + 'line ${action.params[0]}${action.params[1]},${action.params[2]}<y>' + suffix
			
			// <y> → specific digit
			result += 'line ${action.params[0]}${action.params[1]},${action.params[2]}${action.params[3]}'
		}
		.fill {
			// <action> → fill <x><y>
			p.steps << result + 'fill <x><y>' + suffix
			
			// <x> → specific letter
			p.steps << result + 'fill ${action.params[0]}<y>' + suffix
			
			// <y> → specific digit
			result += 'fill ${action.params[0]}${action.params[1]}'
		}
		else {}
	}
	
	return result
}

fn (mut p Parser) match_kind(k TokenKind) bool {
	if p.peek().kind == k { p.advance(); return true }
	return false
}

// Simple parse for tree construction
fn (mut p Parser) parse_draw_for_tree(mut node TreeNode) (bool, []string) {
	for {
		mut act_node := new_node('<action>')
		node.add_child(act_node)
		_, errs := p.parse_action_for_tree(mut act_node)
		if errs.len > 0 { return false, errs }

		if p.peek().kind == .semicol {
			_ = p.match_kind(.semicol)
			mut semi_node := new_node(';')
			node.add_child(semi_node)
			continue
		}
		break
	}
	return true, []string{}
}

fn (mut p Parser) parse_action_for_tree(mut node TreeNode) (bool, []string) {
	t := p.peek()
	match t.kind {
		.bar {
			p.advance()
			node.add_child(new_node('bar'))
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x_node := new_node('<x>')
			x_node.add_child(new_node(x1))
			node.add_child(x_node)
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y1_node := new_node('<y>')
			y1_node.add_child(new_node(y1))
			node.add_child(y1_node)
			if !p.match_kind(.comma) { return false, ["Expected ',' after ${x1}${y1}"] }
			node.add_child(new_node(','))
			y2 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y2_node := new_node('<y>')
			y2_node.add_child(new_node(y2))
			node.add_child(y2_node)
			return true, []string{}
		}
		.line {
			p.advance()
			node.add_child(new_node('line'))
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x1_node := new_node('<x>')
			x1_node.add_child(new_node(x1))
			node.add_child(x1_node)
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y1_node := new_node('<y>')
			y1_node.add_child(new_node(y1))
			node.add_child(y1_node)
			if !p.match_kind(.comma) { return false, ["Expected ',' after ${x1}${y1}"] }
			node.add_child(new_node(','))
			x2 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x2_node := new_node('<x>')
			x2_node.add_child(new_node(x2))
			node.add_child(x2_node)
			y2 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y2_node := new_node('<y>')
			y2_node.add_child(new_node(y2))
			node.add_child(y2_node)
			return true, []string{}
		}
		.fill {
			p.advance()
			node.add_child(new_node('fill'))
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x_node := new_node('<x>')
			x_node.add_child(new_node(x1))
			node.add_child(x_node)
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y_node := new_node('<y>')
			y_node.add_child(new_node(y1))
			node.add_child(y_node)
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
	return t.lit + ' contains the unrecognized value ' + t.lit
}
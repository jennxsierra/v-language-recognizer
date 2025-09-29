module src

/* Syntax Analyzer (Parser) Module
 * 
 * This module implements a recursive descent parser that generates:
 * 1. Parse trees showing the hierarchical structure of valid input
 * 2. Leftmost derivation sequences showing how the grammar produces the input
 * 3. Comprehensive error messages for syntax violations
 * 
 * The parser uses a predictive parsing strategy based on the LL(1) grammar:
 * L - Left to right scanning of input
 * L - Leftmost derivation
 * 1 - One token lookahead */

/* Parse Result Container
 * 
 * Encapsulates all outputs from the parsing process
 * Used for clean separation of concerns between parsing logic and result handling */
pub struct ParseResult {
	pub:
		root       &TreeNode = unsafe { nil } // Root of the parse tree (nil if parsing failed)
		derivation []string                   // Step-by-step leftmost derivation
		errors     []string                   // Collection of syntax error messages
}

/* Recursive Descent Parser
 * 
 * Maintains parsing state and generates both parse trees and derivation sequences
 * Uses lookahead to make parsing decisions and provides detailed error reporting */
pub struct Parser {
	tokens []Token    // Input token stream from lexical analysis
	mut:
		i int         // Current position in token stream (mutable for advancement)
		steps []string // Accumulator for derivation steps (mutable for building derivation)
}

/* Create a new parser instance */
pub fn new_parser(tokens []Token) Parser {
	return Parser{ tokens: tokens, i: 0, steps: []string{} }
}

// Parser Navigation and State Management Functions

/* Check if parser has consumed all tokens */
fn (mut p Parser) at_end() bool { return p.i >= p.tokens.len }

/* Look at current token without consuming it (for lookahead) */
fn (mut p Parser) peek() Token { return p.tokens[p.i] }

/* Consume current token and move to next position */
fn (mut p Parser) advance() Token { t := p.tokens[p.i]; p.i++; return t }

/* Format derivation steps for display
 * 
 * Converts raw derivation steps into a numbered, arrow-formatted sequence
 * suitable for display. Shows the step-by-step transformation from start
 * symbol to final sentence */
pub fn format_derivation(steps []string) []string {
	mut formatted := []string{}
	for i, step in steps {
		if i == 0 {
			// First step: combine initial symbol with first derivation
			formatted << '01 ${step}\t→ ${steps[1]}'
		} else if i == 1 {
			// Skip - already combined with step 0
			continue
		} else {
			// Subsequent steps: add step number and arrow
			num := if i < 10 { '0${i}' } else { '${i}' }  // Zero-pad for alignment
			formatted << '${num}\t\t→ ${step}'
		}
	}
	return formatted
}

/* Reconstruct the original sentence from tokens
 * 
 * Converts the token stream back into a readable string format
 * Handles proper spacing between tokens while preserving the structure
 * of coordinate pairs (e.g., "A1" not "A 1") */
pub fn tokens_to_sentence(tokens []Token) string {
	mut s := ''
	mut prev_kind := TokenKind.eof
	
	// Process each token and build the sentence with proper spacing
	for t in tokens {
		if t.kind == .eof { break }  // Stop at end-of-file marker
		
		match t.kind {
			.comma {
				// Commas attach directly to preceding token
				s += ','
			}
			.semicol {
				// Semicolons are followed by a space for readability
				s += ';'
				s += ' '
			}
			else {
				// Add space before token except in special cases:
				// 1. At start of string
				// 2. After comma or semicolon (already handled)
				// 3. When joining X+Y coordinates (e.g., "A" + "1" = "A1")
				if s.len > 0 && prev_kind !in [.comma, .semicol] && !(prev_kind == .xletter && t.kind == .ydigit) {
					s += ' '
				}
				s += t.lit
			}
		}
		prev_kind = t.kind  // Remember previous token type for next iteration
	}
	return s.trim_space()  // Remove any trailing whitespace
}

/* Main parsing function with derivation generation
 * 
 * This function orchestrates the complete parsing process:
 * 1. Initializes the derivation with the start symbol
 * 2. Constructs the parse tree structure
 * 3. Validates token sequence against grammar rules
 * 4. Generates dynamic leftmost derivation based on actual input */
pub fn (mut p Parser) parse_graph_with_derivation() (&TreeNode, []string, []string) {
	// Initialize derivation sequence with start symbol and first production
	p.steps = []string{}
	p.steps << '<graph>'           // Start symbol
	p.steps << 'HI <draw> BYE'     // First production: <graph> → HI <draw> BYE
	
	// Build the basic parse tree structure for <graph> → HI <draw> BYE
	mut root := new_node('<graph>')  // Root represents the start symbol
	mut hi_node := new_node('HI')    // Terminal: program start marker
	mut draw_node := new_node('<draw>') // Non-terminal: drawing commands
	mut bye_node := new_node('BYE')  // Terminal: program end marker
	
	// Build tree structure
	root.add_child(hi_node)
	root.add_child(draw_node)
	root.add_child(bye_node)

	// PHASE 1: Validate program structure
	// Check for required HI at the beginning
	if !p.match_kind(.hi) {
		return root, p.steps, ['Expected HI at the beginning']
	}

	// PHASE 2: Generate complete leftmost derivation
	// Analyze the token stream to create derivation steps dynamically
	p.generate_dynamic_leftmost_derivation()

	// PHASE 3: Build detailed parse tree
	// Reset position to parse drawing commands and construct tree nodes
	p.i = 1  // Position after HI token
	_, derrs := p.parse_draw_for_tree(mut draw_node)
	if derrs.len > 0 {
		return root, p.steps, derrs
	}

	// PHASE 4: Validate program termination
	// Check for required BYE at the end
	if !p.match_kind(.bye) {
		return root, p.steps, ['Expected BYE at the end']
	}

	// PHASE 5: Ensure no trailing tokens
	if p.peek().kind != .eof {
		t := p.peek()
		return root, p.steps, ['Unexpected token ' + t.lit + ' after BYE']
	}
	
	return root, p.steps, []string{}  // Success: return complete parse tree and derivation
}

/* Generate dynamic leftmost derivation based on actual input
 * 
 * This function creates derivation steps that correspond exactly to the input,
 * showing how the grammar produces the specific sequence of actions
 * The derivation follows leftmost derivation rules (always expand leftmost non-terminal) */
fn (mut p Parser) generate_dynamic_leftmost_derivation() {
	// Extract action information from the token stream
	mut actions := p.extract_actions()
	
	mut current_sentence := 'HI '     // Start with HI and space
	mut remaining_actions := actions.len
	
	// Process each action to build derivation steps
	for i, action in actions {
		is_last_action := (i == actions.len - 1)
		
		// Show <draw> production based on whether more actions follow
		if is_last_action {
			// Last action: <draw> → <action>
			p.steps << current_sentence + '<action> BYE'
		} else {
			// More actions follow: <draw> → <action> ; <draw>
			if remaining_actions > 1 {
				p.steps << current_sentence + '<action> ; <draw> BYE'
			}
		}
		
		// Generate derivation steps for this specific action type and parameters
		current_sentence = p.generate_action_steps(action, current_sentence, is_last_action)
		
		if !is_last_action {
			// Show intermediate step with semicolon and remaining <draw>
			p.steps << current_sentence + ' ; <draw> BYE'
			current_sentence += '; '  // Prepare for next action
		}
		
		remaining_actions--
	}
	
	// Final derivation step: complete sentence
	p.steps << current_sentence + ' BYE'
}

/* Extract action information from token stream
 * 
 * Scans through tokens to identify action commands and their parameters
 * This information is used to generate accurate derivation steps that
 * correspond to the input structure */
fn (p &Parser) extract_actions() []ActionInfo {
	mut actions := []ActionInfo{}
	mut i := 1 // Start after HI token
	
	// Scan through tokens looking for action keywords
	for i < p.tokens.len {
		// Stop when we reach program end markers
		if p.tokens[i].kind == .bye || p.tokens[i].kind == .eof {
			break
		}
		
		// Process action keywords and extract their parameters
		if p.tokens[i].kind in [.bar, .line, .fill] {
			action_type := p.tokens[i].kind
			mut params := []string{}  // Parameter values for this action
			i++ // Move past the action keyword
			
			// Extract parameters based on the specific action type
			match action_type {
				.bar {
					// bar <x><y>,<y> pattern: X-coordinate, Y-coordinate, comma, Y-coordinate
					// Expected token sequence: [xletter, ydigit, comma, ydigit]
					if i + 3 < p.tokens.len {
						params << p.tokens[i].lit     // x coordinate (A-E)
						params << p.tokens[i + 1].lit // y coordinate (1-5)
						params << p.tokens[i + 3].lit // second y coordinate (after comma)
						i += 4  // Skip past all consumed tokens
					}
				}
				.line {
					// line <x><y>,<x><y> pattern: start point, comma, end point
					// Expected token sequence: [xletter, ydigit, comma, xletter, ydigit]
					if i + 4 < p.tokens.len {
						params << p.tokens[i].lit     // start x coordinate
						params << p.tokens[i + 1].lit // start y coordinate
						params << p.tokens[i + 3].lit // end x coordinate (after comma)
						params << p.tokens[i + 4].lit // end y coordinate
						i += 5  // Skip past all consumed tokens
					}
				}
				.fill {
					// fill <x><y> pattern: single coordinate point
					// Expected token sequence: [xletter, ydigit]
					if i + 1 < p.tokens.len {
						params << p.tokens[i].lit     // x coordinate
						params << p.tokens[i + 1].lit // y coordinate
						i += 2  // Skip past consumed tokens
					}
				}
				else {} // No parameters for unknown action types
			}
			
			// Store the complete action information
			actions << ActionInfo{
				action_type: action_type
				params: params
			}
		}
		
		// Skip semicolon separators between actions
		if i < p.tokens.len && p.tokens[i].kind == .semicol {
			i++
		}
	}
	
	return actions
}

/* Action Information Container
 * 
 * Stores the type of action and its associated parameters
 * Used to generate derivation steps that match the specific input */
struct ActionInfo {
	action_type TokenKind // The action keyword (bar, line, fill)
	params      []string  // Parameter values extracted from tokens
}

/* Generate derivation steps for a specific action
 * 
 * Creates the sequence of derivation steps that shows how an <action>
 * non-terminal is expanded into the specific action with its parameters */
fn (mut p Parser) generate_action_steps(action ActionInfo, current_sentence string, is_last bool) string {
	// Determine the suffix based on whether more actions follow
	suffix := if is_last { ' BYE' } else { ' ; <draw> BYE' }
	mut result := current_sentence
	
	// Generate derivation steps specific to each action type
	match action.action_type {
		.bar {
			// Step 1: <action> → bar <x><y>,<y>
			p.steps << result + 'bar <x><y>,<y>' + suffix
			
			// Step 2: <x> → specific letter (e.g., A, B, C, D, or E)
			p.steps << result + 'bar ${action.params[0]}<y>,<y>' + suffix
			
			// Step 3: First <y> → specific digit (1-5)
			p.steps << result + 'bar ${action.params[0]}${action.params[1]},<y>' + suffix
			
			// Step 4: Second <y> → specific digit (1-5)
			result += 'bar ${action.params[0]}${action.params[1]},${action.params[2]}'
		}
		.line {
			// Step 1: <action> → line <x><y>,<x><y>
			p.steps << result + 'line <x><y>,<x><y>' + suffix
			
			// Step 2: First <x> → specific letter (start point x-coordinate)
			p.steps << result + 'line ${action.params[0]}<y>,<x><y>' + suffix
			
			// Step 3: First <y> → specific digit (start point y-coordinate)
			p.steps << result + 'line ${action.params[0]}${action.params[1]},<x><y>' + suffix
			
			// Step 4: Second <x> → specific letter (end point x-coordinate)
			p.steps << result + 'line ${action.params[0]}${action.params[1]},${action.params[2]}<y>' + suffix
			
			// Step 5: Second <y> → specific digit (end point y-coordinate)
			result += 'line ${action.params[0]}${action.params[1]},${action.params[2]}${action.params[3]}'
		}
		.fill {
			// Step 1: <action> → fill <x><y>
			p.steps << result + 'fill <x><y>' + suffix
			
			// Step 2: <x> → specific letter (fill point x-coordinate)
			p.steps << result + 'fill ${action.params[0]}<y>' + suffix
			
			// Step 3: <y> → specific digit (fill point y-coordinate)
			result += 'fill ${action.params[0]}${action.params[1]}'
		}
		else {} // Unknown action type - no derivation steps
	}
	
	return result  // Return the updated sentence with this action expanded
}

/* Match and consume a specific token type
 * 
 * Helper function for predictive parsing. Checks if the current token
 * matches the expected type and consumes it if so */
fn (mut p Parser) match_kind(k TokenKind) bool {
	if p.peek().kind == k { p.advance(); return true }
	return false
}

/* Parse drawing commands and build parse tree nodes
 * 
 * Handles the <draw> production rules:
 * <draw> → <action> | <action> ; <draw>
 * 
 * This function builds the tree structure while the derivation
 * generation handles the step-by-step transformation display */
fn (mut p Parser) parse_draw_for_tree(mut node TreeNode) (bool, []string) {
	// Parse sequence of actions separated by semicolons
	for {
		// Create and parse an <action> node
		mut act_node := new_node('<action>')
		node.add_child(act_node)
		_, errs := p.parse_action_for_tree(mut act_node)
		if errs.len > 0 { return false, errs }

		// Check for semicolon separator (indicates more actions follow)
		if p.peek().kind == .semicol {
			_ = p.match_kind(.semicol)  // Consume the semicolon
			mut semi_node := new_node(';')  // Add semicolon to tree
			node.add_child(semi_node)
			continue  // Parse next action
		}
		break  // No more actions
	}
	return true, []string{}  // Success
}

/* Parse individual action and build corresponding tree nodes
 * 
 * Handles the three action production rules:
 * <action> → bar <x><y>,<y> | line <x><y>,<x><y> | fill <x><y>
 * 
 * Constructs detailed parse tree nodes showing the hierarchical structure
 * of each action with its coordinate parameters */
fn (mut p Parser) parse_action_for_tree(mut node TreeNode) (bool, []string) {
	t := p.peek()  // Look ahead to determine action type
	
	match t.kind {
		.bar {
			// Parse: bar <x><y>,<y>
			p.advance()  // Consume 'bar' token
			node.add_child(new_node('bar'))  // Add terminal node
			
			// Parse first <x> coordinate
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x_node := new_node('<x>')  // Create non-terminal
			x_node.add_child(new_node(x1))   // Add terminal value
			node.add_child(x_node)
			
			// Parse first <y> coordinate
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y1_node := new_node('<y>')  // Create non-terminal
			y1_node.add_child(new_node(y1))  // Add terminal value
			node.add_child(y1_node)
			
			// Parse comma separator
			if !p.match_kind(.comma) { return false, ["Expected ',' after ${x1}${y1}"] }
			node.add_child(new_node(','))  // Add comma to tree
			
			// Parse second <y> coordinate
			y2 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y2_node := new_node('<y>')  // Create non-terminal
			y2_node.add_child(new_node(y2))  // Add terminal value
			node.add_child(y2_node)
			
			return true, []string{}  // Success
		}
		.line {
			// Parse: line <x><y>,<x><y>
			p.advance()  // Consume 'line' token
			node.add_child(new_node('line'))  // Add terminal node
			
			// Parse start point coordinates
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x1_node := new_node('<x>')   // Start point X
			x1_node.add_child(new_node(x1))
			node.add_child(x1_node)
			
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y1_node := new_node('<y>')   // Start point Y
			y1_node.add_child(new_node(y1))
			node.add_child(y1_node)
			
			// Parse comma separator
			if !p.match_kind(.comma) { return false, ["Expected ',' after ${x1}${y1}"] }
			node.add_child(new_node(','))  // Add comma to tree
			
			// Parse end point coordinates
			x2 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x2_node := new_node('<x>')   // End point X
			x2_node.add_child(new_node(x2))
			node.add_child(x2_node)
			
			y2 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y2_node := new_node('<y>')   // End point Y
			y2_node.add_child(new_node(y2))
			node.add_child(y2_node)
			
			return true, []string{}  // Success
		}
		.fill {
			// Parse: fill <x><y>
			p.advance()  // Consume 'fill' token
			node.add_child(new_node('fill'))  // Add terminal node
			
			// Parse fill point coordinates
			x1 := p.consume_x() or { return false, [p.err_expected_x()] }
			mut x_node := new_node('<x>')    // Fill point X
			x_node.add_child(new_node(x1))
			node.add_child(x_node)
			
			y1 := p.consume_y() or { return false, [p.err_expected_y()] }
			mut y_node := new_node('<y>')    // Fill point Y
			y_node.add_child(new_node(y1))
			node.add_child(y_node)
			
			return true, []string{}  // Success
		}
		else {
			// Error: unexpected token where action was expected
			if t.kind == .eof { 
				return false, ['Unexpected end of input while parsing <action>'] 
			}
			return false, ['action ' + t.lit + ' not valid']
		}
	}
}

/* Parse and consume an X coordinate variable (A-E)
 * 
 * Validates that the current token is a valid X coordinate and consumes it
 * Provides specific error messages for common mistakes */
fn (mut p Parser) consume_x() !string {
	t := p.peek()
	if t.kind == .xletter { p.advance(); return t.lit }  // Valid X coordinate
	if t.kind == .ydigit { 
		// Common error: using digit where letter expected
		return error(t.lit + " contains an error - variable '" + t.lit + "' is not valid") 
	}
	return error('Expected X letter (A-E)')  // Generic error for other cases
}

/* Parse and consume a Y coordinate digit (1-5)
 * 
 * Validates that the current token is a valid Y coordinate and consumes it
 * Provides specific error messages for common mistakes */
fn (mut p Parser) consume_y() !string {
	t := p.peek()
	if t.kind == .ydigit { p.advance(); return t.lit }   // Valid Y coordinate
	if t.kind == .xletter { 
		// Common error: using letter where digit expected
		return error(t.lit + " contains an error - variable '" + t.lit + "' is not valid") 
	}
	return error('Expected Y digit (1-5)')  // Generic error for other cases
}

/* Generate context-aware error message for missing X coordinate
 * 
 * Analyzes the current token to provide the most helpful error message
 * Different messages for different types of incorrect tokens */
fn (mut p Parser) err_expected_x() string {
	t := p.peek()
	if t.kind == .ydigit { 
		// Digit where letter expected
		return t.lit + ' contains the unrecognized value ' + t.lit 
	}
	if t.kind == .eof { 
		// Unexpected end of input
		return 'Unexpected end of input - expected X letter (A-E)' 
	}
	// Other invalid tokens
	return t.lit + " contains an error - variable '" + t.lit + "' is not valid"
}

/* Generate context-aware error message for missing Y coordinate
 * 
 * Analyzes the current token to provide the most helpful error message
 * Different messages for different types of incorrect tokens */
fn (mut p Parser) err_expected_y() string {
	t := p.peek()
	if t.kind == .xletter { 
		// Letter where digit expected
		return t.lit + " contains an error - variable '" + t.lit + "' is not valid" 
	}
	if t.kind == .eof { 
		// Unexpected end of input
		return 'Unexpected end of input - expected Y digit (1-5)' 
	}
	// Other invalid tokens
	return t.lit + ' contains the unrecognized value ' + t.lit
}
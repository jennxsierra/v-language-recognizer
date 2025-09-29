module src

/* Parse Tree Visualization Module
 * 
 * This module provides data structures and rendering functions for displaying
 * parse trees in ASCII format. Parse trees show the hierarchical structure
 * of how the grammar rules were applied to derive the input sentence
 * 
 * The tree structure represents:
 * - Internal nodes: Non-terminal symbols (e.g., <graph>, <draw>, <action>)
 * - Leaf nodes: Terminal symbols (e.g., "HI", "bar", "A", "1", ",")
 * - Parent-child relationships: Grammar rule applications */

/* Parse Tree Node Structure
 * 
 * Represents a single node in the parse tree, containing a label and
 * references to child nodes. This creates a hierarchical structure
 * that mirrors the grammar derivation process */
pub struct TreeNode {
	pub mut:
		label   string        // The symbol this node represents (terminal or non-terminal)
		children []&TreeNode  // Child nodes (empty for leaf/terminal nodes)
}

/* Create a new tree node */
pub fn new_node(label string) &TreeNode {
	return &TreeNode{ label: label, children: []&TreeNode{} }
}

/* Add a child node to this tree node */
pub fn (mut n TreeNode) add_child(child &TreeNode) { n.children << child }

/* Render parse tree as ASCII art
 * 
 * Converts the hierarchical tree structure into a visual ASCII representation
 * using box-drawing characters. Example output:
 * <graph>
 * ├─ HI
 * ├─ <draw>
 * │  ├─ <action>
 * │  │  ├─ fill
 * │  │  ├─ <x>
 * │  │  │  └─ A
 * │  │  └─ <y>
 * │  │     └─ 1
 * └─ BYE */
pub fn render_tree(root &TreeNode) string {
	mut lines := []string{}
	
	// Start with root node (no connector needed)
	lines << root.label
	
	// Recursively render all child nodes with appropriate connectors
	for idx, ch in root.children {
		// Determine if this is the last child (affects connector style)
		is_last_child := idx == root.children.len-1
		render_rec(ch, '', is_last_child, mut lines)
	}
	
	return lines.join('\n')
}

/* Recursive helper function for tree rendering
 * 
 * Handles the recursive traversal and ASCII art generation for tree nodes.
 * Uses different box-drawing characters based on position in tree:
 * - ├─ for nodes with siblings below
 * - └─ for the last child in a group
 * - │  for vertical continuation lines
 * - '   ' for empty space under completed branches */
fn render_rec(node &TreeNode, prefix string, last bool, mut out []string) {
	// Choose connector based on whether this is the last child
	connector := if last { '└─ ' } else { '├─ ' }  // └─ = '└─', ├─ = '├─'
	
	// Add this node's line to output
	out << prefix + connector + node.label
	
	// Calculate prefix for child nodes
	// If this is the last child, use spaces; otherwise use vertical line
	child_prefix := if last { prefix + '   ' } else { prefix + '│  ' }  // │ = '│'
	
	// Recursively render all children
	for idx, ch in node.children {
		is_last_child := idx == node.children.len-1
		render_rec(ch, child_prefix, is_last_child, mut out)
	}
}


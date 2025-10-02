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

/* Constants for vertical tree rendering */
const sibling_spacing = 2    // Horizontal space between sibling nodes
const level_row_height = 2   // Vertical space between tree levels

/* Tree drawing characters - using box drawing for cleaner appearance */
const vertical_line = `│`     // Vertical connector
const horizontal_line = `─`   // Horizontal connector  
const junction_down = `┬`     // T-junction pointing down
const junction_up = `┴`       // T-junction pointing up
const corner_left = `┌`       // Top-left corner
const corner_right = `┐`      // Top-right corner
const junction = `┼`          // Four-way junction

/* Render parse tree as vertical ASCII art
 * 
 * Converts the hierarchical tree structure into a traditional vertical tree
 * representation. */
pub fn render_tree(root &TreeNode) string {
	if root == unsafe { nil } {
		return '<empty tree>'
	}
	
	mut w := measure_width(root)
	mut h := measure_depth(root) * level_row_height + 1
	
	if w < 1 { w = 1 }
	if h < 1 { h = 1 }
	
	// Create 2D grid for rendering
	mut grid := [][]rune{len: h}
	for i in 0 .. h {
		grid[i] = []rune{len: w, init: ` `}
	}
	
	// Render tree into grid
	render_node(mut grid, root, 0, 0)
	
	// Convert grid to string, removing empty trailing lines
	mut result := []string{}
	for row in grid {
		mut line := ''
		for r in row {
			line += r.str()
		}
		line = line.trim_right(' ')
		if line.len > 0 || result.len > 0 {
			result << line
		}
	}
	
	// Remove trailing empty lines
	for result.len > 0 && result.last() == '' {
		result = result[..result.len-1].clone()
	}
	
	return result.join('\n')
}

/* Measure the width required for a node and its subtree */
fn measure_width(node &TreeNode) int {
	if node == unsafe { nil } {
		return 1
	}
	
	mut label_width := node.label.len
	if label_width == 0 {
		label_width = 1
	}
	
	// Leaf node - width is just the label width
	if node.children.len == 0 {
		return label_width
	}
	
	// Internal node - width is sum of children widths plus spacing
	mut children_width := 0
	for i, child in node.children {
		children_width += measure_width(child)
		if i < node.children.len - 1 {
			children_width += sibling_spacing
		}
	}
	
	// Return the maximum of label width and children width
	return if children_width > label_width { children_width } else { label_width }
}

/* Measure the depth (height) of a node's subtree */
fn measure_depth(node &TreeNode) int {
	if node == unsafe { nil } {
		return 1
	}
	
	if node.children.len == 0 {
		return 1
	}
	
	mut max_child_depth := 0
	for child in node.children {
		child_depth := measure_depth(child)
		if child_depth > max_child_depth {
			max_child_depth = child_depth
		}
	}
	
	return 1 + max_child_depth
}

/* Render a node and its subtree into the grid */
fn render_node(mut grid [][]rune, node &TreeNode, start_x int, y int) int {
	if node == unsafe { nil } {
		return 0
	}
	
	w := measure_width(node)
	if w <= 0 {
		return 0
	}
	
	// Calculate label position (centered)
	label := node.label
	label_x := start_x + (w - label.len) / 2
	
	// Draw the label
	for i, r in label {
		if y >= 0 && y < grid.len && label_x + i >= 0 && label_x + i < grid[0].len {
			grid[y][label_x + i] = r
		}
	}
	
	// If leaf node, we're done
	if node.children.len == 0 {
		return w
	}
	
	// Calculate parent center for connecting lines
	parent_center := label_x + (label.len - 1) / 2
	
	// Draw vertical line down from parent (only if not already occupied)
	if y + 1 < grid.len && parent_center >= 0 && parent_center < grid[0].len {
		if grid[y + 1][parent_center] == ` ` {
			grid[y + 1][parent_center] = vertical_line
		}
	}
	
	// Precompute child widths and total width (including spacing)
	mut child_widths := []int{}
	mut children_total := 0
	for i, child in node.children {
		mut cw := measure_width(child)
		if cw < 1 { cw = 1 }
		child_widths << cw
		children_total += cw
		if i < node.children.len - 1 {
			children_total += sibling_spacing
		}
	}

	// Center the entire children block under this node
	mut child_start := start_x + (w - children_total) / 2

	// Child centers, based on the centered start
	mut child_centers := []int{}
	for cw in child_widths {
		child_centers << child_start + (cw - 1) / 2
		child_start += cw + sibling_spacing
	}
	
	// Draw horizontal connecting line and junctions
	if y + 1 < grid.len && child_centers.len > 0 {
		if child_centers.len == 1 {
			// Single child - just continue the vertical line, no horizontal connections needed
			// This creates clean vertical lines for parent-child relationships
			// No code needed here - the vertical line from parent continues naturally
		} else {
			// Multiple children - draw horizontal line spanning all elements
			mut min_x := parent_center
			mut max_x := parent_center
			
			for center in child_centers {
				if center < min_x { min_x = center }
				if center > max_x { max_x = center }
			}
			
			// Draw horizontal line
			for x in min_x .. max_x + 1 {
				if x >= 0 && x < grid[0].len {
					grid[y + 1][x] = horizontal_line
				}
			}
			
			// Draw parent junction (T-junction pointing up to connect to parent above)
			if parent_center >= 0 && parent_center < grid[0].len {
				grid[y + 1][parent_center] = junction_up
			}
			
			// Draw child junctions with proper corner connections
			for i, center in child_centers {
				if center >= 0 && center < grid[0].len {
					if center == parent_center {
						// Parent and child at same position - use four-way junction
						grid[y + 1][center] = junction
					} else if i == 0 {
						// Leftmost child - use top-left corner
						grid[y + 1][center] = corner_left
					} else if i == child_centers.len - 1 {
						// Rightmost child - use top-right corner
						grid[y + 1][center] = corner_right
					} else {
						// Middle child - use T-junction pointing down
						grid[y + 1][center] = junction_down
					}
				}
			}
		}
	}
	
	// Recursively render children at the same x positions
	child_start = start_x + (w - children_total) / 2
	for i, child in node.children {
		_ = render_node(mut grid, child, child_start, y + level_row_height)
		child_start += child_widths[i] + sibling_spacing
	}
	
	return w
}


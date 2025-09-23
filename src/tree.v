module src

// Simple parse tree structures and ASCII rendering

pub struct TreeNode {
	pub mut:
		label   string
		children []&TreeNode
}

pub fn new_node(label string) &TreeNode {
	return &TreeNode{ label: label, children: []&TreeNode{} }
}

pub fn (mut n TreeNode) add_child(child &TreeNode) { n.children << child }

pub fn render_tree(root &TreeNode) string {
	mut lines := []string{}
	// Print root without connector
	lines << root.label
	// Render children with connectors
	for idx, ch in root.children {
		render_rec(ch, '', idx == root.children.len-1, mut lines)
	}
	return lines.join('\n')
}

fn render_rec(node &TreeNode, prefix string, last bool, mut out []string) {
	connector := if last { '└─ ' } else { '├─ ' }
	out << prefix + connector + node.label
	// Update prefix for children
	child_prefix := if last { prefix + '   ' } else { prefix + '│  ' }
	for idx, ch in node.children {
		render_rec(ch, child_prefix, idx == node.children.len-1, mut out)
	}
}


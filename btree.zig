const std = @import("std");
const mem = std.mem;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

// struct { items: []T, children: ?*[degree]usize }

pub fn node(comptime degree: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        items: [degree - 1]T,
        children: ?*[degree]usize,
        leaf: bool,

        pub fn init(allocator: Allocator) !*Self {
            var self = try allocator.create(Self);
            self.* = .{
                .items = undefined,
                .children = null,
                .leaf = true, // leaf by default
            };
            // self.children = try allocator.alloc(usize, degree);
            return self;
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.destroy(self);
        }

        pub fn get_item_at(self: *Self, index: usize) T {
            return self.items[index];
        }

        pub fn set_item_at(self: *Self, index: usize, item: T) void {
            self.items[index] = item;
        }

        pub fn get_child_at(self: *Self, index: usize) ?*Self {
            if (self.children) |children| {
                return children[index];
            }
            return null;
        }

        pub fn set_child_at(self: *Self, index: usize, child: *Self) void {
            if (self.children) |children| {
                children[index] = child;
            }
        }

        pub fn get_child_count(self: *Self) usize {
            if (self.children) |children| {
                var count: usize = 0;
                for (children) |child| {
                    if (child!=0) {
                        count += 1;
                    }
                }
                return count;
            }
            return 0;
        }   

        pub fn get_item_count(self: *Self) usize {
            var count: usize = 0;
            for (self.items) |item| {
                if (item!=0) {
                    count += 1;
                }
            }
            return count;
        }

        pub fn is_full(self: *Self) bool {
            return self.get_item_count() == degree - 1;
        }

        pub fn is_leaf(self: *Self) bool {
            return self.leaf;
        }

        pub fn is_root(self: *Self) bool {
            return self.children == null;
        }   

        pub fn is_empty(self: *Self) bool {
            return self.get_item_count() == 0;
        }   

        pub fn is_half_full(self: *Self) bool {
            return self.get_item_count() == (degree - 1) / 2;
        }

        pub fn is_underflow(self: *Self) bool {
            return self.get_item_count() < (degree - 1) / 2;
        }   

        pub fn is_overflow(self: *Self) bool {
            return self.get_item_count() > degree - 1;
        }   

        pub fn is_valid(self: *Self) bool {
            return self.get_item_count() <= degree - 1;
        }

        pub fn copy_item_into(self: *Self, index: usize, dest: *T) void {
            dest.* = self.items[index];
        }

        pub fn swap_item_at(self: *Self, index: usize, item: T) T {
            const old = self.items[index];
            self.items[index] = item;
            return old;
        }   
    };
}

pub fn btree(comptime degree: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = node(degree, T);
        root: ?*Node,
        pool: ArrayList(*Node),
        allocator: Allocator,

        pub fn init(allocator: Allocator) !*Self {
            var self = try allocator.create(Self);
            self.* = .{
                .root = null,
                .allocator = allocator,
                .pool = ArrayList(*Node).init(allocator),
                // .pool = for (pool) |node| node. = .{};,
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }   

        fn node_free(self: *Self, n: *Node) void {
            if (n.isleaf()) {
                n.deinit(self.allocator);
            } else {
                for (n.children) |child| {
                    if (child) |c| {
                        self.node_free(c);
                    }
                }
                n.deinit(self.allocator);
            }
        }

        pub fn clear(self: *Self) void {
            if (self.root) |root| {
                self.node_free(root);
            }
            self.root = null;
        }

        pub fn gimme_node(self: *Self) !*Node {
            if (self.pool.count > 0) {
                return self.pool.pop();
            }
            return Node.init(self.allocator);
        }

        pub fn return_node(self: *Self, n: *Node) void {
            self.pool.append(n);
        }

        fn split_child(self: *Self, parent: *Node, index: usize) !void {
            const child = parent.get_child_at(index);
            const new_child = try self.gimme_node();
            new_child.leaf = child.leaf;
            for (child.items[degree/2..]) |item| {
                new_child.items[new_child.get_item_count()] = item;
            }
            if (!child.leaf) {
                for (child.children[degree/2..]) |c| {
                    new_child.children[new_child.get_child_count()] = c;
                }
            }

            for (child.items[degree/2..]) |i| {
                i = null;
            }
            // child.items[degree/2..] = undefined;
            if (!child.leaf) {
                for (child.children[degree/2..]) |c| {
                    c = null;
                }
            }
            // child.children[degree/2..] = undefined;
            for (parent.items[index..]) |item| {
                parent.items[parent.get_item_count()] = item;
            }
            parent.items[index] = child.items[degree/2 - 1];
            child.items[degree/2 - 1] = undefined;
            for (parent.children[index+1..]) |c| {
                parent.children[parent.get_child_count()] = c;
            }
            parent.children[index+1] = new_child;
        }

        fn insert_nonfull(self: *Self, n: *Node, item: T) !void {
            var i = n.get_item_count() - 1;
            if (n.leaf) {
                while (i >= 0 and n.items[i] > item) : (i -= 1) {
                    n.items[i+1] = n.items[i];
                }
                n.items[i+1] = item;
            } else {
                while (i >= 0 and n.items[i] > item) : (i -= 1) {}
                i += 1;
                const child = n.get_child_at(i);
                if (child) |c| {
                    if (c.is_full()) {
                        try self.split_child(n, i);
                        if (n.items[i] < item) {
                            i += 1;
                        }
                    }
                    try self.insert_nonfull(n.get_child_at(i).?, item);
                }
            }
        }

        pub fn insert(self: *Self, item: T) !void {
            if (self.root) |root| {
                if (root.is_full()) {
                    const new_root = try self.gimme_node();
                    new_root.leaf = false;
                    new_root.children[0] = root;
                    try self.split_child(new_root, 0);
                    self.root = new_root;
                    try self.insert_nonfull(new_root, item);
                } else {
                    try self.insert_nonfull(root, item);
                }
            } else {
                const new_root = try self.gimme_node();
                new_root.leaf = true;
                new_root.items[0] = item;
                self.root = new_root;
            }
        }



    };  
}

pub fn main() !void{
    var allocator = std.heap.page_allocator;
    var tree = try btree(5, u32).init(allocator);
    // std.debug.print("{}", .{tree});
    // // var h = tree.btree_height();
    // // std.debug.print("{}", .{h});
    try tree.insert(1);
    try tree.insert(2);
    std.debug.print("{}", .{tree});
    // try btree.btree_insert(3);
//    var node1 = try node(4, u32).init(allocator);     
//    node1.items[0] = 9;
// //    node1.insertItem(1);
//    std.debug.print("{}", .{node1.get_item_count()});
//    std.debug.print("{any}", .{node1.items});

}

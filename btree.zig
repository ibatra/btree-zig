const std = @import("std");
const mem = std.mem;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

// struct { items: []T, children: ?*[degree]usize }

pub fn node(comptime degree: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        items: [degree - 1]T = undefined,
        children: [degree]?*Self = [_]?*Self{null} ** degree,
        leaf: bool,

        pub fn init(allocator: Allocator) !*Self {
            var self = try allocator.create(Self);
            self.* = .{ .leaf = true };
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

        pub fn get_child_count(self: *Self) usize {
                var count: usize = 0;
                for (self.children) |child| {
                    if (child != null) {
                        count += 1;
                    }
                }
                return count;
        }   

        pub fn is_full(self: *Self) bool {
            return self.get_child_count() == degree-1;
        }

        pub fn is_leaf(self: *Self) bool {
            return self.leaf;
        }

        pub fn is_empty(self: *Self) bool {
            return self.get_child_count() == 0;
        }   

        pub fn is_half_full(self: *Self) bool {
            return self.get_child_count() == (degree - 1) / 2;
        }

        pub fn is_underflow(self: *Self) bool {
            return self.get_child_count() < (degree - 1) / 2;
        }   

        pub fn is_overflow(self: *Self) bool {
            return self.get_child_count() > degree - 1;
        }   

        pub fn is_valid(self: *Self) bool {
            return self.get_child_count() <= degree - 1;
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
            if (n.leaf) {
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
            return self.pool.popOrNull() orelse Node.init(self.allocator);
        }

        pub fn return_node(self: *Self, n: *Node) void {
            self.pool.append(n);
        }

        fn split_child(self: *Self, parent: *Node, index: usize) !void {
            const child = parent.children[index] orelse unreachable;
            const new_child = try self.gimme_node();
            new_child.leaf = child.is_leaf();
            for (child.items[degree/2..]) |item| {
                new_child.set_item_at(new_child.get_child_count(), item);
            }
            if (!child.is_leaf()) {
                std.mem.copy(?*Node, new_child.children[0..degree/2], child.children[degree/2..]);
            }
            for (child.items[degree/2..]) |*item| item.* = undefined;
            for (child.children[degree/2..]) |*item| item.* = undefined;
            // child.items[degree/2..] = undefined;
            // child.children[degree/2..] = undefined;
            for (parent.items[index..]) |item| {
                parent.items[parent.get_child_count()] = item;
            }

            for (parent.items[index..]) |*item| item.* = undefined;
            // parent.items[index..] = undefined;
            for (parent.children[index+1..]) |c| {
                parent.children[parent.get_child_count()] = c;
            }
            for (parent.items[index+1..]) |*item| item.* = undefined;
            // parent.children[index+1..] = undefined;
            parent.items[index] = child.items[degree/2 - 1];
            child.items[degree/2 - 1] = undefined;
            parent.children[index] = child;
            parent.children[parent.get_child_count()] = new_child;
        }

        fn insert_nonfull(self: *Self, n: *Node, item: T) !void {
            if (n.leaf) {
                var i: usize = n.get_child_count();
                while (i > 0 and n.items[i-1] > item) : (i -= 1) {
                    n.items[i] = n.items[i-1];
                }
                n.items[i] = item;
            } else {
                var i: usize = n.get_child_count();

                const child = n.children[i] orelse unreachable;
                if (child.is_full()) {
                    try self.split_child(n, i);
                    if (n.items[i] < item) {
                        i += 1;
                    }
                }
                try self.insert_nonfull(child, item);
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
    try tree.insert(3);
    try tree.insert(2);
    try tree.insert(5);
    try tree.insert(6);

    std.debug.print("{}", .{tree});
    // try btree.btree_insert(3);
//    var node1 = try node(4, u32).init(allocator);     
//    node1.items[0] = 9;
// //    node1.insertItem(1);
//    std.debug.print("{}", .{node1.get_child_count()});
//    std.debug.print("{any}", .{node1.items});

}

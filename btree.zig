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

        pub fn get_item_count(self: *Self) usize {
            var count: usize = 0;
            for (self.items) |item| {
                if (item != 0) {
                    count += 1;
                }
            }
            return count;
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
            return self.get_item_count() == degree-1;
        }

        pub fn is_leaf(self: *Self) bool {
            return self.leaf;
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
                new_child.set_item_at(new_child.get_item_count(), item);
            }

            if (!child.leaf) {
                for (child.children[degree/2..]) |c, i| {
                    new_child.children[i] = c;
                }
            }
            for (child.items[degree/2..]) |*item| item.* = 0;
            for (child.children[degree/2..]) |*c| c.* = null;
            // child.items[degree/2..] = undefined;
            // child.children[degree/2..] = undefined;
            // std.debug.print("{any}",.{parent.items});
            for (parent.items[index..]) |item| {
                // std.debug.print("{any}",.{parent.items[index..]});
                if (parent.get_item_count() == degree - 1) {
                    break;
                }
                parent.items[parent.get_item_count()] = item;
            }
            
            for (parent.items[index+1..]) |*item| item.* = 0;
            // parent.items[index..] = undefined;
            for (parent.children[index+1..]) |c| {
                if (parent.get_child_count() == degree) {
                    break;
                }
                parent.children[parent.get_child_count()] = c;
            }
            for (parent.items[index+1..]) |*item| item.* = 0;
            // parent.children[index+1..] = undefined;
            parent.items[index] = child.items[degree/2 - 1];
            child.items[degree/2 - 1] = 0;
            parent.children[index] = child;
            parent.children[parent.get_item_count()] = new_child;
        }


        fn insert_non_full(self: *Self, n: *Node, item: T) !void {
            var i: usize = n.get_item_count();
            if (n.leaf) {
                while (i > 0 and n.items[i-1] > item) : (i -= 1) {
                    n.items[i] = n.items[i-1];
                }
                n.items[i] = item;
            } else {
                while (i > 0 and n.items[i-1] > item) : (i -= 1) {}
                const child: ?*Node = n.children[i];
                if (child) |c| {
                    if (c.is_full()) {
                        // std.debug.print("{}yoo \n", .{i});
                        try self.split_child(n, i);
                        if (n.items[i] < item) {
                            i += 1;
                        }
                    }
                }
                
                try self.insert_non_full(n.children[i].?, item);
            }
        }        

        pub fn insert(self: *Self, item: T) !void {
            // display_tree(self);
            if (self.root) |root| {
                if (root.is_full()) {
                    const new_root = try self.gimme_node();
                    self.root = new_root;
                    new_root.leaf = false;
                    new_root.children[0] = root;
                    try self.split_child(new_root, 0);
                    try self.insert_non_full(new_root, item);
                } else {
                    try self.insert_non_full(root, item);
                }
            } else {
                const new_root = try self.gimme_node();
                self.root = new_root;
                new_root.leaf = true;
                new_root.items[0] = item;
            }
        }

        pub fn display_tree(self: *Self) void {
            if (self.root) |root| {
                self.display_node(root, 0);
            }
        }

        fn display_node(self: *Self, n: *Node, level: usize) void {
            std.debug.print("Level {}: ", .{level});
            for (n.items) |item| {
                std.debug.print("{} ", .{item});
            }
            std.debug.print("\n", .{});
            if (!n.leaf) {
                for (n.children) |child| {
                    if (child) |c| {
                        self.display_node(c, level+1);
                    }
                }
            }
        }

        pub fn min_max_iterate(self: *Self, min: T, max: T, callback: *const fn (T) void) void {
            if (self.root) |root| {
                self.min_max_iterate_node(root, min, max, callback);
            }
        }   

        fn min_max_iterate_node(self: *Self, n: *Node, min: T, max: T, callback: *const fn (T) void) void {
            var i: usize = 0;
            while (i < n.get_item_count() and n.items[i] < min) : (i += 1) {}
            if (n.leaf) {
                while (i < n.get_item_count() and n.items[i] <= max) : (i += 1) {
                    callback(n.items[i]);
                }
            } else {
                while (i < n.get_item_count() and n.items[i] <= max) : (i += 1) {
                    if (n.items[i] >= min) {
                        callback(n.items[i]);
                    }
                    if (n.children[i]) |c| {
                        self.min_max_iterate_node(c, min, max, callback);
                    }
                }
                if (n.children[i]) |c| {
                    self.min_max_iterate_node(c, min, max, callback);
                }
            }
        }   

        // pub fn iterator(self: *Self) @TypeOf(Iterator) {
        //     return Iterator(T).init(self, null, null);
        // }

        // pub fn min_max_iterator(self: *Self, min: T, max: T) Iterator {
        //     return Iterator{
        //         .tree = self,
        //         .node = self.root,
        //         .index = 0,
        //         .min = min,
        //         .max = max,
        //     };
        // }



    };  
}

pub fn Iterator(comptime degree: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        tree: *btree(degree, T),
        node: ?*btree(degree, T).Node,
        index: usize,
        min: ?T = null,
        max: ?T = null,

        pub fn init(tree: *btree(degree, T), min: ?T, max: ?T) Self {
            return Self{
                .tree = tree,
                .node = tree.root,
                .index = 0,
                .min = min,
                .max = max,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.node) |n| {
                if (self.min) |min| {
                    while (self.index < n.get_item_count() and n.items[self.index] < min) : (self.index += 1) {}
                }
                if (self.max) |max| {
                    while (self.index < n.get_item_count() and n.items[self.index] > max) : (self.index += 1) {}
                }
                if (self.index < n.get_item_count()) {
                    const item = n.items[self.index];
                    self.index += 1;
                    return item;
                } 
                else {
                        if (n.children[0]) |c| {
                            self.node = c;
                            self.index = 0;
                            return self.next();
                        }

                }
            }
            return null;
        }
    };
}

fn print(x: u8) void {std.debug.print("{any}\n", .{x});}

pub fn main() !void{
    var allocator = std.heap.page_allocator;
    var tree = try btree(5, u8).init(allocator);
    // std.debug.print("{}", .{tree});
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    var i: usize = 0;
    var r: u8 = 0;
    while (i < 100) : (i += 1) {
        r = rand.int(u8);
        std.debug.print("Inserting {}\n", .{r});
        // tree.display_tree();
        try tree.insert(r);
        
    }
    tree.display_tree();

    var iter = Iterator(5, u8).init(tree, 0, 255);
    while (iter.next()) |x| {
        print(x);
    }
    
    // tree.iterator().next();
   

    // std.debug.print("{any}", .{tree.root.?.children});
    // tree.display_tree();
}

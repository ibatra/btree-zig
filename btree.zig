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

        pub fn init(allocator: *Allocator) !*Self {
            var self = try allocator.create(Self);
            self.* = .{
                .items = undefined,
                .children = null,
            };
            return self;
        }
    };
}

pub fn tree(comptime degree: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = node(degree, T);

        root: ?*Node,

        pub fn init(allocator: *Allocator) !*Self {
            var self = try allocator.create(Self);
            self.* = .{
                .root = null,
            };
            return self;
        }

        pub fn deinit(self: *Self, allocator: *Allocator) void {
            if (self.root) |root| {
                self.deinitNode(root, allocator);
                allocator.destroy(root);
            }
        }

        fn deinitNode(self: *Self, n: *Node, allocator: *Allocator) void {
            if (n.children) |children| {
                for (children) |*child| {
                    self.deinitNode(child, allocator);
                    allocator.destroy(child);
                }
                allocator.free(children);
            }
        }

        pub fn insertNode(self: *Self, n: *Node, value: T) !void {
            var i: usize = 0;
            while (i < n.items.len and n.items[i] < value) : (i += 1) {}
            if (i < n.items.len and n.items[i] == value) {
                return;
            }
            if (n.children) |children| {
                try self.insertNode(children[i], value);
                return;
            }
            if (n.items.len < degree - 1) {
                n.items[i] = value;
                return;
            }
            // split
            var new_node = try Node.init(self.allocator);
            new_node.* = .{
                .items = undefined,
                .children = null,
            };
            
            var j: usize = 0;
            while (j < degree / 2) : (j += 1) {}
            var k: usize = 0;
            while (j < degree - 1) : (j += 1) {
                new_node.items[k] = n.items[j];
                k += 1;
            }
            if (i < degree / 2) {
                n.items[i] = value;
            } else {
                new_node.items[i - degree / 2] = value;
            }
        }
    };
}

 
pub fn main() !void{
    var allocator = std.heap.page_allocator;
    var btree = try tree(4, u32).init(&allocator);
    try btree.insertNode(&allocator, 1);
    try btree.insertNode(&allocator, 2);
    try btree.insertNode(&allocator, 3);
//    var node1 = try node(4, u32).init(&allocator);     
//    node1.items[0] = 9;
//    std.debug.print("{}", .{node1.items[0]});

}


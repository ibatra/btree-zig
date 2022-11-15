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

        fn deinitNode(self: *Self, node: *Node, allocator: *Allocator) void {
            if (node.children) |children| {
                for (children) |*child| {
                    self.deinitNode(child, allocator);
                    allocator.destroy(child);
                }
                allocator.free(children);
            }
        }


    };
}

 
pub fn main() !void{
   var allocator = std.heap.page_allocator;
   var node1 = try node(4, u32).init(&allocator);     
   node1.items[0] = 9;
   std.debug.print("{}", .{node1.items[0]});
}


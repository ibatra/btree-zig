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

        pub fn init(allocator: *Allocator) !*Self {
            var self = try allocator.create(Self);
            self.* = .{
                .items = undefined,
                .children = null,
                .leaf = true, // leaf by default
            };
            // self.children = try allocator.alloc(usize, degree);
            return self;
        }

        pub fn deinit(self: *Self, allocator: *Allocator) void {
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
                    if (child) |c| {
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
                if (item) |i| {
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


const std = @import("std");
const print = std.debug.print;

pub fn todigit(char: u8) u8 {
    return char - '0';
}
pub fn isdigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

const rule = struct {
    before: u32,
    after: u32,
};

pub fn parseRule(line: []const u8) rule {
    return .{
        .before = todigit(line[0]) * 10 + todigit(line[1]),
        .after = todigit(line[3]) * 10 + todigit(line[4]),
    };
}
pub fn parseUpdate(line: []const u8, allocator: std.mem.Allocator) ![]const u32 {
    var out = std.ArrayList(u32).init(allocator);

    var page: u32 = 0;
    for (line) |c| {
        if (isdigit(c)) {
            page = page * 10 + todigit(c);
        } else if (c == ',') {
            try out.append(page);
            page = 0;
        }
    }
    try out.append(page);
    return out.items;
}

const puzzleInput = struct {
    rules: []rule,
    updates: [][]const u32,
    pub fn show(self: @This()) void {
        print("\nrules:", .{});
        for (self.rules) |r| {
            print("\n\t{d}|{d}", .{ r.before, r.after });
        }
        print("\nupdates:", .{});
        for (self.updates) |update| {
            print("\n\t{d}", .{update});
        }
    }
};

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !puzzleInput {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var rules = std.ArrayList(rule).init(alloc);
    var updates = std.ArrayList([]const u32).init(alloc);

    const fsize = try file.getEndPos();
    const filestr = try file.readToEndAlloc(alloc, fsize);
    var lines = std.mem.splitScalar(u8, filestr, '\n');

    var onrules: bool = true;
    while (lines.next()) |line| {
        if (line.len == 0) {
            onrules = false;
            continue;
        } else {
            if (onrules) {
                try rules.append(parseRule(line));
            } else {
                try updates.append(try parseUpdate(line, alloc));
            }
        }
    }
    return .{ .rules = rules.items, .updates = updates.items };
}

const Graph = struct {
    const N = std.AutoArrayHashMap(u32, void); // a node is just a set of other nodes which point to itself
    const G = std.AutoHashMap(u32, *N); // a graph is a map from a node id to the set of other nodes which point to it
    alloc: std.mem.Allocator,
    nodes: *G,
    pub fn init(allocator: std.mem.Allocator) Graph {
        const g = allocator.create(G) catch unreachable;
        g.* = G.init(allocator);
        return .{ .nodes = g, .alloc = allocator };
    }
    pub fn initNode(self: Graph, id: u32) !void {
        const new = try self.alloc.create(N);
        new.* = N.init(self.alloc);
        try self.nodes.put(id, new);
    }
    pub fn connect(self: Graph, from: u32, to: u32) !void {
        if (!self.nodes.contains(from))
            try self.initNode(from);
        if (!self.nodes.contains(to))
            try self.initNode(to);
        try self.nodes.get(to).?.put(from, {});
    }
    pub fn get(self: Graph, id: u32) ?*N {
        return self.nodes.get(id);
    }
    pub fn show(self: Graph) void {
        var kiter = self.nodes.keyIterator();
        print("\n", .{});
        while (kiter.next()) |k| {
            var nkiter = self.nodes.get(k.*).?.keyIterator();
            print("( ", .{});
            while (nkiter.next()) |f| {
                print(" {d} ", .{f.*});
            }
            print(") -> {d}\n", .{k.*});
        }
    }
};

pub fn validate(input: puzzleInput, alloc: std.mem.Allocator) ![]bool {
    var out = try alloc.alloc(bool, input.updates.len);

    var g = Graph.init(alloc);

    for (input.rules) |r| {
        // form a directed graph where if page x must come before page y, node x points to node y in the graph
        try g.connect(r.before, r.after);
    }

    for (input.updates, 0..) |update, u| {
        var contains = std.AutoHashMap(u32, void).init(alloc);
        for (update) |page| { // figure out which pages occur anywhere in the update first.
            try contains.put(page, {});
        }
        var seen = std.AutoHashMap(u32, void).init(alloc); // running track of which pages have been seen.
        pages: for (update) |page| { // for every page in the update
            if (g.get(page)) |p| { // if dependency graph contains any nodes for this page,
                for (p.keys()) |req| { // iterate over the dependencies of the page number,
                    if (contains.contains(req) and !seen.contains(req)) { // if the dependency occurrs somewhere in the update, but has NOT already been seen,
                        out[u] = false; // then the rule has been broken. set invalid and go to next update.
                        break :pages;
                    }
                }
                try seen.put(page, {});
            }
        } else out[u] = true;
    }

    return out;
}
pub fn solvePart1(input: puzzleInput, flags: []bool) usize {
    var out: usize = 0;
    for (input.updates, flags) |update, flag| {
        if (flag) {
            out += update[update.len / 2];
        }
    }
    return out;
}
pub fn order(update: []const u32, g: Graph, alloc: std.mem.Allocator) ![]u32 {
    var out = try alloc.alloc(u32, update.len);

    var c = std.AutoArrayHashMap(u32, void).init(alloc); // a set containing all node ids present in the update
    for (update) |page| {
        try c.put(page, {});
    }

    var outset = std.AutoHashMap(u32, void).init(alloc); // a set containing all node ids which have been placed in the ordered output array
    for (0..update.len) |i| { // for each position in the ordered output array,
        fnodes: for (c.keys()) |k| { // for all the page numbers in the update list,
            if (!outset.contains(k)) {
                if (g.get(k)) |reqs| { // get the prereq pages for each page numbere
                    for (reqs.keys()) |req| { // for each prereq page of the current page,
                        // Check if the prereq page is somewhere in the update, but hasn't yet been placed.
                        if (c.contains(req) and !outset.contains(req)) {
                            continue :fnodes; // If so, then the node cannot be placed yet. check the next node.
                        }
                    }
                    // If we checked all the requirements without skipping the node, then the node has no unsatisfied dependencies.
                    out[i] = k; // place the dependency-less node in the array,
                    try outset.put(k, {}); // and in the set of placed nodes,
                    break :fnodes;
                }
            }
        }
    }

    return out;
}

pub fn solvePart2(input: puzzleInput, flags: []const bool, alloc: std.mem.Allocator) !usize {
    var out: usize = 0;

    var g = Graph.init(alloc);
    for (input.rules) |r| {
        // form a directed graph where if page x must come before page y, node x points to node y in the graph
        try g.connect(r.before, r.after);
    }

    for (input.updates, flags) |update, flag| {
        if (!flag) {
            const ordered = try order(update, g, alloc);
            //print("\nupdate {d}: before ordering: {d}, after ordering: {d}", .{ i, update, ordered });
            out += ordered[ordered.len / 2];
        }
    }
    return out;
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const input = readInput("src\\inputs\\d5a.txt", alloc) catch |err| {
        print("\nfailed to create input arrays with error: '{s}'", .{@errorName(err)});
        return;
    };
    print("\nread input with {d} rules and {d} update lists:", .{ input.rules.len, input.updates.len });

    const flags = validate(input, alloc) catch |err| {
        print("\nidentifying valid updates faled with error: {s}", .{@errorName(err)});
        return;
    };
    const p1 = solvePart1(input, flags);
    print("\nsum of middle number of properly ordered updates is {d}", .{p1});

    const p2 = solvePart2(input, flags, alloc) catch |err| {
        print("\nsolving part 2 failed with error: {s}", .{@errorName(err)});
        return;
    };
    print("\nsum of middle number of incorrect updates after properly ordering them is {d}", .{p2});
}

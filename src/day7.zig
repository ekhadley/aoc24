const std = @import("std");
const print = std.debug.print;

const puzzleInput = std.ArrayList(std.ArrayList(i64));
pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !puzzleInput {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const fsize = try file.getEndPos();
    const filestr = try file.readToEndAlloc(alloc, fsize);

    var val: i64 = 0;
    var reports = puzzleInput.init(alloc);
    try reports.append(std.ArrayList(i64).init(alloc));
    for (filestr) |c| {
        if (c >= '0' and c <= '9') {
            val = 10 * val + (c - '0');
        } else if (c != ':') {
            try reports.items[reports.items.len - 1].append(val);
            val = 0;
            if (c == '\n') try reports.append(std.ArrayList(i64).init(alloc));
        }
    }
    try reports.items[reports.items.len - 1].append(val);
    return reports;
}

pub fn possible(vals: []const i64, place: usize, cur: i64) bool {
    if (place == vals.len) return cur == vals[0];
    if (cur > vals[0]) return false;
    return possible(vals, place + 1, cur + vals[place]) or possible(vals, place + 1, cur * vals[place]);
}

pub fn isPossible(vals: []const i64) bool {
    return possible(vals, 2, vals[1]);
}

pub fn part1(inp: puzzleInput) i64 {
    var out: i64 = 0;
    for (inp.items) |vals| {
        if (isPossible(vals.items)) {
            out += vals.items[0];
        }
    }
    return out;
}

pub fn concat(a: i64, b: i64) i64 {
    var tempb = b;
    var newa = a;
    while (tempb > 0) {
        //tempb /= 10;
        tempb = @divFloor(tempb, 10);
        newa *= 10;
    }
    return newa + b;
}

pub fn possible2(vals: []const i64, place: usize, cur: i64) bool {
    if (place == vals.len) return cur == vals[0];
    if (cur > vals[0]) return false;
    return possible2(vals, place + 1, cur + vals[place]) or possible2(vals, place + 1, cur * vals[place]) or possible2(vals, place + 1, concat(cur, vals[place]));
}

pub fn isPossible2(vals: []const i64) bool {
    return possible2(vals, 2, vals[1]);
}
pub fn part2(inp: puzzleInput) i64 {
    var out: i64 = 0;
    for (inp.items) |vals| {
        if (isPossible2(vals.items)) {
            out += vals.items[0];
        }
    }
    return out;
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const input = readInput("src\\inputs\\d7a.txt", alloc) catch |err| {
        print("\nfailed to read input  with error: {s}", .{@errorName(err)});
        return;
    };
    print("\nread puzzle input with {d} lines.", .{input.items.len});

    const p1 = part1(input);
    print("\nsum of satisfiable calibration values with add and mul is {d}", .{p1});

    const p2 = part2(input);
    print("\nsum of satisfiable calibration values with add, mul, and concat is {d}", .{p2});

    if (input.items.len < 20) {
        for (input.items, 0..) |vals, i| {
            print("\n[{d}]: {d}: {s}satisfiable ({s}satisfiable)", .{ i, vals.items, if (isPossible(vals.items)) "" else "un", if (isPossible2(vals.items)) "" else "un" });
        }
    }
}

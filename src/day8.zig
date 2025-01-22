const std = @import("std");
const print = std.debug.print;

const Pos = struct {
    x: i32,
    y: i32,
    pub fn init(x: i32, y: i32) Pos {
        return .{ .x = x, .y = y };
    }
};
const PuzzleInput = struct {
    sats: std.AutoArrayHashMap(u8, *std.ArrayList(Pos)),
    h: usize,
    w: usize,
    pub fn show(self: PuzzleInput) void {
        print("\ngrid has h: {d} and w: {d}", .{ self.h, self.w });
        for (self.sats.keys()) |k| {
            print("\n{c}: [", .{k});
            for (self.sats.get(k).?.items) |p| {
                print(" ({d}, {d}) ", .{ p.x, p.y });
            }
            print("]", .{});
        }
    }
};

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !PuzzleInput {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const filestr = try file.readToEndAlloc(alloc, try file.getEndPos());

    const w = for (filestr, 0..) |c, i| {
        if (c == '\n') {
            break i;
        }
    } else filestr.len;
    const h = filestr.len / (w + 1);

    var sats = std.AutoArrayHashMap(u8, *std.ArrayList(Pos)).init(alloc);
    for (0..h) |y| {
        for (0..w) |x| {
            const c = filestr[y * (w + 1) + x];
            if (c != '\n' and c != '.') {
                if (sats.get(c)) |s| {
                    try s.append(Pos.init(@intCast(x), @intCast(y)));
                } else {
                    //var new_s = std.ArrayList(Pos).init(alloc);
                    var new_s = try alloc.create(std.ArrayList(Pos));
                    new_s.* = std.ArrayList(Pos).init(alloc);
                    try new_s.append(Pos.init(@intCast(x), @intCast(y)));
                    try sats.put(c, new_s);
                }
            }
        }
    }
    return .{ .sats = sats, .h = h, .w = w };
}

pub fn findAntinodes(s1: Pos, s2: Pos) struct { Pos, Pos } {
    const dx: i32 = s2.x - s1.x;
    const dy: i32 = s2.y - s1.y;
    return .{ Pos.init(s1.x - dx, s1.y - dy), Pos.init(s2.x + dx, s2.y + dy) };
}

pub fn inBounds(input: PuzzleInput, x: i32, y: i32) bool {
    return x >= 0 and x < input.w and y >= 0 and y < input.h;
}
pub fn posInBounds(input: PuzzleInput, pos: Pos) bool {
    return inBounds(input, pos.x, pos.y);
}

pub fn part1(input: PuzzleInput, alloc: std.mem.Allocator) !usize {
    var uniqueNodes = std.AutoHashMap(Pos, void).init(alloc);

    var iter = input.sats.iterator();
    while (iter.next()) |s| {
        for (s.value_ptr.*.items) |pos1| {
            for (s.value_ptr.*.items) |pos2| {
                if (pos1.x > pos2.x or pos1.y > pos2.y) {
                    const an1, const an2 = findAntinodes(pos1, pos2);
                    if (posInBounds(input, an1))
                        try uniqueNodes.put(an1, {});
                    if (posInBounds(input, an2))
                        try uniqueNodes.put(an2, {});
                }
            }
        }
    }
    return uniqueNodes.count();
}

pub fn findAntinodesWithHarmonics(input: PuzzleInput, s1: Pos, s2: Pos, alloc: std.mem.Allocator) !std.ArrayList(Pos) {
    const dx: i32 = s2.x - s1.x;
    const dy: i32 = s2.y - s1.y;
    var out = std.ArrayList(Pos).init(alloc);
    try out.append(s1);
    try out.append(s2);
    var x = s1.x - dx;
    var y = s1.y - dy;
    while (inBounds(input, x, y)) {
        try out.append(Pos.init(x, y));
        x -= dx;
        y -= dy;
    }
    x = s2.x + dx;
    y = s2.y + dy;
    while (inBounds(input, x, y)) {
        try out.append(Pos.init(x, y));
        x += dx;
        y += dy;
    }
    return out;
}

pub fn part2(input: PuzzleInput, alloc: std.mem.Allocator) !usize {
    var uniqueNodes = std.AutoHashMap(Pos, void).init(alloc);

    var iter = input.sats.iterator();
    while (iter.next()) |s| {
        for (s.value_ptr.*.items) |pos1| {
            for (s.value_ptr.*.items) |pos2| {
                if (pos1.x > pos2.x or pos1.y > pos2.y) {
                    for ((try findAntinodesWithHarmonics(input, pos1, pos2, alloc)).items) |an| {
                        if (uniqueNodes.get(an)) |_| {} else {
                            print("\nadding antinode ({d}, {d}) for satellites at ({d}, {d}) and ({d}, {d})", .{ an.x, an.y, pos1.x, pos1.y, pos2.x, pos2.y });
                        }
                        try uniqueNodes.put(an, {});
                    }
                }
            }
        }
    }
    return uniqueNodes.count();
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const input = readInput("src\\inputs\\d8a.txt", alloc) catch |err| {
        print("\nfailed to read puzzle input with error: {s}", .{@errorName(err)});
        return;
    };
    if (input.sats.count() < 20)
        input.show();

    const p1 = part1(input, alloc) catch |err| {
        print("\ncounting uinque antinodes positions failed with error: {s}", .{@errorName(err)});
        return;
    };
    print("\nthere are {d} unique antinode positions in the input", .{p1});

    const p2 = part2(input, alloc) catch |err| {
        print("\ncounting uinque antinodes positions with harmonics failed with error: {s}", .{@errorName(err)});
        return;
    };
    print("\nwith harmonics, there are {d} unique antinode positions in the input", .{p2});
}

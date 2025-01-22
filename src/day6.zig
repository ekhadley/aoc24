const std = @import("std");
const print = std.debug.print;

const Grid = struct {
    str: []u8,
    len: usize,
    h: usize,
    w: usize,

    pub fn init(str: []u8, h: usize, w: usize) Grid {
        return .{ .str = str, .h = h, .w = w, .len = str.len };
    }
    pub fn idx(self: Grid, x: usize, y: usize) usize {
        return y * (self.w + 1) + x;
    }
    pub fn at(self: Grid, x: usize, y: usize) u8 {
        return self.str[self.idx(x, y)];
    }
    pub fn inBounds(self: Grid, x: usize, y: usize) bool {
        return x >= 0 and x < self.w and y >= 0 and y < self.h;
    }
};
const Pos = struct {
    x: usize,
    y: usize,
    dir: u8,
    pub fn init(x: usize, y: usize, dir: u8) Pos {
        return .{ .x = x, .y = y, .dir = dir };
    }
};

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !struct { Grid, Pos } {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const filestr = try file.readToEndAlloc(alloc, try file.getEndPos());

    const w = for (filestr, 0..) |c, i| {
        if (c == '\n') {
            break i - 1;
        }
    } else filestr.len;

    const h = filestr.len / (w + 2);
    var g = Grid.init(filestr, h, w + 1);

    var p: Pos = undefined;
    var x: usize = 0;
    while (x < g.w) : (x += 1) {
        var y: usize = 0;
        while (y < g.h) : (y += 1) {
            const c = g.at(x, y);
            if (c != '.' and c != '#') {
                var d: u8 = 0;
                for ("^>v<") |dir| {
                    if (c == dir) {
                        p = .{ .x = x, .y = y, .dir = d };
                        g.str[g.idx(x, y)] = '.';
                        break;
                    }
                    d += 1;
                }
            }
        }
    }
    return .{ g, p };
}

pub fn getNextPos(grid: Grid, p: Pos) struct { Pos, bool } { // (next calculated position, is it still inbounds)
    var newx: i32 = @intCast(p.x);
    var newy: i32 = @intCast(p.y);
    switch (p.dir) {
        0 => newy -= 1,
        1 => newx += 1,
        2 => newy += 1,
        3 => newx -= 1,
        else => unreachable,
    }

    if (newx < 0 or newx >= grid.w or newy < 0 or newy >= grid.h) { // if out of bounds,
        return .{ p, false }; // return original position with inbounds flag set false
    } else if (grid.at(@intCast(newx), @intCast(newy)) == '#') { // if inbounds and current position is obstacle,
        //return .{ getNextPos(grid, Pos.init(p.x, p.y, (p.dir + 1) % 4))[0], true }; // take new step from previous position after turning
        return .{ Pos.init(p.x, p.y, (p.dir + 1) % 4), true }; // take new step from previous position after turning
    } else { // if in bounds and didnt hit obstacle,
        return .{ Pos.init(@intCast(newx), @intCast(newy), p.dir), true }; // new position is current position
    }
}
const Path = std.ArrayList(Pos);

pub fn getPath(grid: Grid, startPos: Pos, alloc: std.mem.Allocator) !struct { Path, bool } { // returns the list of tiles visited and wether it is a loop or not
    var path = Path.init(alloc); // list of positions/directions over the whole path
    var visited = std.AutoHashMap(Pos, void).init(alloc); // set of tiles visited+direction when there
    var inbounds = true;
    var pos = startPos;
    while (inbounds) {
        try path.append(pos); // log the tile as visited
        if (visited.contains(pos)) { // if we have already been to this tile, facing the same direction, we are looping
            return .{ path, true };
        } else {
            try visited.put(pos, {}); // otherwise record the tile as visited
        }
        const next = getNextPos(grid, pos); // return the next pos and if it is in bounds
        pos, inbounds = next;
    }
    return .{ path, false }; // didnt exit early due to loop detection, so no loop
}
pub fn part1(grid: Grid, path: Path, alloc: std.mem.Allocator) !usize {
    var visited = std.AutoHashMap(usize, void).init(alloc); // set of tiles visited
    for (path.items) |p| {
        try visited.put(grid.idx(p.x, p.y), {});
    }
    return visited.count();
}

pub fn part2(g: Grid, path: Path, alloc: std.mem.Allocator) !usize {
    var out: usize = 0;
    var visited = std.AutoHashMap(usize, void).init(alloc);
    const startPos = path.items[0];
    try visited.put(g.idx(startPos.x, startPos.y), {});
    var i: usize = 1;
    while (i < path.items.len) : (i += 1) {
        const pos = path.items[i];
        const idx = g.idx(pos.x, pos.y);
        if (!visited.contains(idx)) {
            try visited.put(idx, {});
            g.str[idx] = '#';
            _, const hasloop = try getPath(g, startPos, alloc);
            if (hasloop) {
                out += 1;
            }
            g.str[idx] = '.';
        }
    }
    return out;
}
pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const grid, const startPos = readInput("src\\inputs\\d6a.txt", alloc) catch |err| {
        print("\nreading input file failed with error: {s}", .{@errorName(err)});
        return;
    };
    print("\ninput has height {d}, width {d}. The guard's starting position is x: {d}, y: {d}, dir: {d}", .{ grid.h, grid.w, startPos.x, startPos.y, startPos.dir });

    const path1, const path1hasloop = getPath(grid, startPos, alloc) catch |err| {
        print("\nfailed to find the path taken in part 1: {s}", .{@errorName(err)});
        return;
    };
    const p1 = part1(grid, path1, alloc) catch |err| {
        print("\nfailed to count unique tiles in part 1's path. error: {s}", .{@errorName(err)});
        return;
    };
    print("\nthe guard visits {d} unique tiles. it contains {s} loop.", .{ p1, if (path1hasloop) "a" else "no" });

    const p2 = part2(grid, path1, alloc) catch |err| {
        print("\nfailed to solve part 2 with error: {s}", .{@errorName(err)});
        return;
    };
    print("\nthere are {d} positions where placing an obstacle would result in a loop.", .{p2});
}

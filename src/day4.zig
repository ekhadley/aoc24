const std = @import("std");
const print = std.debug.print;

const puzzleInput = struct {
    str: []const u8,
    h: usize,
    w: usize,
};
pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !puzzleInput {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const fsize = try file.getEndPos();
    const filestr = try file.readToEndAlloc(alloc, fsize);

    var width: usize = 0;
    while (filestr[width] != '\n') : (width += 1) {}

    return .{ .str = filestr, .w = width, .h = filestr.len / width };
}
// [row, column]
// [0,0], [0, 1], [0, 2] .. [0, w], [1, 0], [1, 1]...
pub fn scanHorizontal(input: puzzleInput) usize {
    var count: usize = 0;

    const targ1 = "XMAS";
    const targ2 = "SAMX";
    var p1: usize = 0;
    var p2: usize = 0;
    for (input.str) |c| {
        p1 = if (c == targ1[p1]) p1 + 1 else (if (c == targ1[0]) 1 else 0);
        p2 = if (c == targ2[p2]) p2 + 1 else (if (c == targ2[0]) 1 else 0);
        if (p1 == targ1.len) {
            count += 1;
            p1 = 0;
        }
        if (p2 == targ2.len) {
            count += 1;
            p2 = 0;
        }
    }
    return count;
}
// [0,0], [1, 0], [2, 0] .. [h, 0], [0, 1], [1, 1]...
pub fn scanVertical(input: puzzleInput) usize {
    var count: usize = 0;

    const targ1 = "XMAS";
    const targ2 = "SAMX";
    var p1: usize = 0;
    var p2: usize = 0;

    var c: u8 = 0;
    for (0..input.w) |x| {
        for (0..input.h) |y| {
            c = input.str[x + y * (input.w + 1)];

            p1 = if (c == targ1[p1]) p1 + 1 else (if (c == targ1[0]) 1 else 0);
            p2 = if (c == targ2[p2]) p2 + 1 else (if (c == targ2[0]) 1 else 0);
            if (p1 == targ1.len) {
                count += 1;
                p1 = 0;
            }
            if (p2 == targ2.len) {
                count += 1;
                p2 = 0;
            }
        }
        p1 = 0;
        p2 = 0;
    }
    return count;
}

const vec2d = struct {
    x: usize,
    y: usize,
};

// [0, 0], (reset progress) [1, 0], [0, 1], (reset progress) [2, 0], [1, 1], [0, 2], (reset progress) [3, 0], [2, 1] ...
// can actually just start and end when the diags are too short to contain any target sequence.
pub fn scanUpstairs(input: puzzleInput, targ1: []const u8, targ2: []const u8, allocator: std.mem.Allocator) std.ArrayList(vec2d) {
    var out = std.ArrayList(vec2d).init(allocator);

    var p1: usize = 0;
    var p2: usize = 0;

    var c: u8 = 0;
    var y: usize = targ1.len - 1;
    var x: usize = 0;

    var rx: usize = 0;
    var ry: usize = y + 1;
    while (rx <= input.w - targ1.len + 1) {
        c = input.str[x + y * (input.w + 1)];

        p1 = if (c == targ1[p1]) p1 + 1 else (if (c == targ1[0]) 1 else 0);
        p2 = if (c == targ2[p2]) p2 + 1 else (if (c == targ2[0]) 1 else 0);
        if (p1 == targ1.len) {
            out.append(.{ .x = x, .y = y }) catch unreachable;
            p1 = 0;
        }
        if (p2 == targ2.len) {
            out.append(.{ .x = x, .y = y }) catch unreachable;
            p2 = 0;
        }

        if (y == 0 or x == input.w - 1) {
            x = rx;
            y = ry;
            p1 = 0;
            p2 = 0;
            if (ry != input.h - 1) {
                ry += 1;
            } else {
                rx += 1;
            }
        } else {
            x += 1;
            y -= 1;
        }
    }
    return out;
}

pub fn scanDownstairs(input: puzzleInput, targ1: []const u8, targ2: []const u8, allocator: std.mem.Allocator) std.ArrayList(vec2d) {
    var out = std.ArrayList(vec2d).init(allocator);

    var p1: usize = 0;
    var p2: usize = 0;

    var c: u8 = 0;
    var y: usize = input.h - targ1.len; // begin at row min(target sequence)
    var x: usize = 0;

    var rx: usize = 0;
    var ry: usize = y - 1;
    while (rx <= input.w - targ1.len + 1) {
        c = input.str[x + y * (input.w + 1)];

        p1 = if (c == targ1[p1]) p1 + 1 else (if (c == targ1[0]) 1 else 0);
        p2 = if (c == targ2[p2]) p2 + 1 else (if (c == targ2[0]) 1 else 0);

        if (p1 == targ1.len) {
            out.append(.{ .x = x, .y = y }) catch unreachable;
            p1 = 0;
        }
        if (p2 == targ2.len) {
            out.append(.{ .x = x, .y = y }) catch unreachable;
            p2 = 0;
        }

        if (y == input.h - 1 or x == input.w - 1) {
            x = rx;
            y = ry;
            p1 = 0;
            p2 = 0;
            if (ry != 0) {
                ry -= 1;
            } else {
                rx += 1;
            }
        } else {
            x += 1;
            y += 1;
        }
    }
    return out;
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const input = readInput("src\\inputs\\d4a.txt", alloc) catch |err| {
        print("failed to create input arrays with error: '{s}'", .{@errorName(err)});
        return;
    };
    //print("found input with height {d} and width {d}:\n{s}\n", .{ input.h, input.w, input.str });

    const hor = scanHorizontal(input);
    const ver = scanVertical(input);
    const ups = scanUpstairs(input, "XMAS", "SAMX", alloc);
    const dow = scanDownstairs(input, "XMAS", "SAMX", alloc);
    print("\n found {d} horizontal XMAS's", .{hor});
    print("\n found {d} vertical XMAS's", .{ver});
    print("\n found {d} diagonal upstairs XMAS's", .{ups.items.len});
    print("\n found {d} diagonal downstairs XMAS's", .{dow.items.len});
    const total = hor + ver + ups.items.len + dow.items.len;
    print("\n found {d} total XMAS's", .{total});

    const upmas = scanUpstairs(input, "MAS", "SAM", alloc);
    const downmas = scanDownstairs(input, "MAS", "SAM", alloc);
    print("\n found {d} diagonal upstairs MAS's", .{upmas.items.len});
    print("\n found {d} diagonal downstairs MAS's", .{downmas.items.len});

    var xmas: usize = 0;
    for (upmas.items) |upos| {
        for (downmas.items) |dpos| {
            if (upos.x - 1 == dpos.x - 1 and upos.y + 1 == dpos.y - 1) {
                xmas += 1;
                //print("\n found X-MAS centered at [{d}, {d}]", .{ upos.x - 1, upos.y + 1 });
            }
        }
    }
    print("\n found {d} X-MAS's", .{xmas});
}

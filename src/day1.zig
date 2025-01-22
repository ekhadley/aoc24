const std = @import("std");
const print = std.debug.print;

const puzzleInput = struct {
    arr1: std.ArrayList(u32),
    arr2: std.ArrayList(u32),
    len: usize,
};

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !puzzleInput {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var arr1 = std.ArrayList(u32).init(alloc);
    var arr2 = std.ArrayList(u32).init(alloc);

    const fsize = try file.getEndPos();
    const filestr = try file.readToEndAlloc(alloc, fsize);

    var id: u32 = 0;

    for (filestr) |c| {
        if (c == ' ') {
            if (arr1.items.len == arr2.items.len) {
                try arr1.append(id);
                id = 0;
            }
        } else if (c == '\n') {
            try arr2.append(id);
            id = 0;
        } else if (c >= '0') {
            id = 10 * id + (c - '0');
        }
    }
    try arr2.append(id);
    return .{ .arr1 = arr1, .arr2 = arr2, .len = arr1.items.len };
}

pub fn sort(arr: []u32, _size: usize) void {
    var swapped = true;
    var size = _size;

    while (swapped) {
        swapped = false;
        size -= 1;
        for (0..size) |i| {
            if (arr[i] > arr[i + 1]) {
                std.mem.swap(u32, &arr[i], &arr[i + 1]);
                swapped = true;
            }
        }
    }
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const input = readInput("src\\inputs\\d1a.txt", alloc) catch |err| {
        print("failed to create input arrays with error: '{s}'", .{@errorName(err)});
        return;
    };
    const arr1 = input.arr1.items;
    const arr2 = input.arr2.items;
    const len = input.len;
    sort(arr1, len);
    sort(arr2, len);

    var out1: u64 = 0;
    for (0..input.arr1.items.len) |i| {
        out1 += if (arr1[i] > arr2[i]) arr1[i] - arr2[i] else arr2[i] - arr1[i];
    }
    print("solution for first part is: {d}", .{out1});

    var counts = std.AutoHashMap(u32, u32).init(alloc);
    for (arr2) |i| {
        counts.put(i, if (counts.contains(i)) counts.get(i).? + 1 else 1) catch |err| {
            print("failed to increment counter map with error: {s}", .{@errorName(err)});
        };
    }
    var out2: u64 = 0;
    for (arr1) |i| {
        if (counts.contains(i)) {
            out2 += i * counts.get(i).?;
        }
    }
    print("solution for second part is: {d}", .{out2});
}

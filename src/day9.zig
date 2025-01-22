const std = @import("std");
const print = std.debug.print;

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const fsize = try file.getEndPos();
    return try file.readToEndAlloc(alloc, fsize);
}

pub fn expandMap(input: []const u8, alloc: std.mem.Allocator) ![]u32 {
    var len: usize = 0;
    for (input) |c|
        len += c - '0';
    var out = try alloc.alloc(u32, len);

    var i: usize = 0; // current index of the expanded output map
    var id: u32 = 1; // id or 'name' of the current file block.
    var isfree = false; // the compacted map consists of alternating lengths of occuppied blocks, and lengths of free blocks.
    for (input) |c| {
        for (0..(c - '0')) |_| {
            out[i] = if (isfree) 0 else id;
            i += 1;
        }
        if (!isfree)
            id += 1;
        isfree = !isfree;
    }
    return out;
}

pub fn defrag(expanded: []const u32, alloc: std.mem.Allocator) ![]u32 {
    var out = try alloc.alloc(u32, expanded.len);
    var i: usize = 0;
    var j: usize = expanded.len - 1;
    while (i <= j) {
        if (expanded[i] != 0) {
            out[i] = expanded[i];
            i += 1;
        }
        if (expanded[j] == 0) {
            out[j] = 0;
            j -= 1;
        }
        if (expanded[i] == 0 and expanded[j] != 0) {
            out[i] = expanded[j];
            out[j] = 0;
            i += 1;
            j -= 1;
        }
    }
    return out;
}

pub fn niceprint(expanded: []const u32) void {
    print("\n", .{});
    for (expanded) |id| {
        if (id == 0) {
            print(".", .{});
        } else {
            const c: u8 = @intCast(id - 1);
            print("{c}", .{c + '0'});
        }
    }
}

pub fn _defrag2(expanded: []const u32, alloc: std.mem.Allocator) ![]u32 {
    var out = try alloc.alloc(u32, expanded.len);
    std.mem.copyForwards(u32, out, expanded); // w/e

    var id: u32 = 0; // id of current file being scanned
    var ihead: usize = 0;
    var itail: usize = 0;
    var jhead: usize = expanded.len - 1;
    var jtail: usize = expanded.len - 1;
    while (itail <= jhead) {
        print("\nihead: {d} itail: {d}, jhead: {d}, jtail: {d}", .{ ihead, itail, jhead, jtail });
        var moved = false;
        if (out[ihead] != 0) {
            ihead += 1;
            moved = true;
        }
        if (ihead > itail or out[itail] != 0 or out[itail + 1] == 0) {
            itail += 1;
            moved = true;
        }
        if (id == 0 and out[jhead] != 0) {
            id = out[jhead];
        }
        if (jhead > jtail or out[jhead] != id or out[jhead - 1] == id) {
            jhead -= 1;
            moved = true;
        }
        if (out[jtail] != id) {
            jtail -= 1;
            moved = true;
        }
        if (!moved) {
            const freelen = itail - ihead + 1;
            const filelen = jtail - jhead + 1;
            if (freelen >= filelen) {
                for (0..filelen) |i| {
                    out[ihead + i] = id;
                    out[jhead + i] = 0;
                }
                ihead += filelen;
            }
            jhead -= 1;
            jtail -= filelen;
            id = 0;
            niceprint(out);
        }
    }
    return out;
}

const File = struct {
    start: usize,
    len: usize,
    pub fn init(start: usize, len: usize) File {
        return .{ .start = start, .len = len };
    }
};
pub fn printFiles(files: std.ArrayList(File)) void {
    print("\n {d} files: [", .{files.items.len});
    for (files.items) |f| {
        print(" ({d}, {d}) ", .{ f.start, f.len });
    }
    print("]", .{});
}
pub fn defrag2(expanded: []const u32, alloc: std.mem.Allocator) ![]u32 {
    var frees = std.ArrayList(File).init(alloc);
    var files = std.ArrayList(File).init(alloc);

    var cid: u32 = 1;
    var freelen: usize = 0;
    var filelen: usize = 0;
    for (expanded, 0..expanded.len) |id, i| {
        if (id == 0) {
            freelen += 1;
        } else if (freelen != 0) {
            try frees.append(File.init(i - freelen, freelen));
            freelen = 0;
        }
        if (id == cid) {
            filelen += 1;
        } else if (filelen != 0) {
            try files.append(File.init(i - filelen, filelen));
            cid += 1;
            filelen = if (id == cid) 1 else 0;
        }
    }
    if (filelen != 0) {
        try files.append(File.init(expanded.len - filelen, filelen));
    }

    var out = try alloc.alloc(u32, expanded.len);
    std.mem.copyForwards(u32, out, expanded);
    var moved: bool = true;
    while (moved) {
        moved = false;
        for (0..frees.items.len) |freeIndex| {
            const fr = &frees.items[freeIndex];
            for (0..files.items.len) |fileIndex| {
                var fi = &files.items[files.items.len - fileIndex - 1];
                if (fi.len > 0 and fr.len >= fi.len and fi.start > fr.start) {
                    moved = true;
                    for (0..fi.len) |i| {
                        out[fr.start + i] = out[fi.start + fi.len - 1];
                        out[fi.start + i] = 0;
                    }

                    frees.items[freeIndex].start += fi.len;
                    frees.items[freeIndex].len -= fi.len;
                    fi.len = 0; // change the file to zero length to signal it no longer exists at that position.

                }
            }
        }
    }
    return out;
}

pub fn checksum(defragged: []const u32) usize {
    var cs: usize = 0;
    for (defragged, 0..) |id, i| {
        if (id != 0) cs += (id - 1) * i;
    }
    return cs;
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const input = readInput("src\\inputs\\d9a.txt", alloc) catch |err| {
        print("\nfailed to read input with error: {s}", .{@errorName(err)});
        return;
    };
    const map = expandMap(input, alloc) catch |err| {
        print("\nfailed to expand input map with error : {s}", .{@errorName(err)});
        return;
    };

    const defragged = defrag(map, alloc) catch |err| {
        print("failed to defrag drive with error: {s}", .{@errorName(err)});
        return;
    };
    const checksum1 = checksum(defragged);

    const defragged2 = defrag2(map, alloc) catch |err| {
        print("failed to defrag drive with error: {s}", .{@errorName(err)});
        return;
    };
    const checksum2 = checksum(defragged2);

    print("\nread input: '{s}'", .{input});
    print("\nexpanded map: ", .{});
    niceprint(map);

    print("\n\ndefragged drive: ", .{});
    niceprint(defragged);
    print("\nchecksum of defragged disk is {d}", .{checksum1});

    print("\n\nwhole-file defragged drive: {d}", .{defragged2});
    niceprint(defragged2);
    print("\nchecksum of whole-file defragged disk is {d}", .{checksum2});
}

const std = @import("std");
const print = std.debug.print;

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) !std.ArrayList(std.ArrayList(i32)) {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const fsize = try file.getEndPos();
    const filestr = try file.readToEndAlloc(alloc, fsize);

    var val: i32 = 0;
    var reports = std.ArrayList(std.ArrayList(i32)).init(alloc);
    try reports.append(std.ArrayList(i32).init(alloc));
    for (filestr) |c| {
        if (c >= '0' and c <= '9') {
            val = 10 * val + (c - '0');
        } else {
            try reports.items[reports.items.len - 1].append(val);
            val = 0;
            if (c == '\n') try reports.append(std.ArrayList(i32).init(alloc));
        }
    }
    try reports.items[reports.items.len - 1].append(val);
    return reports;
}

pub fn unsafeLevels(prevgap: i32, nextgap: i32) bool {
    return prevgap == 0 or prevgap < -3 or prevgap > 3 or nextgap == 0 or nextgap < -3 or nextgap > 3 or (prevgap > 0) != (nextgap > 0);
}
pub fn safeReport(report: []i32) bool {
    var prevgap: i32 = 0;
    var nextgap: i32 = 0;
    for (1..report.len - 1) |j| {
        prevgap = report[j] - report[j - 1];
        nextgap = report[j + 1] - report[j];
        if (unsafeLevels(prevgap, nextgap)) return false;
    }
    return true;
}
pub fn countSafeReports(reports: *const std.ArrayList(std.ArrayList(i32))) usize {
    var safe: usize = 0;
    for (0..reports.items.len) |i| {
        const report = reports.items[i].items;
        if (safeReport(report)) safe += 1;
    }
    return safe;
}

pub fn safeWithDampener(report: []i32, ignore: usize) bool {
    var prevgap: i32 = 0;
    var nextgap: i32 = 0;

    var j: usize = if (ignore != 0) 1 else 2;
    while (j < ((if (ignore == report.len - 1) report.len - 2 else report.len - 1))) : (j += 1) {
        if (j == ignore) continue;
        prevgap = report[j] - report[(if (j == ignore + 1) j - 2 else j - 1)]; // if we are one past the ignore, look two backwards
        nextgap = report[(if (j + 1 == ignore) j + 2 else j + 1)] - report[j]; // if we are just before the ignore, look two forwards
        if (unsafeLevels(prevgap, nextgap)) return false; // if still unsafe
        //print("\nj: {d} prevgap: {d} nextgap: {d}", .{ j, prevgap, nextgap });
    }
    return true;
}

pub fn countSafeReportsWithDampener(reports: std.ArrayList(std.ArrayList(i32))) usize {
    var safe: usize = 0;

    for (0..reports.items.len) |i| {
        const report = reports.items[i].items;
        for (0..report.len) |j| {
            if (safeWithDampener(report, j)) {
                safe += 1;
                break;
            }
        }
    }
    return safe;
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const reports = readInput("src\\inputs\\d2a.txt", alloc) catch |err| {
        print("failed to create input arrays with error: '{s}'", .{@errorName(err)});
        return;
    };

    print("\nsafe reports: {d}", .{countSafeReports(&reports)});
    print("\nsafe reports with dampener {d}", .{countSafeReportsWithDampener(reports)});
}

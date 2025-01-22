const std = @import("std");
const print = std.debug.print;

pub fn readInput(comptime filename: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const fsize = try file.getEndPos();
    return try file.readToEndAlloc(alloc, fsize);
}

pub fn isdigit(c: u8) bool {
    return (c >= '0' and c <= '9');
}

const FilterState = struct {
    dests: *std.AutoHashMap(u8, usize),

    pub fn init(alloc: std.mem.Allocator) FilterState {
        //const dest_p = alloc.create(std.AutoHashMap(u8, usize)) catch |err| {
        //    print("Could not allocate destination map for FilterState. Error: {s}", .{@errorName(err)});
        //};
        const dest_p = alloc.create(std.AutoHashMap(u8, usize)) catch unreachable;
        dest_p.* = std.AutoHashMap(u8, usize).init(alloc);
        return .{ .dests = dest_p };
    }
    pub fn addLiteralRule(self: *FilterState, char: u8, dest: usize) void {
        self.dests.put(char, dest) catch |err| {
            print("failed to add rule '{c}' -> state {d} with error: {s}", .{ char, dest, @errorName(err) });
        };
    }
    pub fn addUnaryRule(self: *FilterState, comptime unaryRule: fn (c: u8) bool, dest: usize) void {
        var i: u8 = 0;
        while (i < 127) : (i += 1) {
            if (unaryRule(i))
                self.addLiteralRule(i, dest);
        }
    }
    pub fn getNextState(self: *FilterState, c: u8) usize {
        if (self.dests.get(c)) |next| return next; // capturing value of optional
        return 0; // return when no value captured
    }
};

const matchResults = struct {
    starts: std.ArrayList(usize),
    lens: std.ArrayList(usize),

    pub fn show(this: @This(), string: []const u8) void {
        print("\nmatch results for '{s}'", .{string});
        var len: usize = 0;
        for (this.starts.items, 0..) |start, i| {
            len = this.lens.items[i];
            print("\nmatch at {d}: '{s}'", .{ start, string[start .. start + len] });
        }
    }
};

const Filter = struct {
    alloc: std.mem.Allocator,
    states: *std.ArrayList(FilterState),
    numStates: usize,

    pub fn init(allocator: std.mem.Allocator) Filter {
        //var _states = std.ArrayList(FilterState).init(allocator);
        const state_p = allocator.create(std.ArrayList(FilterState)) catch unreachable;
        state_p.* = std.ArrayList(FilterState).init(allocator);
        return .{
            .alloc = allocator,
            .states = state_p,
            .numStates = 0,
        };
    }

    pub fn addState(self: *Filter, state: FilterState) void {
        self.states.append(state) catch |err| {
            print("Failed to add new state to filter with error '{s}'", .{@errorName(err)});
        };
        self.numStates += 1;
    }
    pub fn getMatches(self: *Filter, str: []const u8) matchResults {
        var starts = std.ArrayList(usize).init(self.alloc);
        var lens = std.ArrayList(usize).init(self.alloc);

        var currentStart: usize = 0;
        var currentState: usize = 0;

        for (str, 0..) |c, i| {
            currentState = self.states.items[currentState].getNextState(c);
            if (currentState == 1) currentStart = i;
            if (currentState == self.numStates) { // final state (indicating a match) has value equal to number of total states.
                starts.append(currentStart) catch |err| {
                    print("Failed to append match to result ArrayList 'starts' with error '{s}'", .{@errorName(err)});
                };
                lens.append(i - currentStart + 1) catch |err| {
                    print("Failed to append match to result ArrayList 'lers' with error '{s}'", .{@errorName(err)});
                };
                currentState = 0;
            }
        }
        return .{ .starts = starts, .lens = lens };
    }
};

pub fn parseMul(mul: []const u8) i32 {
    var op1: i32 = 0;
    var op2: i32 = 0;

    var i: usize = 0;
    while (mul[i] != ',') : (i += 1) {
        if (isdigit(mul[i])) op1 = op1 * 10 + mul[i] - '0';
    }
    i += 1;
    while (mul[i] != ')') : (i += 1) {
        op2 = op2 * 10 + mul[i] - '0';
    }
    return op1 * op2;
}

pub fn solution() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var mulfilter = Filter.init(alloc);

    var ms0 = FilterState.init(alloc);
    ms0.addLiteralRule('m', 1);
    var ms1 = FilterState.init(alloc);
    ms1.addLiteralRule('u', 2);
    var ms2 = FilterState.init(alloc);
    ms2.addLiteralRule('l', 3);
    var ms3 = FilterState.init(alloc);
    ms3.addLiteralRule('(', 4);
    var ms4 = FilterState.init(alloc);
    ms4.addUnaryRule(isdigit, 4);
    ms4.addLiteralRule(',', 5);
    var ms5 = FilterState.init(alloc);
    ms5.addUnaryRule(isdigit, 5);
    ms5.addLiteralRule(')', 6);
    mulfilter.addState(ms0);
    mulfilter.addState(ms1);
    mulfilter.addState(ms2);
    mulfilter.addState(ms3);
    mulfilter.addState(ms4);
    mulfilter.addState(ms5);

    const inp = readInput("src\\inputs\\d3a.txt", alloc) catch |err| {
        print("Failed to load puzzle input with error: {s}", .{@errorName(err)});
        return;
    };

    const muls = mulfilter.getMatches(inp);
    //muls.show(inp);
    var start: usize = 0;
    var len: usize = 0;
    var out: i32 = 0;
    for (0..muls.starts.items.len) |i| {
        start = muls.starts.items[i];
        len = muls.lens.items[i];
        out += parseMul(inp[start .. start + len]);
        //print("'{s}' = {d}\n", .{ inp[start .. start + len], parseMul(inp[start .. start + len]) });
    }
    print("sum of muls: {d}\n", .{out});

    var dofilter = Filter.init(alloc);
    var ds0 = FilterState.init(alloc);
    ds0.addLiteralRule('d', 1);
    var ds1 = FilterState.init(alloc);
    ds1.addLiteralRule('o', 2);
    var ds2 = FilterState.init(alloc);
    ds2.addLiteralRule('(', 3);
    var ds3 = FilterState.init(alloc);
    ds3.addLiteralRule(')', 4);
    dofilter.addState(ds0);
    dofilter.addState(ds1);
    dofilter.addState(ds2);
    dofilter.addState(ds3);

    var dontfilter = Filter.init(alloc);
    var donts0 = FilterState.init(alloc);
    donts0.addLiteralRule('d', 1);
    var donts1 = FilterState.init(alloc);
    donts1.addLiteralRule('o', 2);
    var donts2 = FilterState.init(alloc);
    donts2.addLiteralRule('n', 3);
    var donts3 = FilterState.init(alloc);
    donts3.addLiteralRule(39, 4); // single quote char as int
    var donts4 = FilterState.init(alloc);
    donts4.addLiteralRule('t', 5);
    var donts5 = FilterState.init(alloc);
    donts5.addLiteralRule('(', 6);
    var donts6 = FilterState.init(alloc);
    donts6.addLiteralRule(')', 7);
    dontfilter.addState(donts0);
    dontfilter.addState(donts1);
    dontfilter.addState(donts2);
    dontfilter.addState(donts3);
    dontfilter.addState(donts4);
    dontfilter.addState(donts5);
    dontfilter.addState(donts6);

    const dos = dofilter.getMatches(inp);
    const donts = dontfilter.getMatches(inp);
    //dos.show(inp);
    //donts.show(inp);

    var enabled: bool = true;
    var doplace: usize = 0;
    var dontplace: usize = 0;
    var mulplace: usize = 0;
    var out2: i32 = 0;
    for (0..inp.len) |i| {
        //print("\n checking {d}: {c}", .{ i, inp[i] });
        if (doplace < dos.starts.items.len) {
            if (i == dos.starts.items[doplace]) {
                enabled = true;
                doplace += 1;
                //print("\n{d}: found do, enabling. doplace: {d}", .{ i, doplace });
            }
        }
        if (dontplace < donts.starts.items.len) {
            if (i == donts.starts.items[dontplace]) {
                enabled = false;
                dontplace += 1;
                //print("\n{d}: found dont, disabling. dontplace: {d}", .{ i, dontplace });
            }
        }
        if (mulplace < muls.starts.items.len) {
            if (i == muls.starts.items[mulplace]) {
                start = muls.starts.items[mulplace];
                len = muls.lens.items[mulplace];
                mulplace += 1;
                if (enabled) {
                    out2 += parseMul(inp[start .. start + len]);
                    //print("\n{d}: found mul while enabled: '{s}'. mulplace: {d}", .{ i, inp[start .. start + len], mulplace });
                }
            }
        }
    }
    print("sum of muls with conditionals: {d}", .{out2});
}

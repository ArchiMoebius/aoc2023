const std = @import("std");

// Zig you nasty pita I want my argv from C...
pub fn getInputFromArgs(args: [][:0]u8) []u8 {
    var file:[]u8 = undefined;
    var next:bool = false;
    file = args[0][0..];
    file[0] = 0x00;

    for(args) |arg| {
        if (next) {
            file = arg[0..];
            break;
        }

        if (std.mem.eql(u8, arg, "--data")) {
            next = true;
        }
    }
    std.log.debug("Parsing: {s}\n", .{file});

    return file;
}

const Row = struct {
    const Self = @This();

    winning: std.AutoHashMap(u32, u32),
    line:[]u8,
    allocator: std.mem.Allocator,
    total:u32 = 0,
    mul:u32 = 0,
    matches:u32 = 0,
    copies:u32 = 0,
    card:[]u8,

    pub fn init(line:[]u8, allocator:std.mem.Allocator) !Self {
        const l:[]u8 = try allocator.alloc(u8, line.len);
        std.mem.copyForwards(u8, l, line);

        return Self {
            .allocator = allocator,
            .winning = std.AutoHashMap(u32, u32).init(allocator),
            .line = l,
            .card = "",
        };
    }

    pub fn debug(self: *Self) void {
        std.log.debug("ROW: {s} = {d}", .{self.line, self.total});
    }

    pub fn parseLine(self: *Self) !void {
        var entry = std.ArrayList(u8).init(self.allocator);
        defer entry.deinit();
        entry.clearAndFree();

        var dit = std.mem.tokenizeSequence(u8, self.line, ":");
        var tmp:[]const u8 = dit.next() orelse return;

        self.card = try self.allocator.alloc(u8, tmp.len);
        std.mem.copyForwards(u8, self.card, tmp);

        std.log.debug("D: {s}\n", .{tmp});
        tmp = dit.next() orelse return;

        var parts = std.mem.tokenizeSequence(u8, tmp, "|");

        tmp = parts.next() orelse return;
        std.log.debug("D: {s}\n", .{tmp});

        var winners = std.mem.tokenizeSequence(u8, tmp, " ");

        while (winners.next()) | number | {
            const value = std.fmt.parseUnsigned(u32, number, 10) catch |err| {
                std.log.debug("E {any}\n", .{err});
                return;
            };
            std.log.debug(">> {d}\n", .{value});
            self.winning.put(value, 0) catch |err| {
                std.log.debug("E {any}\n", .{err});
                return;
            };
        }

        tmp = parts.next() orelse return;
        std.log.debug("Q: {s}\n", .{tmp});

        var possible = std.mem.tokenizeSequence(u8, tmp, " ");

        while (possible.next()) | number | {
            const value = std.fmt.parseUnsigned(u32, number, 10) catch |err| {
                std.log.debug("E {any}\n", .{err});
                return;
            };
            std.log.debug("?? {d}\n", .{value});
            
            if (self.winning.contains(value)) {

                self.matches += 1;

                if (self.total == 0) {
                    self.total = 1;
                }

                std.log.debug("!! {d}\n", .{value});
            }
        }

        std.log.debug("T ================================================================================ {d}\n", .{self.total});
    }

    pub fn deinit(self: *Self) void {
        self.winning.deinit();
        self.allocator.free(self.line);
        self.allocator.free(self.card);
    }
};

pub fn countRowsMul(rows: *std.ArrayList(Row), row:* Row, i: usize) void {
    if (row.matches <= 0) {
        return;
    }

    const min = @min(i+1, rows.items.len);
    const max = @min(min+row.matches, rows.items.len);

    for (rows.items[min..max]) |*copy| {
        for (0..i) |_| {
            std.debug.print(".", .{});
        }
        copy.*.mul += 1;
        std.debug.print("++ => {s} ((( {d} >>> {d}..{d}\n", .{copy.card, copy.mul, min, max});
    }
}

pub fn countRows(rows: *std.ArrayList(Row), row:* Row, i: usize) void {
    const min = @min(i, rows.items.len);
    const max = @min(min+row.matches, rows.items.len);

    for (rows.items[min..max]) |*copy| {
        for (0..i) |_| {
            std.debug.print(".", .{});
        }
        std.debug.print("++ => {s} ((( {d} >>> {d}..{d}\n", .{copy.card, copy.mul, min, max});
        copy.*.mul += 1;
    }
}


pub fn main() !void {

    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const data: []u8 = getInputFromArgs(args);

    if (data[0] == 0x00) {
        std.log.warn("Failed to find file, use --data <filename>\n", .{});
        return;
    }

    var file = try std.fs.cwd().openFile(data, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;

    var total:u64 = 0;

    var rows:std.ArrayList(Row) = std.ArrayList(Row).init(allocator);// only here so we can clean up...blech
    defer rows.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var row = try Row.init(line, allocator);

        try row.parseLine();
        try rows.append(row);
    }

    // for (rows.items, 0..) |*row, idx| {// weird notation...
    //     std.log.debug("\nM: {d} {d} {d}\n", .{row.total, row.matches, idx});
    // }

    for (rows.items, 0..) |*row, idx| {// weird notation...
        countRowsMul(&rows, row, idx);
        std.debug.print("------------------------------------------------------------------------------------\n", .{});
    }

    for (rows.items, 0..) |*row, idx| {// weird notation...
        //countRows(&rows, row, idx);
        std.log.debug("{s} = C({d}) M({d}) [{d}]\n", .{row.card, row.mul, row.matches, idx});
        total += row.copies;
    }

    for (rows.items) |*row| {// weird notation...
        row.deinit();
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total: {d}\n", .{total});
}
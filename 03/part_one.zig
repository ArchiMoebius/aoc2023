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

    sigil: std.ArrayList(u32),
    part: std.ArrayList(u32),
    index: std.AutoHashMap(u32, u32),
    line:[]u8,
    total: u32 = 0,
    allocator: std.mem.Allocator,

    pub fn init(line:[]u8, allocator:std.mem.Allocator) !Self {
        const l:[]u8 = try allocator.alloc(u8, line.len);
        std.mem.copyForwards(u8, l, line);

        return Self {
            .allocator = allocator,
            .sigil = std.ArrayList(u32).init(allocator),
            .part = std.ArrayList(u32).init(allocator),
            .index = std.AutoHashMap(u32, u32).init(allocator),
            .line = l,
        };
    }

    pub fn debug(self: *Self) void {
        std.log.debug("ROW: {s} = {d}", .{self.line, self.total});
        std.log.debug("SIG: {any}", .{self.sigil.items});
        std.log.debug("ITM: {any}\n", .{self.part.items});
    }

    pub fn parseSerial(self: *Self, entry: *std.ArrayList(u8)) void {
        if (entry.items.len <= 0) {
            self.part.append(0) catch |err| {
                std.log.debug("E {any}\n", .{err});
                return;
            };
            return;
        }

        const serial = std.fmt.parseUnsigned(u32, entry.items, 10) catch |err| {
            std.log.debug("E {any}\n", .{err});
            return;
        };

        for (entry.items)|_| {
            self.part.append(serial) catch |err| {
                std.log.debug("E {any}\n", .{err});
                return;
            };
        }

        entry.clearAndFree();

        self.part.append(0) catch |err| {
            std.log.debug("E {any}\n", .{err});
            return;
        };
    }

    pub fn parseLine(self: *Self, line:[]u8) !void {
        var entry = std.ArrayList(u8).init(self.allocator);
        defer entry.deinit();
        entry.clearAndFree();

        for (line) |char| {
            // dot's not the sigil we're looking for
            if (char == 0x2e) {
                self.parseSerial(&entry);
                try self.sigil.append(0);
                continue;
            }
           
            // oh a sigil, cool - next - something like ...333* or .3*3 or ..*
            if (!std.ascii.isDigit(char)) {
                // have we seen numbers yet? if so, parse them
                self.parseSerial(&entry);
                try self.sigil.append(1);
                continue;
            }

            // oh a number - let's get them all
            try self.sigil.append(0);
            try entry.append(char);
        }

        self.parseSerial(&entry);
    }

    pub fn clearPart(self: *Self, idx: u32) void {
        var i:u32 = idx;
        var j:u32 = i+1;

        while (i >= 0 and self.part.items[i] != 0) {
            self.part.items[i] = 0;

            if (i > 0) {
                i = i - 1;
            }
        }

        while (j < self.part.items.len and self.part.items[j] != 0) {
            self.part.items[j] = 0;
            j+= 1;
        }
    }

    pub fn countIfAbove(self: *Self, above: *Row) void {
        var i:u32 = 0;

        // std.debug.print("CHECK {s}\n", .{above.line});
        // std.debug.print("HITSS {s}\n", .{self.line});

        for (above.sigil.items) |entry| {

            if (entry != 0) {
                if (self.part.items[i] != 0) {
                    std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> {d} {d} == {d} A\n", .{i, entry, self.part.items[i]});
                    self.total += self.part.items[i];
                    self.clearPart(i);
                }

                if (self.part.items[i+1] != 0) { // right
                    std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> {d} {d} == {d} AR\n", .{i, entry, self.part.items[i+1]});
                    self.total += self.part.items[i+1];
                    self.clearPart(i+1);
                }

                if (i >= 1 and self.part.items[i-1] != 0) { // left
                    std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> {d} {d} == {d} AL\n", .{i, entry, self.part.items[i-1]});
                    self.total += self.part.items[i-1];
                    self.clearPart(i-1);
                }
            }
            i += 1;
        }
    }

    pub fn countRow(self: *Self) void {
        var i:u32 = 0;

        for (self.sigil.items) |entry| {
            if (entry != 0) {
                if (self.part.items[i] != 0) { // should NEVER happen
                    std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> WUT...HOW...{d} {d} == {d}\n", .{i, entry, self.part.items[i]});
                    self.debug();
                    self.total += self.part.items[i];
                    self.clearPart(i);
                }

                if (self.part.items[i+1] != 0) { // right
                    std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> {d} {d} == {d} HR\n", .{i, entry, self.part.items[i+1]});
                    self.total += self.part.items[i+1];
                    self.clearPart(i+1);
                }

                if (i >= 1 and self.part.items[i-1] != 0) { // left
                    std.debug.print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> {d} {d} == {d} HL\n", .{i, entry, self.part.items[i-1]});
                    self.total += self.part.items[i-1];
                    self.clearPart(i-1);
                }
            }
            i += 1;
        }
    }

    pub fn deinit(self: *Self) void {
        self.sigil.deinit();
        self.part.deinit();
        self.index.deinit();
        self.allocator.free(self.line);
    }
};

pub fn count(bottom:* Row,  middle: *Row, top: *Row) u32 {
    var tmp:u32 = top.total + middle.total + bottom.total;

    top.countRow();
    middle.countRow();
    bottom.countRow();

    tmp = tmp + top.total + middle.total + bottom.total;

    top.total = 0;
    middle.total = 0;
    bottom.total =  0;

    top.countIfAbove(middle);
    middle.countIfAbove(top);
    middle.countIfAbove(bottom);
    bottom.countIfAbove(middle);

    tmp = tmp + top.total + middle.total + bottom.total;

    // std.debug.print("TOP----------------------------\n", .{});
    // top.debug();
    // middle.debug();
    // bottom.debug();
    // std.debug.print("BOT----------------------------\n", .{});

    top.total = 0;
    middle.total =0;
    bottom.total =0;

    return tmp;
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

    var total:u32 = 0;
    var previous_row: ?Row = null;
    var xprevious_row: ?Row = null;

    var rows:std.ArrayList(Row) = std.ArrayList(Row).init(allocator);// only here so we can clean up...blech
    defer rows.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var row = try Row.init(line, allocator);

        try row.parseLine(line);
        try rows.append(row);
        row.debug();

        if (previous_row != null and xprevious_row != null) {
            total += count(&row, @ptrCast(&previous_row), @ptrCast(&xprevious_row));// weird notation...@ptrCast...
        }

        xprevious_row = previous_row;
        previous_row = row;
    }

    previous_row.?.countIfAbove(@ptrCast(&xprevious_row));
    xprevious_row.?.countIfAbove(@ptrCast(&previous_row));

    total += previous_row.?.total;
    total += xprevious_row.?.total;

    xprevious_row.?.debug();
    previous_row.?.debug();

    for (rows.items) |*row| {// weird notation...
        row.deinit();
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total: {d}\n", .{total});
}
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
                try self.sigil.append(char);
                continue;
            }

            // oh a number - let's get them all
            try self.sigil.append(0);
            try entry.append(char);
        }

        self.parseSerial(&entry);
    }

    pub fn count(self: *Self, above: *Row, below: *Row) u64 {
        std.debug.print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n", .{});
        above.debug();
        self.debug();
        below.debug();
        std.debug.print("========================================================================================================\n", .{});
        var total:u64 = 0;
        var last:u32 = 0;
        var hits:std.ArrayList(u32) = std.ArrayList(u32).init(self.allocator);
        defer hits.deinit();

        for (self.sigil.items, 0..) |entry, i| {

            if (entry == 42) {
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>ABOVE
                if (above.part.items[i] != 0) { // directly above
                    last = above.part.items[i];
                    std.log.debug("DA \t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
 
                if (i >= 1 and above.part.items[i-1] != 0 and above.part.items[i-1] != last) { // directly above and left
                    last = above.part.items[i-1];
                    std.log.debug("DAL\t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
                if (i < above.part.items.len and above.part.items[i+1] != 0 and above.part.items[i+1] != last) { // directly above and right
                    last = above.part.items[i+1];
                    std.log.debug("DAR\t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>ROW
                if (i >= 1 and self.part.items[i-1] != 0) { // directly left
                    last = self.part.items[i-1];
                    std.log.debug("DL \t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
                if (i < self.part.items.len and self.part.items[i+1] != 0) { // directly right
                    last = self.part.items[i+1];
                    std.log.debug("DR \t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>BELOW
                if (below.part.items[i] != 0) { // directly below
                    last = below.part.items[i];
                    std.log.debug("DB \t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
                if (i >= 1 and below.part.items[i-1] != 0 and below.part.items[i-1] != last) { // directly below and left
                    last = below.part.items[i-1];
                    std.log.debug("DBL\t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }
                if (i < below.part.items.len and below.part.items[i+1] != 0 and below.part.items[i+1] != last) { // directly below and right
                    last = below.part.items[i+1];
                    std.log.debug("DBR\t{d} {d}\n", .{i, last});
                    hits.append(last) catch |err| {
                        std.log.debug("E {any}\n", .{err});
                        return 0;
                    };
                }

                if (hits.items.len == 2) {
                    total = total + hits.items[0] * hits.items[1];
                    self.sigil.items[i] = 0;
                }

                std.log.debug("hits.items: {any} == {d}\n", .{hits.items, total});
                hits.clearAndFree();
            }
        }

        return total;
    }

    pub fn deinit(self: *Self) void {
        self.sigil.deinit();
        self.part.deinit();
        self.index.deinit();
        self.allocator.free(self.line);
    }
};

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
    var previous_row: ?Row = null;
    var xprevious_row: ?Row = null;

    var rows:std.ArrayList(Row) = std.ArrayList(Row).init(allocator);// only here so we can clean up...blech
    defer rows.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var row = try Row.init(line, allocator);

        try row.parseLine(line);
        try rows.append(row);

        if (previous_row != null and xprevious_row != null) {
            // middle, top, bottom
            total += previous_row.?.count(@ptrCast(&xprevious_row), &row);// weird notation...@ptrCast...
        }

        xprevious_row = previous_row;
        previous_row = row;
    }

    std.debug.print("||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n", .{});

    for (rows.items) |*row| {// weird notation...
        row.deinit();
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total: {d}\n", .{total});
}
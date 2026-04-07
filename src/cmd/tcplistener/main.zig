const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;

const zig_http_server = @import("zig_http_server");

// Doing https://www.boot.dev/courses/learn-http-protocol-golang but in zig
pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    // const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const ip: Io.net.IpAddress = try .parseIp4("127.0.0.1", 42069);
    var server = try ip.listen(io, .{});
    defer server.deinit(io);
    const stream = try server.accept(io);
    defer stream.close(io);
    try stdout_writer.print("user connected\n", .{});
    var reader_buffer: [1024]u8 = undefined;
    var reader = stream.reader(io, &reader_buffer);
    while (try nextLine(&reader.interface, init.gpa)) |line| {
        try stdout_writer.print("{s}\n", .{line});
        init.gpa.free(line);
    }
    try stdout_writer.print("user disconnected\n", .{});
    try stdout_writer.flush();
}

fn nextLine(reader: *Io.Reader, alloc: std.mem.Allocator) !?[]u8 {
    var bytes: std.Io.Writer.Allocating = .init(alloc);
    defer bytes.deinit();

    while (true) {
        const byte = reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                if (bytes.writer.end == 0) return null;
                return try bytes.toOwnedSlice();
            },
            else => return err,
        };

        if (byte == '\n') {
            return try bytes.toOwnedSlice();
        }

        try bytes.writer.writeByte(byte);
    }
}

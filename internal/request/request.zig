const std = @import("std");
const expect = std.testing.expect;
const Io = std.Io;
const gpa = std.testing.allocator;

const String = []const u8;

const ChunkReaderError = error{EOF};

const ChunkReader = struct {
    data: String,
    num_bytes_per_read: u8,
    pos: u8,
    // Read reads up to len(p) or numBytesPerRead bytes from the string per call
    // its useful for simulating reading a variable number of bytes per chunk from a network connection
    pub fn read(cr: ChunkReader, p: *[]u8) ChunkReaderError!u8 {
        if (cr.pos >= cr.data.len) {
            return ChunkReaderError.EOF;
        }
        var endIndex = cr.pos + cr.num_bytes_per_read;
        if (endIndex > cr.data.len) {
            endIndex = cr.data.len;
        }
        p = cr.data[cr.pos..endIndex];
        const n = endIndex - cr.pos;
        cr.pos += n;
        return n;
    }
};

const RequestLine = struct {
    http_version: String,
    request_target: String,
    method: String,
    pub fn deinit(s: RequestLine, alloc: std.mem.Allocator) void {
        alloc.free(s.http_version);
        alloc.free(s.request_target);
        alloc.free(s.method);
    }
};

const Request = struct {
    state: enum { initialized, done },
    request_line: RequestLine,
    pub fn deinit(s: Request, alloc: std.mem.Allocator) void {
        s.request_line.deinit(alloc);
    }
    pub fn parse(s: Request, data: []u8, alloc: std.mem.Allocator) !usize {
        const result = try parseRequestLine(data, alloc);
        switch (result) {
            .none => return 0,
            .value => |r| {
                s.request_line = r.request_line;
                s.state = .done;
                return r.num_of_bytes_consumed;
            },
        }
    }
};

fn strEql(a: String, b: String) bool {
    return std.mem.eql(u8, a, b);
}

const RequestFromReaderError = error{NoText} || ParseRequestLineError;

fn requestFromReader(reader: *Io.Reader, alloc: std.mem.Allocator) RequestFromReaderError!Request {
    const buffer = reader.allocRemaining(alloc, .unlimited) catch return RequestFromReaderError.NoText;
    defer alloc.free(buffer);
    var it = std.mem.splitSequence(u8, buffer, "\r\n");
    const request_line_raw = it.next() orelse return RequestFromReaderError.NoText;
    const request_line = try parseRequestLine(request_line_raw, alloc);
    return Request{ .request_line = request_line };
}

const ParseRequestLineError = error{ NoMethod, NoTarget, NoVersion, OutOfMemory };

const RequestLineResult = union(enum) { none: void, result: struct {
    rl: RequestLine,
    num_of_bytes_consumed: usize,
} };

fn parseRequestLine(line: []const u8, alloc: std.mem.Allocator) ParseRequestLineError!RequestLineResult {
    const num_bytes = std.mem.find(u8, line, "\r\n") orelse return {};
    var it = std.mem.splitScalar(u8, line, ' ');
    const method = it.next() orelse return ParseRequestLineError.NoMethod;
    const request_target = it.next() orelse return ParseRequestLineError.NoTarget;
    const http_version_full = it.next() orelse return ParseRequestLineError.NoVersion;
    const http_version = http_version_full[5..];
    return RequestLineResult{
        .result = .{
            .rl = .{
                .http_version = try alloc.dupe(u8, http_version),
                .request_target = try alloc.dupe(u8, request_target),
                .method = try alloc.dupe(u8, method),
            },
            .num_of_bytes_consumed = num_bytes,
        },
    };
}

// test "Good GET Request line" {
//     var reader: Io.Reader = .fixed("GET / HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");
//     const r = try requestFromReader(&reader, gpa);
//     defer r.deinit(gpa);
//     try expect(strEql("GET", r.request_line.method));
//     try expect(strEql("/", r.request_line.request_target));
//     try expect(strEql("1.1", r.request_line.http_version));
// }

// test "Good GET Request line with path" {
//     var reader: Io.Reader = .fixed("GET /coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");
//     const r = try requestFromReader(&reader, gpa);
//     defer r.deinit(gpa);
//     try expect(strEql("GET", r.request_line.method));
//     try expect(strEql("/coffee", r.request_line.request_target));
//     try expect(strEql("1.1", r.request_line.http_version));
// }

test "Invalid number of parts in request line" {
    var reader: Io.Reader = .fixed("/coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");
    const r = requestFromReader(&reader, gpa);
    try std.testing.expectError(ParseRequestLineError.NoVersion, r);
}

test "Good GET Request line" {
    var reader = ChunkReader{
        .data = "GET / HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n",
        .numBytesPerRead = 3,
    };
    const r = try requestFromReader(reader, gpa);
    try expect(strEql("GET", r.RequestLine.Method));
    try expect(strEql("/", r.RequestLine.RequestTarget));
    try expect(strEql("1.1", r.RequestLine.HttpVersion));
}

test "Good GET Request line with path" {
    var reader = ChunkReader{
        .data = "GET /coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n",
        .numBytesPerRead = 1,
    };
    const r = try requestFromReader(reader, gpa);
    try expect(strEql("GET", r.RequestLine.Method));
    try expect(strEql("/coffee", r.RequestLine.RequestTarget));
    try expect(strEql("1.1", r.RequestLine.HttpVersion));
}

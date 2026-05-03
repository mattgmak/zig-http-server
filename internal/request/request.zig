const std = @import("std");
const expect = std.testing.expect;
const Io = std.Io;
const gpa = std.testing.allocator;

const String = []const u8;

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
    request_line: RequestLine,
    pub fn deinit(s: Request, alloc: std.mem.Allocator) void {
        s.request_line.deinit(alloc);
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

fn parseRequestLine(line: []const u8, alloc: std.mem.Allocator) ParseRequestLineError!RequestLine {
    var it = std.mem.splitScalar(u8, line, ' ');
    const method = it.next() orelse return ParseRequestLineError.NoMethod;
    const request_target = it.next() orelse return ParseRequestLineError.NoTarget;
    const http_version_full = it.next() orelse return ParseRequestLineError.NoVersion;
    const http_version = http_version_full[5..];
    return RequestLine{
        .http_version = try alloc.dupe(u8, http_version),
        .request_target = try alloc.dupe(u8, request_target),
        .method = try alloc.dupe(u8, method),
    };
}

test "Good GET Request line" {
    var reader: Io.Reader = .fixed("GET / HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");
    const r = try requestFromReader(&reader, gpa);
    defer r.deinit(gpa);
    try expect(strEql("GET", r.request_line.method));
    try expect(strEql("/", r.request_line.request_target));
    try expect(strEql("1.1", r.request_line.http_version));
}

test "Good GET Request line with path" {
    var reader: Io.Reader = .fixed("GET /coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");
    const r = try requestFromReader(&reader, gpa);
    defer r.deinit(gpa);
    try expect(strEql("GET", r.request_line.method));
    try expect(strEql("/coffee", r.request_line.request_target));
    try expect(strEql("1.1", r.request_line.http_version));
}

test "Invalid number of parts in request line" {
    var reader: Io.Reader = .fixed("/coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");
    const r = requestFromReader(&reader, gpa);
    try std.testing.expectError(ParseRequestLineError.NoVersion, r);
}

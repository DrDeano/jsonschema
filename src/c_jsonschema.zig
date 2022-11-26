/// C API for the Zig JSON Schema library
const std = @import("std");
const builtin = @import("builtin");
const jsonschema = @import("jsonschema.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = if (builtin.is_test) gpa.allocator() else std.heap.c_allocator;

/// An opaque type used to convert the JSON schema struct pointer to a void pointer that C can use.
const zjs_type = opaque {};

///
/// Parse the C string into a std.json.ValueTree.
/// On success, deinit() will need to be called on the returned value.
///
/// Arguments:
///     IN input: ?[*:0]const u8 - The input string.
///
/// Return: std.json.ValueTree
///     The parsed value tree.
///
/// Error: anyerror (As std.json.Parser.parse() doesn't explicitly defined errors)
///     - NullInput: The input string is null.
///     - Errors relating to std.json.Parser.parse().
///
fn parseJsonTree(input: ?[*:0]const u8) anyerror!std.json.ValueTree {
    if (std.mem.span(input)) |input_slice| {
        var input_parser = std.json.Parser.init(allocator, false);
        defer input_parser.deinit();

        return input_parser.parse(input_slice);
    }
    return error.NullInput;
}

///
/// Parse the C string into a jsonschema.Schema.
///
/// Arguments:
///     IN input: ?[*:0]const u8 - The input string.
///
/// Return: std.json.ValueTree
///     The parsed value tree.
///
/// Error: anyerror (As std.json.Parser.parse() doesn't explicitly defined errors)
///     - NullInput: The input string is null.
///     - Errors relating to std.json.Parser.parse().
///
fn internalCompile(schema: ?[*:0]const u8) anyerror!jsonschema.Schema {
    var schema_tree = try parseJsonTree(schema);
    defer schema_tree.deinit();
    return jsonschema.Schema.compile(allocator, schema_tree.root);
}

///
/// C API for compiling a JSON Schema file.
/// This will use the Zig API Schema.compile().
/// Call zjs_deinit() on clean up.
///
/// Arguments:
///     IN schema: ?[*:0]const u8 - The string containing the JSON schema.
///
/// Return: ?*zjs_type
///     On success, returns a opaque pointer containing the compiled JSON schema.
///     The user doesn't need to understand the internals of this data.
//      On error, returns null.
///
export fn zjs_compile(schema: ?[*:0]const u8) ?*zjs_type {
    var schema_comp = allocator.create(jsonschema.Schema) catch return null;
    errdefer allocator.destroy(schema_comp);
    schema_comp.* = internalCompile(schema) catch return null;
    return @ptrCast(?*zjs_type, schema_comp);
}

///
/// C API for validating JSON data against a compiled schema.
/// This will use the Zip API Schema.validate().
///
/// Arguments:
///     IN zjs: ?*zjs_type - The opaque compiled JSON schema from zjs_compile().
///     IN data: ?[*:0]const u8 - The JSON data to validate.
///
/// Return: bool
///     Whether the data is valid against the schema. Currently, if there was an error parsing
///     the data or invalid arguments, this will return false.
///
export fn zjs_validate(zjs: ?*align(@alignOf(jsonschema.Schema)) zjs_type, data: ?[*:0]const u8) bool {
    if (zjs) |schema_ptr| {
        const schema_comp = @ptrCast(*jsonschema.Schema, schema_ptr);
        var data_tree = parseJsonTree(data) catch return false;
        defer data_tree.deinit();
        return schema_comp.validate(data_tree.root) catch return false;
    }
    return false;
}

///
/// C API for validating JSON data against a schema.
/// This is a simplified version of using zjs_compile() and zjs_validate().
///
/// Arguments:
///     IN schema: ?[*:0]const u8 - The string containing the JSON schema.
///     IN data: ?[*:0]const u8 - The JSON data to validate.
///
/// Return: bool
///     Whether the data is valid against the schema. Currently, if there was an error parsing
///     the schema, data or invalid arguments, this will return false.
///
export fn zjs_compile_and_validate(schema: ?[*:0]const u8, data: ?[*:0]const u8) bool {
    const schema_comp = internalCompile(schema) catch return false;
    var data_tree = parseJsonTree(data) catch return false;
    defer data_tree.deinit();
    return schema_comp.validate(data_tree.root) catch return false;
}

///
/// C API for freeing the compiles JSON schema from zjs_compile().
///
/// Arguments:
///     IN zjs: ?*zjs_type - The opaque compiled JSON schema from zjs_compile().
///
export fn zjs_deinit(zjs: ?*align(@alignOf(jsonschema.Schema)) zjs_type) void {
    if (zjs) |schema_ptr| {
        const schema_comp = @ptrCast(*jsonschema.Schema, schema_ptr);
        allocator.destroy(schema_comp);
    }
}

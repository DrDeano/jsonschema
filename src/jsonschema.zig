/// Zig API for the Zig JSON Schema library
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// The root compiled schema object
pub const Schema = union(enum) {
    Bool: bool,

    const Self = @This();

    /// Error relating to the compilation of the schema
    pub const CompileError = error{
        /// TODO top level compiler
        TODOTopLevel,
    };

    /// Error relating to the validation of JSON data against the schema
    pub const ValidateError = error{
        /// TODO top level compiler
        TODOTopLevel,
    };

    ///
    /// Compile the provided JSON schema into a more refined form for faster validation.
    ///
    /// Arguments:
    ///     IN allocator: Allocator - An allocator.
    ///     IN schema: std.json.Value - The JSON data representing a schema to be compiled.
    ///
    /// Return: Schema
    ///     A schema object that can be used to validate against data. See Schema.validate().
    ///
    /// Error: CompileError
    ///     TODOTopLevel - TODO top level validator
    ///
    pub fn compile(allocator: Allocator, schema: std.json.Value) CompileError!Self {
        _ = allocator;
        _ = schema;
        return CompileError.TODOTopLevel;
    }

    ///
    /// Validate JSON data against a compiled schema.
    ///
    /// Arguments:
    ///     IN self: Self - The compiled schema.
    ///     IN data: std.json.Value - The JSON data to validate.
    ///
    /// Return: bool
    ///     Whether the JSON data matches the schema.
    ///
    /// Error: ValidateError
    ///     TODOTopLevel - TODO top level compiler
    ///
    pub fn validate(self: Self, data: std.json.Value) ValidateError!bool {
        _ = self;
        _ = data;
        return ValidateError.TODOTopLevel;
    }
};

///
/// Compile then validate the data against the provided schema.
/// This will first compile the provided JSON schema then validate against the data.
///
/// Arguments:
///     IN allocator: Allocator - An allocator.
///     IN schema: std.json.Value - The JSON data representing a schema to be compiled.
///     IN data: std.json.Value - The JSON data to test against the schema.
///
/// Return: bool
///     True if the data matched the schema.
///
/// Error: CompileError || ValidateError
///     TODOTopLevel - TODO top level validator
///
pub fn validate(allocator: Allocator, schema: std.json.Value, data: std.json.Value) (Schema.CompileError || Schema.ValidateError)!bool {
    const js_cmp = try Schema.compile(allocator, schema);
    return js_cmp.validate(data);
}

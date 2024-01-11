//! ANSI color codes
//! on Windows these are just defined to be empty strings

pub const color = if(@import("builtin").target.os.tag != .windows) struct {
	pub const black = "\x1B[30m";
	pub const red = "\x1B[31m";
	pub const green = "\x1B[32m";
	pub const yellow = "\x1B[33m";
	pub const blue = "\x1B[34m";
	pub const magenta = "\x1B[35m";
	pub const cyan = "\x1B[36m";
	pub const white = "\x1B[37m";
	pub const default = "\x1B[39m";
} else struct {
	pub const black = "";
	pub const red = "";
	pub const green = "";
	pub const yellow = "";
	pub const blue = "";
	pub const magenta = "";
	pub const cyan = "";
	pub const white = "";
	pub const default = "";
};

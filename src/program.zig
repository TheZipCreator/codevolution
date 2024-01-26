//! Controls program and generation logic

const std = @import("std");
const Random = std.rand.Random;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;


const color = @import("color.zig").color;

// add a usize and isize together, returning 0 if it overflows
fn addSize(a: usize, b: isize) usize {
	const add = @addWithOverflow(@as(isize, @bitCast(a)), b);
	return if(add[1] == 1) 0 else @bitCast(add[0]);
}

const numRegisters = 8;

pub const Instruction = union(enum) {
	const Mode = enum { reg, imm };
	const Op = enum { add, sub, mul, div };	

	mov: struct {
		mode: Mode,
		reg: u8,
		val: u8
	},
	in: u8,
	out: struct {
		mode: Mode,
		val: u8
	},
	jmp: isize,
	op: struct {
		op: Op,
		mode: Mode,
		reg: u8,
		val: u8
	},
	
	// returns a random instruction
	pub fn random(rng: Random) Instruction {
		const t = rng.enumValue(std.meta.Tag(Instruction));
		return switch(t) {
			.mov => .{ .mov = .{ .mode = rng.enumValue(Mode), .reg = rng.int(u8), .val = rng.int(u8) } },
			.in => .{ .in = rng.int(u8) },
			.out => .{ .out = .{ .mode = rng.enumValue(Mode), .val = rng.int(u8) } },
			.jmp => .{ .jmp = rng.intRangeAtMost(isize, -5, 5) },
			.op => .{ .op = .{ .op = rng.enumValue(Op), .mode = rng.enumValue(Mode), .reg = rng.int(u8), .val = rng.int(u8) } }
		};
	}

	inline fn vary(rng: Random, int: *u8, amt: i8) void {
		int.* = @truncate(@as(u16, @bitCast(@as(i16, int.*)+rng.intRangeAtMost(i8, -amt, amt))));
	}

	// randomly mutates this instruction without changing the type
	pub fn mutate(self: *Instruction, rng: Random) void {
		switch(self.*) {
			.mov => switch(rng.enumValue(enum { mode, reg, val })) {
				.mode => self.mov.mode = rng.enumValue(Mode),
				.reg => vary(rng, &self.mov.reg, 1),
				.val => vary(rng, &self.mov.val, 4)
			},
			.in => vary(rng, &self.in, 1),
			.out => switch(rng.enumValue(enum { mode, val })) {
				.mode => self.out.mode = rng.enumValue(Mode),
				.val => vary(rng, &self.out.val, 4)
			},
			.jmp => self.jmp +%= rng.intRangeAtMost(isize, -2, 2),
			.op => switch(rng.enumValue(enum { op, mode, reg, val })) {
				.op => self.op.op = rng.enumValue(Op),
				.mode => self.op.mode = rng.enumValue(Mode),
				.reg => vary(rng, &self.op.reg, 1),
				.val => vary(rng, &self.op.val, 4)
			}
		}
	}
};

pub const Program = struct {
	
	// info
	code: []Instruction,
	name: []const u8,
	// state
	registers: [numRegisters]u8,
	ip: usize,
	// I/O
	input: []const u8, // note: this is externally managed
	inputPos: usize,
	output: ArrayList(u8),

	/// Creates a random program
	pub fn random(ally: Allocator, rng: Random) !Program {
		// create code array
		const code = try ally.alloc(Instruction, rng.intRangeAtMost(usize, 5, 10));
		// fill with random instructions
		for(code) |*c|
			c.* = Instruction.random(rng);
		// generate name
		// TODO have some way to check for uniqueness. right now it just hopes the name is unique
		const name = try genName(ally, rng);
		return Program {
			.code = code,
			.name = name,
			.registers = undefined,
			.ip = undefined,
			.input = &[_]u8 {},
			.inputPos = undefined,
			.output = ArrayList(u8).init(ally)
		};
	}
	/// Creates from code and name
	pub fn init(ally: Allocator, name: []const u8, code: []Instruction) !Program {
		return Program {
			.code = code,
			.name = name,
			.registers = undefined,
			.ip = undefined,
			.input = &[_]u8 {},
			.inputPos = undefined,
			.output = ArrayList(u8).init(ally)
		};
	}

	// generates names
	fn genName(ally: Allocator, rng: Random) ![]const u8 {
		const vowels = "aeiou";
		const consonants = "bcdfghjklmnpqrstvwxyz";
		const syllables = 4; // syllable count
		var str = try ally.alloc(u8, syllables*2);
		for(0..syllables) |i| {
			str[i*2] = consonants[rng.uintLessThan(usize, consonants.len)];
			str[i*2+1] = vowels[rng.uintLessThan(usize, vowels.len)];
		}
		return str;
	}
	
	/// Frees memory
	pub fn deinit(self: Program, ally: Allocator, partial: bool) void {
		if(!partial) {
			ally.free(self.code);
			ally.free(self.name);
		}
		self.output.deinit();
	}

	/// Resets the program for execution
	pub fn reset(self: *Program) void {
		self.ip = 0;
		for(&self.registers) |*r|
			r.* = 0;
		self.output.clearAndFree();
		self.input = &[_]u8 {};
		self.inputPos = 0;
	}
	

	/// Executes a cycle
	pub fn cycle(self: *Program) !void {
		if(self.terminated())
			return;
		const instr = self.code[self.ip];
		switch(instr) {
			.mov => self.registers[instr.mov.reg%numRegisters] = switch(instr.mov.mode) {
				.reg => self.registers[instr.mov.val%numRegisters],
				.imm => instr.mov.val
			},
			.in => self.registers[instr.in%numRegisters] = if(self.inputPos >= self.input.len) 0 else blk: {
				// this is why ++ is a good operator. I like Zig but I don't know why it (and a lot of other modern languages) leave it out.
				const ret = self.input[self.inputPos];
				self.inputPos += 1;
				break :blk ret;
			},
			.out => try self.output.append(switch(instr.out.mode) {
				.reg => self.registers[instr.out.val%numRegisters],
				.imm => instr.out.val
			}),
			.jmp => {
				self.ip = addSize(self.ip, instr.jmp);
				return;
			},
			.op => {
				const a = self.registers[instr.op.reg%numRegisters];
				const b = switch(instr.op.mode) {
					.reg => self.registers[instr.op.val%numRegisters],
					.imm => instr.op.val
				};
				self.registers[instr.op.reg%numRegisters] = switch(instr.op.op) {
					.add => a+%b,
					.sub => a-%b,
					.mul => a*%b,
					// make sure to avoid division by zero
					.div => if(b == 0) 0 else @divFloor(a, b)
				};
			}
		}
		self.ip += 1;
	}

	/// Returns true if the program terminated
	pub inline fn terminated(self: Program) bool {
		return self.ip >= self.code.len;
	}
	
	/// Mutates the program
	pub fn mutate(self: *Program, ally: Allocator, rng: Random) !void {
		// if len == 0 all we can do is just add an instruction
		if(self.code.len == 0) {
			self.code = try ally.realloc(self.code, self.code.len+1);
			self.code[0] = Instruction.random(rng);
			return;
		}
		const MutType = enum {
			modify, // modify an instruction
			replace, // replace an instruction with a new instruction
			swap, // swap two instructions
			add, // add an instruction
			remove // remove an instruction
		};
		const mutType =  ([_]MutType { .modify, .replace, .swap, .add, .remove})[rng.weightedIndex(f64, &.{12.5, 12.5, 12.5, 12.5, 50})];
		// *maybe* I should've made `code` an ArrayList so I wouldn't have to do manual array management here, but whatever
		switch(mutType) {
			.modify => self.code[rng.uintLessThan(usize, self.code.len)].mutate(rng),
			.replace => self.code[rng.uintLessThan(usize, self.code.len)] = Instruction.random(rng),
			.swap => std.mem.swap(Instruction, &self.code[rng.uintLessThan(usize, self.code.len)], &self.code[rng.uintLessThan(usize, self.code.len)]),
			.add => {
				// adds an instruction
				const idx = if(self.code.len == 0) 0 else rng.uintLessThan(usize, self.code.len);
				// insert instruction
				self.code = try ally.realloc(self.code, self.code.len+1);
				std.mem.copyBackwards(Instruction, self.code[idx+1..], self.code[idx..self.code.len-1]);
				// self.code[self.code.len-1] = Instruction { .in = 0 };
				self.code[idx] = Instruction.random(rng);
				// fix jump targets
				for(self.code, 0..) |*j, i| {
					if(i == idx)
						continue;
					switch(j.*) {
						.jmp => {
							const target = addSize(i, j.jmp);
							if((i < idx and target < idx) or (i > idx and target > idx))
								continue; // target does not need to be fixed
							if(i < idx) {
								j.jmp += 1;
							} else
								j.jmp -= 1;
						},
						else => {}
					}
				}
			},
			.remove => {
				// removes an instruction
				if(self.code.len == 0)
					return;
				const idx = rng.uintLessThan(usize, self.code.len);
				// remove instruction
				std.mem.copyForwards(Instruction, self.code[idx..self.code.len-1], self.code[idx+1..]);
				self.code = try ally.realloc(self.code, self.code.len-1);
				// fix jump targets
				for(self.code, 0..) |*j, i| {
					if(i == idx)
						continue;
					switch(j.*) {
						.jmp => {
							const target = addSize(i, j.jmp);
							if((i < idx and target < idx) or (i >= idx and target >= idx))
								continue; // target does not need to be fixed
							if(i < idx) {
								j.jmp -= 1;
							} else
								j.jmp += 1;
						},
						else => {}
					}
				}
			}
		}
	}

	/// Clones the program
	pub fn clone(self: Program, ally: Allocator, rng: Random) !Program {
		return Program {
			.code = try ally.dupe(Instruction, self.code),
			.name = try genName(ally, rng),
			.registers = undefined,
			.ip = undefined,
			.input = &[_]u8 {},
			.inputPos = undefined,
			.output = ArrayList(u8).init(ally)
		};
	}

};

/// Writes a program source to output
pub fn writeCode(writer: anytype, code: []Instruction) !void {
	// create labels
	var labels = [_]u8 {0} ** 1024; // I doubt a program will be more than 1024 instructions long
	var char: u8 = 'A';
	for(code, 0..) |c, i| {
		const target = addSize(i, switch(c) {
			.jmp => c.jmp,
			else => continue
		});
		if(target >= labels.len or labels[target] != 0)
			continue;
		labels[target] = char;
		char += 1;
		if(char == '[')
			char = 'a';
	}
	// print
	for(code, 0..) |c, i| {
		// colors
		const opcode = color.red;
		const reg = color.green;
		const imm = color.cyan;
		const label = color.magenta;
		const def = color.default;
		if(labels[i] != 0) {
			try writer.print(label++"{c} ", .{labels[i]});
		} else
			try writer.print("  ", .{});
		try writer.print(opcode, .{});
		switch(c) {
			.mov => try writer.print("mov "++reg++"r{d}"++def++", {s}{d}", .{
				c.mov.reg%numRegisters, 
				if(c.mov.mode == .reg) reg++"r" else imm, 
				if(c.mov.mode == .reg) c.mov.val%numRegisters else c.mov.val
			}),
			.in => try writer.print("in "++reg++"r{d}", .{c.in%numRegisters}),
			.out => try writer.print("out {s}{d}", .{
				if(c.out.mode == .reg) reg++"r" else imm, 
				if(c.out.mode == .reg) c.out.val%numRegisters else c.out.val
			}),
			.jmp => {
				const target = addSize(i, c.jmp);
				if(target >= labels.len and target < code.len) {
					try writer.print("jmp "++def++"?", .{});
				}
				else if(target >= code.len) {
					try writer.print("halt", .{});
				} else
					try writer.print("jmp "++label++"{c}", .{labels[target]});
			},
			.op => {
				const name = switch(c.op.op) {
					.add => "add",
					.sub => "sub",
					.mul => "mul",
					.div => "div",
				};
				try writer.print("{s} "++reg++"r{d}"++def++", {s}{d}", .{
					name, 
					c.op.reg%numRegisters, 
					if(c.op.mode == .reg) reg++"r" else imm, 
					if(c.op.mode == .reg) c.op.val%numRegisters else c.op.val
				});
			}
		}
		try writer.print("\n", .{});
	}
}

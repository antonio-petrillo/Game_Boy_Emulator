package main

Flag_Set :: bit_set[Flags]

NOP_Instruction :: struct { }

Branch_Arg :: enum { A16, HL, E8 }
Branch_Kind :: enum { JP, JR, CALL } // NOTE: absolute, relative and function call
Branch_Condition :: enum { None, Zero, Non_Zero, Carry, Non_Carry }
Branch_Instruction :: struct {
	kind: Branch_Kind,
	cond: Branch_Condition,
	arg: Branch_Arg,
	alt_t_cycles: u64,
}

Ret_Instruction :: struct {
	cond: Branch_Condition,
	alt_t_cycles: u64,
}

Load_16_Dest :: enum { BC, DE, HL, SP, A16 }
Load_16_Instruction :: struct {
	dest: Load_16_Dest,
}

Load_8_Dest_Arg :: enum {
	A, B, C, D, E, H, L, HL, HL_Plus, HL_Minus, BC, DE,
}
Load_8_Src_Arg :: enum {
	A, B, C, D, E, H, L, HL, HL_Plus, HL_Minus, BC, DE, N8,
}
Load_R8_R8 :: struct {
	dest: Load_8_Dest_Arg,
	src: Load_8_Src_Arg,
}

Load_A_A16 :: enum { A, A16 }
Load_HL_SP :: enum { HL, SP }

LDH_Arg :: enum { A8_Indirect, A, C_Indirect }
LDH_Instruction :: struct {
	dest: LDH_Arg,
	src: LDH_Arg,
}

Increment_Kind :: enum { Inc, Dec }
Increment_Arg_8 :: enum { A, B, C, D, E, H, L, HL_Indirect }
Increment_Arg_16 :: enum { BC, DE, HL, SP }
Increment_Instruction :: struct {
	kind: Increment_Kind,
	arg: union{ Increment_Arg_8, Increment_Arg_16 },
}

Interrupt_Master_Enable_Instruction :: enum { DI, EI, RETI }

Stack_Op :: enum { Push, Pop }
Stack_Arg :: enum { BC, DE, HL, AF }
Stack_Instruction :: struct {
	op: Stack_Op,
	arg: Stack_Arg,
}

Math_R8_R8_Kind :: enum { Add, Sub, And, Or, Adc, Sbc, Xor, Cp }
Math_Flag_Action :: enum { None, One, Zero, Compute }
Math_R8_R8_Arg :: enum { A, B, C, D, E, H, L, HL_Indirect, N8 }
Math_R8_R8_Instruction :: struct {
	op: Math_R8_R8_Kind,
	flag_actions: [Flags]Math_Flag_Action,
	arg: Math_R8_R8_Arg,
}

Prefix :: distinct struct {}

Rotation_Kind :: enum { Left, Right }
Rotate_Instruction_A :: struct {
	kind: Rotation_Kind,
	use_carry_bit_from_byte: bool,
}

Instruction_Kind :: union {
	NOP_Instruction,
	Branch_Instruction,
	Ret_Instruction,
	Load_16_Instruction,
	Load_R8_R8,
	Load_A_A16,
	LDH_Instruction,
	Load_HL_SP,
	Increment_Instruction,
	Interrupt_Master_Enable_Instruction,
	Stack_Instruction,
	Math_R8_R8_Instruction,
	Prefix,
	Rotate_Instruction_A,
}

Instruction :: struct {
	kind: Instruction_Kind,
	t_cycles: u64,
	disassembly: string,
}

// TODO: warning to large may cause problem
INSTRUCTIONS_TABLE := [0x100]Instruction {
	/*+------------------------------------+
      | INSTRUCTION FROM 0x00 TO 0x0F      |
      +------------------------------------+*/
	0x00 = { NOP_Instruction{}, 4, "NOP" },
	0x01 = { Load_16_Instruction{ .BC }, 12,  "LD BC, n16"},
	0x02 = { Load_R8_R8{ .BC, .A }, 8, "LD [BC], A" },
	0x03 = { Increment_Instruction{ .Inc, .BC }, 8, "INC BC" },
	0x04 = { Increment_Instruction{ .Inc, .B }, 4, "INC B" },
	0x05 = { Increment_Instruction{ .Dec, .B }, 4, "DEC B" },
	0x06 = { Load_R8_R8{ .B, .N8 }, 8, "LD B, n8" },
	0x07 = { Rotate_Instruction_A{ .Left, true }, 4, "RLCA" },
	0x08 = { Load_16_Instruction{ .A16 }, 20, "LD [a16], SP" },
	0x0A = { Load_R8_R8{ .A, .BC }, 8, "LD C, n8" },
	0x0C = { Increment_Instruction{ .Inc, .C }, 4, "INC C" },
	0x0D = { Increment_Instruction{ .Dec, .C }, 4, "DEC C" },
	0x0E = { Load_R8_R8{ .C, .N8 }, 8, "LD C, n8" },
	0x0F = { Rotate_Instruction_A{ .Right, true }, 4, "RRCA" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x10 TO 0x1F      |
      +------------------------------------+*/
	0x11 = { Load_16_Instruction{ .DE }, 12,  "LD DE, n16"},
	0x12 = { Load_R8_R8{ .DE, .A }, 8, "LD [DE], A" },
	0x13 = { Increment_Instruction{ .Inc, .DE }, 8, "INC DE" },
	0x14 = { Increment_Instruction{ .Inc, .D }, 4, "INC D" },
	0x15 = { Increment_Instruction{ .Dec, .D }, 4, "DEC D" },
	0x16 = { Load_R8_R8{ .D, .N8 }, 8, "LD D, n8" },
	0x17 = { Rotate_Instruction_A{ .Left, false }, 4, "RLA" },
	0x18 = { Branch_Instruction{ .JR, .None, .E8, 12 }, 12, "JR e8" },
	0x1A = { Load_R8_R8{ .A, .DE }, 8, "LD A, [DE]" },
	0x1C = { Increment_Instruction{ .Inc, .E }, 4, "INC E" },
	0x1D = { Increment_Instruction{ .Dec, .E }, 4, "DEC E" },
	0x1E = { Load_R8_R8{ .E, .N8 }, 8, "LD E, n8" },
	0x1F = { Rotate_Instruction_A{ .Right, false }, 4, "RRA" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x20 TO 0x2F      |
      +------------------------------------+*/
	0x20 = { Branch_Instruction{ .JR, .Non_Zero, .E8, 12 }, 8, "JR NZ, e8" },
	0x21 = { Load_16_Instruction{ .HL }, 12,  "LD HL, n16"},
	0x22 = { Load_R8_R8{ .HL_Plus, .A }, 8, "LD [HL+], A" },
	0x23 = { Increment_Instruction{ .Inc, .HL }, 8, "INC HL" },
	0x24 = { Increment_Instruction{ .Inc, .H }, 4, "INC H" },
	0x25 = { Increment_Instruction{ .Dec, .H }, 4, "DEC H" },
	0x26 = { Load_R8_R8{ .H, .N8 }, 8, "LD H, n8" },
	0x28 = { Branch_Instruction{ .JR, .Zero, .E8, 12 }, 8, "JR Z, e8" },
	0x2A = { Load_R8_R8{ .A, .HL_Plus }, 8, "LD A, [HL+]" },
	0x2C = { Increment_Instruction{ .Inc, .L }, 4, "INC L" },
	0x2D = { Increment_Instruction{ .Dec, .L }, 4, "DEC L" },
	0x2E = { Load_R8_R8{ .L, .N8 }, 8, "LD L, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x30 TO 0x3F      |
      +------------------------------------+*/
	0x30 = { Branch_Instruction{ .JR, .Non_Carry, .E8, 12 }, 8, "JR NC, e8" },
	0x31 = { Load_16_Instruction{ .SP }, 12,  "LD SP, n16"},
	0x32 = { Load_R8_R8{ .HL_Minus, .A }, 8, "LD [HL-], A" },
	0x33 = { Increment_Instruction{ .Inc, .SP }, 8, "INC SP" },
	0x34 = { Increment_Instruction{ .Inc, .HL_Indirect }, 12, "INC [HL]" },
	0x35 = { Increment_Instruction{ .Dec, .HL_Indirect }, 12, "DEC [HL]" },
	0x36 = { Load_R8_R8{ .HL, .N8 }, 8, "LD [HL], n8" },
	0x38 = { Branch_Instruction{ .JR, .Carry, .E8, 12 }, 8, "JR C, e8" },
	0x3A = { Load_R8_R8{ .A, .HL_Minus }, 8, "LD A, [HL-]" },
	0x3C = { Increment_Instruction{ .Inc, .A }, 4, "INC A" },
	0x3D = { Increment_Instruction{ .Dec, .A }, 4, "DEC A" },
	0x3E = { Load_R8_R8{ .A, .N8 }, 8, "LD A, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x40 TO 0x4F      |
      +------------------------------------+*/
	0x40 = { Load_R8_R8{ .B, .B }, 4, "LD B, B" },
	0x41 = { Load_R8_R8{ .B, .C }, 4, "LD B, C" },
	0x42 = { Load_R8_R8{ .B, .D }, 4, "LD B, D" },
	0x43 = { Load_R8_R8{ .B, .E }, 4, "LD B, E" },
	0x44 = { Load_R8_R8{ .B, .H }, 4, "LD B, H" },
	0x45 = { Load_R8_R8{ .B, .L }, 4, "LD B, L" },
	0x46 = { Load_R8_R8{ .B, .HL }, 8, "LD B, [HL]" },
	0x47 = { Load_R8_R8{ .B, .A }, 4, "LD B, A" },
	0x48 = { Load_R8_R8{ .C, .B }, 4, "LD C, B" },
	0x49 = { Load_R8_R8{ .C, .C }, 4, "LD C, C" },
	0x4A = { Load_R8_R8{ .C, .D }, 4, "LD C, D" },
	0x4B = { Load_R8_R8{ .C, .E }, 4, "LD C, E" },
	0x4C = { Load_R8_R8{ .C, .H }, 4, "LD C, H" },
	0x4D = { Load_R8_R8{ .C, .L }, 4, "LD C, L" },
	0x4E = { Load_R8_R8{ .C, .HL }, 8, "LD C, [HL]" },
	0x4F = { Load_R8_R8{ .C, .A }, 4, "LD C, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x50 TO 0x5F      |
      +------------------------------------+*/
	0x50 = { Load_R8_R8{ .D, .B }, 4, "LD D, B" },
	0x51 = { Load_R8_R8{ .D, .C }, 4, "LD D, C" },
	0x52 = { Load_R8_R8{ .D, .D }, 4, "LD D, D" },
	0x53 = { Load_R8_R8{ .D, .E }, 4, "LD D, E" },
	0x54 = { Load_R8_R8{ .D, .H }, 4, "LD D, H" },
	0x55 = { Load_R8_R8{ .D, .L }, 4, "LD D, L" },
	0x56 = { Load_R8_R8{ .D, .HL }, 8, "LD D, [HL]" },
	0x57 = { Load_R8_R8{ .D, .A }, 4, "LD D, A" },
	0x58 = { Load_R8_R8{ .E, .B }, 4, "LD E, B" },
	0x59 = { Load_R8_R8{ .E, .C }, 4, "LD E, C" },
	0x5A = { Load_R8_R8{ .E, .D }, 4, "LD E, D" },
	0x5B = { Load_R8_R8{ .E, .E }, 4, "LD E, E" },
	0x5C = { Load_R8_R8{ .E, .H }, 4, "LD E, H" },
	0x5D = { Load_R8_R8{ .E, .L }, 4, "LD E, L" },
	0x5E = { Load_R8_R8{ .E, .HL }, 8, "LD E, [HL]" },
	0x5F = { Load_R8_R8{ .E, .A }, 4, "LD E, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x60 TO 0x6F      |
      +------------------------------------+*/
	0x60 = { Load_R8_R8{ .H, .B }, 4, "LD H, B" },
	0x61 = { Load_R8_R8{ .H, .C }, 4, "LD H, C" },
	0x62 = { Load_R8_R8{ .H, .D }, 4, "LD H, D" },
	0x63 = { Load_R8_R8{ .H, .E }, 4, "LD H, E" },
	0x64 = { Load_R8_R8{ .H, .H }, 4, "LD H, H" },
	0x65 = { Load_R8_R8{ .H, .L }, 4, "LD H, L" },
	0x66 = { Load_R8_R8{ .H, .HL }, 8, "LD H, [HL]" },
	0x67 = { Load_R8_R8{ .H, .A }, 4, "LD H, A" },
	0x68 = { Load_R8_R8{ .L, .B }, 4, "LD L, B" },
	0x69 = { Load_R8_R8{ .L, .C }, 4, "LD L, C" },
	0x6A = { Load_R8_R8{ .L, .D }, 4, "LD L, D" },
	0x6B = { Load_R8_R8{ .L, .E }, 4, "LD L, E" },
	0x6C = { Load_R8_R8{ .L, .H }, 4, "LD L, H" },
	0x6D = { Load_R8_R8{ .L, .L }, 4, "LD L, L" },
	0x6E = { Load_R8_R8{ .L, .HL }, 8, "LD L, [HL]" },
	0x6F = { Load_R8_R8{ .L, .A }, 4, "LD L, A" },


	/*+------------------------------------+
      | INSTRUCTION FROM 0x70 TO 0x7F      |
      +------------------------------------+*/
	0x70 = { Load_R8_R8{ .HL, .B }, 8, "LD [HL], B" },
	0x71 = { Load_R8_R8{ .HL, .C }, 8, "LD [HL], C" },
	0x72 = { Load_R8_R8{ .HL, .D }, 8, "LD [HL], D" },
	0x73 = { Load_R8_R8{ .HL, .E }, 8, "LD [HL], E" },
	0x74 = { Load_R8_R8{ .HL, .H }, 8, "LD [HL], H" },
	0x75 = { Load_R8_R8{ .HL, .L }, 8, "LD [HL], L" },
	0x77 = { Load_R8_R8{ .HL, .A }, 8, "LD [HL], A" },
	0x78 = { Load_R8_R8{ .A, .B }, 4, "LD A, B" },
	0x79 = { Load_R8_R8{ .A, .C }, 4, "LD A, C" },
	0x7A = { Load_R8_R8{ .A, .D }, 4, "LD A, D" },
	0x7B = { Load_R8_R8{ .A, .E }, 4, "LD A, E" },
	0x7C = { Load_R8_R8{ .A, .H }, 4, "LD A, H" },
	0x7D = { Load_R8_R8{ .A, .L }, 4, "LD A, L" },
	0x7E = { Load_R8_R8{ .A, .HL }, 8, "LD A, [HL]" },
	0x7F = { Load_R8_R8{ .A, .A }, 4, "LD A, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x80 TO 0x8F      |
      +------------------------------------+*/
	0x80 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .B }, 4, "ADD A, B" },
	0x81 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .C }, 4, "ADD A, C" },
	0x82 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .D }, 4, "ADD A, D" },
	0x83 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .E }, 4, "ADD A, E" },
	0x84 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .H }, 4, "ADD A, H" },
	0x85 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .L }, 4, "ADD A, L" },
	0x86 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .HL_Indirect }, 8, "ADD A, [HL]" },
	0x87 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .A }, 4, "ADD A, A" },

	0x88 = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .B }, 4, "ADC A, B" },
	0x89 = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .C }, 4, "ADC A, C" },
	0x8A = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .D }, 4, "ADC A, D" },
	0x8B = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .E }, 4, "ADC A, E" },
	0x8C = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .H }, 4, "ADC A, H" },
	0x8D = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .L }, 4, "ADC A, L" },
	0x8E = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .HL_Indirect }, 8, "ADC A, [HL]" },
	0x8F = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .A }, 4, "ADC A, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x90 TO 0x9F      |
      +------------------------------------+*/
	0x90 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SUB A, B" },
	0x91 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SUB A, C" },
	0x92 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SUB A, D" },
	0x93 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SUB A, E" },
	0x94 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SUB A, H" },
	0x95 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SUB A, L" },
	0x96 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .HL_Indirect }, 4, "SUB A, [HL]" },
	0x97 = { Math_R8_R8_Instruction{ .Sub, { .Z = .One, .N = .One, .H = .Zero, .C = .Zero }, .A }, 4, "SUB A, A" },

	0x98 = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "SBC A, B" },
	0x99 = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .C }, 4, "SBC A, C" },
	0x9A = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .D }, 4, "SBC A, D" },
	0x9B = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .E }, 4, "SBC A, E" },
	0x9C = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .H }, 4, "SBC A, H" },
	0x9D = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .L }, 4, "SBC A, L" },
	0x9E = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .HL_Indirect }, 8, "SBC A, [HL]" },
	0x9F = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .None }, .A }, 4, "SBC A, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xA0 TO 0xAF      |
      +------------------------------------+*/
	0xA0 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .B }, 4, "AND A, B" },
	0xA1 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .C }, 4, "AND A, C" },
	0xA2 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .D }, 4, "AND A, D" },
	0xA3 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .E }, 4, "AND A, E" },
	0xA4 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .H }, 4, "AND A, H" },
	0xA5 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .L }, 4, "AND A, L" },
	0xA6 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .HL_Indirect }, 8, "AND A, [HL]" },
	0xA7 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .A }, 4, "AND A, A" },

	0xA8 = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .B }, 4, "XOR A, B" },
	0xA9 = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .C }, 4, "XOR A, C" },
	0xAA = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .D }, 4, "XOR A, D" },
	0xAB = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .E }, 4, "XOR A, E" },
	0xAC = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .H }, 4, "XOR A, H" },
	0xAD = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .L }, 4, "XOR A, L" },
	0xAE = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .HL_Indirect }, 8, "XOR A, [HL]" },
	0xAF = { Math_R8_R8_Instruction{ .Xor, { .Z = .One, .N = .Zero, .H = .Zero, .C = .Zero }, .A }, 4, "XOR A, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xB0 TO 0xBF      |
      +------------------------------------+*/
	0xB0 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .B }, 4, "OR A, B" },
	0xB1 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .C }, 4, "OR A, C" },
	0xB2 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .D }, 4, "OR A, D" },
	0xB3 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .E }, 4, "OR A, E" },
	0xB4 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .H }, 4, "OR A, H" },
	0xB5 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .L }, 4, "OR A, L" },
	0xB6 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .HL_Indirect }, 8, "OR A, [HL]" },
	0xB7 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .A }, 4, "OR A, A" },

	0xB8 = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .B }, 4, "CP A, B" },
	0xB9 = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .C }, 4, "CP A, C" },
	0xBA = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .D }, 4, "CP A, D" },
	0xBB = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .E }, 4, "CP A, E" },
	0xBC = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .H }, 4, "CP A, H" },
	0xBD = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .L }, 4, "CP A, L" },
	0xBE = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .HL_Indirect }, 8, "CP A, [HL]" },
	0xBF = { Math_R8_R8_Instruction{ .Cp, { .Z = .One, .N = .One, .H = .Zero, .C = .Zero }, .A }, 4, "CP A, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xC0 TO 0xCF      |
      +------------------------------------+*/
	0xC0 = { Ret_Instruction{ .Non_Zero, 20 }, 8, "RET NZ" },
	0xC1 = { Stack_Instruction{ .Pop, .BC }, 12, "POP BC" },
	0xC2 = { Branch_Instruction{ .JP, .Non_Zero, .A16 , 16}, 12, "JP NZ, a16" },
	0xC3 = { Branch_Instruction{ .JP, .None, .A16, 16 }, 16, "JP a16" },
	0xC4 = { Branch_Instruction{ .CALL, .Non_Zero, .A16 , 24}, 12, "CALL NZ, a16" },
	0xC5 = { Stack_Instruction{ .Push, .BC }, 16, "PUSH BC" },
	0xC6 = { Math_R8_R8_Instruction{ .Add, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .N8 }, 8, "ADD A, n8" },
	0xC8 = { Ret_Instruction{ .Zero, 20 }, 8, "RET Z" },
	0xC9 = { Ret_Instruction{ .None, 16 }, 8, "RET" },
	0xCA = { Branch_Instruction{ .JP, .Zero, .A16, 16 }, 12, "JP Z, a16" },
	0xCB = { Prefix{}, 4, "PREFIX" },
	0xCC = { Branch_Instruction{ .CALL, .Zero, .A16 , 24}, 12, "CALL Z, a16" },
	0xCE = { Math_R8_R8_Instruction{ .Adc, { .Z = .Compute, .N = .Zero, .H = .Compute, .C = .Compute }, .N8 }, 8, "ADC A, n8" },
	0xCD = { Branch_Instruction{ .CALL, .None, .A16 , 24}, 24, "CALL a16" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xD0 TO 0xDF      |
      +------------------------------------+*/
	0xD0 = { Ret_Instruction{ .Non_Carry, 20 }, 8, "RET NC" },
	0xD1 = { Stack_Instruction{ .Pop, .DE }, 12, "POP DE" },
	0xD2 = { Branch_Instruction{ .JP, .Non_Carry, .A16 , 16}, 12, "JP NC, a16" },
	0xD4 = { Branch_Instruction{ .CALL, .Non_Carry, .A16 , 24}, 12, "CALL NC, a16" },
	0xD5 = { Stack_Instruction{ .Push, .DE }, 16, "PUSH DE" },
	0xD6 = { Math_R8_R8_Instruction{ .Sub, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .N8 }, 8, "SUB A, n8" },
	0xD8 = { Ret_Instruction{ .Carry, 20 }, 8, "RET C" },
	0xD9 = { .RETI, 16, "RETI" },
	0xDA = { Branch_Instruction{ .JP, .Carry, .A16, 16 }, 12, "JP C, a16" },
	0xDE = { Math_R8_R8_Instruction{ .Sbc, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .N8 }, 8, "SBC A, n8" },
	0xDC = { Branch_Instruction{ .CALL, .Carry, .A16 , 24}, 12, "CALL C, a16" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xE0 TO 0xEF      |
      +------------------------------------+*/
	0xE0 = { LDH_Instruction{ .A8_Indirect, .A }, 12, "LDH [a8], A" },
	0xE1 = { Stack_Instruction{ .Pop, .HL }, 12, "POP HL" },
	0xE2 = { LDH_Instruction{ .C_Indirect, .A }, 8, "LDH [C], A" },
	0xE5 = { Stack_Instruction{ .Push, .HL }, 16, "PUSH HL" },
	0xE6 = { Math_R8_R8_Instruction{ .And, { .Z = .Compute, .N = .Zero, .H = .One, .C = .Zero }, .N8 }, 8, "AND A, n8" },
	0xE9 = { Branch_Instruction{ .JP, .None, .HL, 4 }, 4, "JP HL" },
	0xEA = { .A, 16, "LD [a16], A" },
	0xEE = { Math_R8_R8_Instruction{ .Xor, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .N8 }, 8, "XOR A, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xF0 TO 0xFF      |
      +------------------------------------+*/
	0xF0 = { LDH_Instruction{ .A, .A8_Indirect }, 12, "LDH A, [a8]" },
	0xF1 = { Stack_Instruction{ .Pop, .AF }, 12, "POP AF" },
	0xF2 = { LDH_Instruction{ .A, .C_Indirect }, 8, "LDH A, [C]" },
	0xF3 = { .DI, 4, "DI" },
	0xF5 = { Stack_Instruction{ .Push, .AF }, 16, "PUSH AF" },
	0xF6 = { Math_R8_R8_Instruction{ .Or, { .Z = .Compute, .N = .Zero, .H = .Zero, .C = .Zero }, .N8 }, 8, "OR A, n8" },
	0xF8 = { .HL, 12, "LD HL, SP + e8" },
	0xF9 = { .HL, 12, "LD SP, HL" },
	0xFA = { .A16, 16, "LD A, [a16]" },
	0xFB = { .EI, 4, "EI" },
	0xFE = { Math_R8_R8_Instruction{ .Cp, { .Z = .Compute, .N = .One, .H = .Compute, .C = .Compute }, .N8 }, 8, "CP A, n8" },
}

Rotate_Arg :: enum { A, B, C, D, E, H, L, HL_Indirect }
Rotate_Instruction :: struct {
	kind: Rotation_Kind,
	arg: Rotate_Arg,
	use_carry_bit_from_byte: bool,
}

Shift_Kind :: enum { Logical, Arithmetic }
Shift_Rotation_Kind :: Rotation_Kind
Shift_Arg :: Rotate_Arg
Shift_Instruction :: struct {
	kind: Shift_Kind,
	rotation_kind: Shift_Rotation_Kind,
	arg: Shift_Arg,
}

Prefix_Bit_Set_Op :: enum { Set, Res }
Prefix_Bit_Set_Arg :: enum { A, B, C, D, E, H, L, HL_Indirect }
Set_Bit_Instruction :: struct {
	op: Prefix_Bit_Set_Op,
	arg: Prefix_Bit_Set_Arg,
	bit_index: u8, // should be in 0..=7
}

Swap_Arg :: Prefix_Bit_Set_Arg
Swap_Instruction :: struct {
	arg: Swap_Arg,
}

Test_Bit_Arg :: Prefix_Bit_Set_Arg
Test_Bit_Instruction :: struct {
	arg: Test_Bit_Arg,
	bit_index: u8,
}

Prefix_Instruction_Kind :: union {
	Set_Bit_Instruction,
	Rotate_Instruction,
	Shift_Instruction,
	Swap_Instruction,
	Test_Bit_Instruction,
}

Prefix_Instruction :: struct {
	kind: Prefix_Instruction_Kind,
	t_cycles: u64,
	disassembly: string,
}

// TODO: warning to large may cause problem
PREFIX_INSTRUCTIONS_TABLE := [0x100]Prefix_Instruction {
	/*+------------------------------------+
      | INSTRUCTION FROM 0x00 TO 0x0F      |
      +------------------------------------+*/
	0x00 = { Rotate_Instruction{ .Left, .B, true }, 8, "RLC B" },
	0x01 = { Rotate_Instruction{ .Left, .C, true }, 8, "RLC C" },
	0x02 = { Rotate_Instruction{ .Left, .D, true }, 8, "RLC D" },
	0x03 = { Rotate_Instruction{ .Left, .E, true }, 8, "RLC E" },
	0x04 = { Rotate_Instruction{ .Left, .H, true }, 8, "RLC H" },
	0x05 = { Rotate_Instruction{ .Left, .L, true }, 8, "RLC L" },
	0x06 = { Rotate_Instruction{ .Left, .HL_Indirect, true }, 16, "RLC [HL]" },
	0x07 = { Rotate_Instruction{ .Left, .A, true }, 8, "RLC A" },

	0x08 = { Rotate_Instruction{ .Right, .B, true }, 8, "RRC B" },
	0x09 = { Rotate_Instruction{ .Right, .C, true }, 8, "RRC C" },
	0x0A = { Rotate_Instruction{ .Right, .D, true }, 8, "RRC D" },
	0x0B = { Rotate_Instruction{ .Right, .E, true }, 8, "RRC E" },
	0x0C = { Rotate_Instruction{ .Right, .H, true }, 8, "RRC H" },
	0x0D = { Rotate_Instruction{ .Right, .L, true }, 8, "RRC L" },
	0x0E = { Rotate_Instruction{ .Right, .HL_Indirect, true }, 16, "RRC [HL]" },
	0x0F = { Rotate_Instruction{ .Right, .A, true }, 8, "RRC A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x10 TO 0x1F      |
      +------------------------------------+*/
	0x10 = { Rotate_Instruction{ .Left, .B, false }, 8, "RL B" },
	0x11 = { Rotate_Instruction{ .Left, .C, false }, 8, "RL C" },
	0x12 = { Rotate_Instruction{ .Left, .D, false }, 8, "RL D" },
	0x13 = { Rotate_Instruction{ .Left, .E, false }, 8, "RL E" },
	0x14 = { Rotate_Instruction{ .Left, .H, false }, 8, "RL H" },
	0x15 = { Rotate_Instruction{ .Left, .L, false }, 8, "RL L" },
	0x16 = { Rotate_Instruction{ .Left, .HL_Indirect, false }, 16, "RL [HL]" },
	0x17 = { Rotate_Instruction{ .Left, .A, false }, 8, "RL A" },

	0x18 = { Rotate_Instruction{ .Right, .B, false }, 8, "RR B" },
	0x19 = { Rotate_Instruction{ .Right, .C, false }, 8, "RR C" },
	0x1A = { Rotate_Instruction{ .Right, .D, false }, 8, "RR D" },
	0x1B = { Rotate_Instruction{ .Right, .E, false }, 8, "RR E" },
	0x1C = { Rotate_Instruction{ .Right, .H, false }, 8, "RR H" },
	0x1D = { Rotate_Instruction{ .Right, .L, false }, 8, "RR L" },
	0x1E = { Rotate_Instruction{ .Right, .HL_Indirect, false }, 16, "RR [HL]" },
	0x1F = { Rotate_Instruction{ .Right, .A, false }, 8, "RR A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x20 TO 0x2F      |
      +------------------------------------+*/
	0x20 = { Shift_Instruction{ .Arithmetic, .Left, .B }, 8, "SLA B" },
	0x21 = { Shift_Instruction{ .Arithmetic, .Left, .C }, 8, "SLA C" },
	0x22 = { Shift_Instruction{ .Arithmetic, .Left, .D }, 8, "SLA D" },
	0x23 = { Shift_Instruction{ .Arithmetic, .Left, .E }, 8, "SLA E" },
	0x24 = { Shift_Instruction{ .Arithmetic, .Left, .H }, 8, "SLA H" },
	0x25 = { Shift_Instruction{ .Arithmetic, .Left, .L }, 8, "SLA L" },
	0x26 = { Shift_Instruction{ .Arithmetic, .Left, .HL_Indirect }, 16, "SLA [HL]" },
	0x27 = { Shift_Instruction{ .Arithmetic, .Left, .A }, 8, "SLA A" },

	0x28 = { Shift_Instruction{ .Arithmetic, .Right, .B }, 8, "SRA B" },
	0x29 = { Shift_Instruction{ .Arithmetic, .Right, .C }, 8, "SRA C" },
	0x2A = { Shift_Instruction{ .Arithmetic, .Right, .D }, 8, "SRA D" },
	0x2B = { Shift_Instruction{ .Arithmetic, .Right, .E }, 8, "SRA E" },
	0x2C = { Shift_Instruction{ .Arithmetic, .Right, .H }, 8, "SRA H" },
	0x2D = { Shift_Instruction{ .Arithmetic, .Right, .L }, 8, "SRA L" },
	0x2E = { Shift_Instruction{ .Arithmetic, .Right, .HL_Indirect }, 16, "SRA [HL]" },
	0x2F = { Shift_Instruction{ .Arithmetic, .Right, .A }, 8, "SRA A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x30 TO 0x3F      |
      +------------------------------------+*/
	0x30 = { Swap_Instruction{ .B }, 8, "SWAP B" },
	0x31 = { Swap_Instruction{ .C }, 8, "SWAP C" },
	0x32 = { Swap_Instruction{ .D }, 8, "SWAP D" },
	0x33 = { Swap_Instruction{ .E }, 8, "SWAP E" },
	0x34 = { Swap_Instruction{ .H }, 8, "SWAP H" },
	0x35 = { Swap_Instruction{ .L }, 8, "SWAP L" },
	0x36 = { Swap_Instruction{ .HL_Indirect }, 16, "SWAP [HL]" },
	0x37 = { Swap_Instruction{ .A }, 8, "SWAP A" },

	0x38 = { Shift_Instruction{ .Logical, .Right, .B }, 8, "SRL B" },
	0x39 = { Shift_Instruction{ .Logical, .Right, .C }, 8, "SRL C" },
	0x3A = { Shift_Instruction{ .Logical, .Right, .D }, 8, "SRL D" },
	0x3B = { Shift_Instruction{ .Logical, .Right, .E }, 8, "SRL E" },
	0x3C = { Shift_Instruction{ .Logical, .Right, .H }, 8, "SRL H" },
	0x3D = { Shift_Instruction{ .Logical, .Right, .L }, 8, "SRL L" },
	0x3E = { Shift_Instruction{ .Logical, .Right, .HL_Indirect }, 16, "SRL [HL]" },
	0x3F = { Shift_Instruction{ .Logical, .Right, .A }, 8, "SRL A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x40 TO 0x4F      |
      +------------------------------------+*/
	0x40 = { Test_Bit_Instruction{ .B, 0 }, 8, "BIT 0, B" },
	0x41 = { Test_Bit_Instruction{ .C, 0 }, 8, "BIT 0, C" },
	0x42 = { Test_Bit_Instruction{ .D, 0 }, 8, "BIT 0, D" },
	0x43 = { Test_Bit_Instruction{ .E, 0 }, 8, "BIT 0, E" },
	0x44 = { Test_Bit_Instruction{ .H, 0 }, 8, "BIT 0, H" },
	0x45 = { Test_Bit_Instruction{ .L, 0 }, 8, "BIT 0, L" },
	0x46 = { Test_Bit_Instruction{ .HL_Indirect, 0 }, 8, "BIT 0, [HL]" },
	0x47 = { Test_Bit_Instruction{ .A, 0 }, 8, "BIT 0, A" },

	0x48 = { Test_Bit_Instruction{ .B, 1 }, 8, "BIT 1, B" },
	0x49 = { Test_Bit_Instruction{ .C, 1 }, 8, "BIT 1, C" },
	0x4A = { Test_Bit_Instruction{ .D, 1 }, 8, "BIT 1, D" },
	0x4B = { Test_Bit_Instruction{ .E, 1 }, 8, "BIT 1, E" },
	0x4C = { Test_Bit_Instruction{ .H, 1 }, 8, "BIT 1, H" },
	0x4D = { Test_Bit_Instruction{ .L, 1 }, 8, "BIT 1, L" },
	0x4E = { Test_Bit_Instruction{ .HL_Indirect, 1 }, 8, "BIT 1, [HL]" },
	0x4F = { Test_Bit_Instruction{ .A, 1 }, 8, "BIT 1, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x50 TO 0x5F      |
      +------------------------------------+*/
	0x50 = { Test_Bit_Instruction{ .B, 2 }, 8, "BIT 2, B" },
	0x51 = { Test_Bit_Instruction{ .C, 2 }, 8, "BIT 2, C" },
	0x52 = { Test_Bit_Instruction{ .D, 2 }, 8, "BIT 2, D" },
	0x53 = { Test_Bit_Instruction{ .E, 2 }, 8, "BIT 2, E" },
	0x54 = { Test_Bit_Instruction{ .H, 2 }, 8, "BIT 2, H" },
	0x55 = { Test_Bit_Instruction{ .L, 2 }, 8, "BIT 2, L" },
	0x56 = { Test_Bit_Instruction{ .HL_Indirect, 2 }, 8, "BIT 2, [HL]" },
	0x57 = { Test_Bit_Instruction{ .A, 2 }, 8, "BIT 2, A" },

	0x58 = { Test_Bit_Instruction{ .B, 3 }, 8, "BIT 3, B" },
	0x59 = { Test_Bit_Instruction{ .C, 3 }, 8, "BIT 3, C" },
	0x5A = { Test_Bit_Instruction{ .D, 3 }, 8, "BIT 3, D" },
	0x5B = { Test_Bit_Instruction{ .E, 3 }, 8, "BIT 3, E" },
	0x5C = { Test_Bit_Instruction{ .H, 3 }, 8, "BIT 3, H" },
	0x5D = { Test_Bit_Instruction{ .L, 3 }, 8, "BIT 3, L" },
	0x5E = { Test_Bit_Instruction{ .HL_Indirect, 3 }, 8, "BIT 3, [HL]" },
	0x5F = { Test_Bit_Instruction{ .A, 3 }, 8, "BIT 3, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x60 TO 0x6F      |
      +------------------------------------+*/
	0x60 = { Test_Bit_Instruction{ .B, 4 }, 8, "BIT 4, B" },
	0x61 = { Test_Bit_Instruction{ .C, 4 }, 8, "BIT 4, C" },
	0x62 = { Test_Bit_Instruction{ .D, 4 }, 8, "BIT 4, D" },
	0x63 = { Test_Bit_Instruction{ .E, 4 }, 8, "BIT 4, E" },
	0x64 = { Test_Bit_Instruction{ .H, 4 }, 8, "BIT 4, H" },
	0x65 = { Test_Bit_Instruction{ .L, 4 }, 8, "BIT 4, L" },
	0x66 = { Test_Bit_Instruction{ .HL_Indirect, 4 }, 8, "BIT 4, [HL]" },
	0x67 = { Test_Bit_Instruction{ .A, 4 }, 8, "BIT 4, A" },

	0x68 = { Test_Bit_Instruction{ .B, 5 }, 8, "BIT 5, B" },
	0x69 = { Test_Bit_Instruction{ .C, 5 }, 8, "BIT 5, C" },
	0x6A = { Test_Bit_Instruction{ .D, 5 }, 8, "BIT 5, D" },
	0x6B = { Test_Bit_Instruction{ .E, 5 }, 8, "BIT 5, E" },
	0x6C = { Test_Bit_Instruction{ .H, 5 }, 8, "BIT 5, H" },
	0x6D = { Test_Bit_Instruction{ .L, 5 }, 8, "BIT 5, L" },
	0x6E = { Test_Bit_Instruction{ .HL_Indirect, 5 }, 8, "BIT 5, [HL]" },
	0x6F = { Test_Bit_Instruction{ .A, 5 }, 8, "BIT 5, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x70 TO 0x7F      |
      +------------------------------------+*/
	0x70 = { Test_Bit_Instruction{ .B, 6 }, 8, "BIT 6, B" },
	0x71 = { Test_Bit_Instruction{ .C, 6 }, 8, "BIT 6, C" },
	0x72 = { Test_Bit_Instruction{ .D, 6 }, 8, "BIT 6, D" },
	0x73 = { Test_Bit_Instruction{ .E, 6 }, 8, "BIT 6, E" },
	0x74 = { Test_Bit_Instruction{ .H, 6 }, 8, "BIT 6, H" },
	0x75 = { Test_Bit_Instruction{ .L, 6 }, 8, "BIT 6, L" },
	0x76 = { Test_Bit_Instruction{ .HL_Indirect, 6 }, 8, "BIT 6, [HL]" },
	0x77 = { Test_Bit_Instruction{ .A, 6 }, 8, "BIT 6, A" },

	0x78 = { Test_Bit_Instruction{ .B, 7 }, 8, "BIT 7, B" },
	0x79 = { Test_Bit_Instruction{ .C, 7 }, 8, "BIT 7, C" },
	0x7A = { Test_Bit_Instruction{ .D, 7 }, 8, "BIT 7, D" },
	0x7B = { Test_Bit_Instruction{ .E, 7 }, 8, "BIT 7, E" },
	0x7C = { Test_Bit_Instruction{ .H, 7 }, 8, "BIT 7, H" },
	0x7D = { Test_Bit_Instruction{ .L, 7 }, 8, "BIT 7, L" },
	0x7E = { Test_Bit_Instruction{ .HL_Indirect, 7 }, 8, "BIT 7, [HL]" },
	0x7F = { Test_Bit_Instruction{ .A, 7 }, 8, "BIT 7, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x80 TO 0x8F      |
      +------------------------------------+*/
	0x80 = { Set_Bit_Instruction{ .Res, .B, 0 }, 8, "RES 0, B" },
	0x81 = { Set_Bit_Instruction{ .Res, .C, 0 }, 8, "RES 0, C" },
	0x82 = { Set_Bit_Instruction{ .Res, .D, 0 }, 8, "RES 0, D" },
	0x83 = { Set_Bit_Instruction{ .Res, .E, 0 }, 8, "RES 0, E" },
	0x84 = { Set_Bit_Instruction{ .Res, .H, 0 }, 8, "RES 0, H" },
	0x85 = { Set_Bit_Instruction{ .Res, .L, 0 }, 8, "RES 0, L" },
	0x86 = { Set_Bit_Instruction{ .Res, .HL_Indirect, 0 }, 16, "RES 0, [HL]" },
	0x87 = { Set_Bit_Instruction{ .Res, .A, 0 }, 8, "RES 0, A" },

	0x88 = { Set_Bit_Instruction{ .Res, .B, 1 }, 8, "RES 1, B" },
	0x89 = { Set_Bit_Instruction{ .Res, .C, 1 }, 8, "RES 1, C" },
	0x8A = { Set_Bit_Instruction{ .Res, .D, 1 }, 8, "RES 1, D" },
	0x8B = { Set_Bit_Instruction{ .Res, .E, 1 }, 8, "RES 1, E" },
	0x8C = { Set_Bit_Instruction{ .Res, .H, 1 }, 8, "RES 1, H" },
	0x8D = { Set_Bit_Instruction{ .Res, .L, 1 }, 8, "RES 1, L" },
	0x8E = { Set_Bit_Instruction{ .Res, .HL_Indirect, 1 }, 16, "RES 1, [HL]" },
	0x8F = { Set_Bit_Instruction{ .Res, .A, 1 }, 8, "RES 1, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x90 TO 0x9F      |
      +------------------------------------+*/
	0x90 = { Set_Bit_Instruction{ .Res, .B, 2 }, 8, "RES 2, B" },
	0x91 = { Set_Bit_Instruction{ .Res, .C, 2 }, 8, "RES 2, C" },
	0x92 = { Set_Bit_Instruction{ .Res, .D, 2 }, 8, "RES 2, D" },
	0x93 = { Set_Bit_Instruction{ .Res, .E, 2 }, 8, "RES 2, E" },
	0x94 = { Set_Bit_Instruction{ .Res, .H, 2 }, 8, "RES 2, H" },
	0x95 = { Set_Bit_Instruction{ .Res, .L, 2 }, 8, "RES 2, L" },
	0x96 = { Set_Bit_Instruction{ .Res, .HL_Indirect, 2 }, 16, "RES 2, [HL]" },
	0x97 = { Set_Bit_Instruction{ .Res, .A, 2 }, 8, "RES 2, A" },

	0x98 = { Set_Bit_Instruction{ .Res, .B, 3 }, 8, "RES 3, B" },
	0x99 = { Set_Bit_Instruction{ .Res, .C, 3 }, 8, "RES 3, C" },
	0x9A = { Set_Bit_Instruction{ .Res, .D, 3 }, 8, "RES 3, D" },
	0x9B = { Set_Bit_Instruction{ .Res, .E, 3 }, 8, "RES 3, E" },
	0x9C = { Set_Bit_Instruction{ .Res, .H, 3 }, 8, "RES 3, H" },
	0x9D = { Set_Bit_Instruction{ .Res, .L, 3 }, 8, "RES 3, L" },
	0x9E = { Set_Bit_Instruction{ .Res, .HL_Indirect, 3 }, 16, "RES 3, [HL]" },
	0x9F = { Set_Bit_Instruction{ .Res, .A, 3 }, 8, "RES 3, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xA0 TO 0xAF      |
      +------------------------------------+*/
	0xA0 = { Set_Bit_Instruction{ .Res, .B, 4 }, 8, "RES 4, B" },
	0xA1 = { Set_Bit_Instruction{ .Res, .C, 4 }, 8, "RES 4, C" },
	0xA2 = { Set_Bit_Instruction{ .Res, .D, 4 }, 8, "RES 4, D" },
	0xA3 = { Set_Bit_Instruction{ .Res, .E, 4 }, 8, "RES 4, E" },
	0xA4 = { Set_Bit_Instruction{ .Res, .H, 4 }, 8, "RES 4, H" },
	0xA5 = { Set_Bit_Instruction{ .Res, .L, 4 }, 8, "RES 4, L" },
	0xA6 = { Set_Bit_Instruction{ .Res, .HL_Indirect, 4 }, 16, "RES 4, [HL]" },
	0xA7 = { Set_Bit_Instruction{ .Res, .A, 4 }, 8, "RES 4, A" },

	0xA8 = { Set_Bit_Instruction{ .Res, .B, 5 }, 8, "RES 5, B" },
	0xA9 = { Set_Bit_Instruction{ .Res, .C, 5 }, 8, "RES 5, C" },
	0xAA = { Set_Bit_Instruction{ .Res, .D, 5 }, 8, "RES 5, D" },
	0xAB = { Set_Bit_Instruction{ .Res, .E, 5 }, 8, "RES 5, E" },
	0xAC = { Set_Bit_Instruction{ .Res, .H, 5 }, 8, "RES 5, H" },
	0xAD = { Set_Bit_Instruction{ .Res, .L, 5 }, 8, "RES 5, L" },
	0xAE = { Set_Bit_Instruction{ .Res, .HL_Indirect, 5 }, 16, "RES 5, [HL]" },
	0xAF = { Set_Bit_Instruction{ .Res, .A, 5 }, 8, "RES 5, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xB0 TO 0xBF      |
      +------------------------------------+*/
	0xB0 = { Set_Bit_Instruction{ .Res, .B, 6 }, 8, "RES 6, B" },
	0xB1 = { Set_Bit_Instruction{ .Res, .C, 6 }, 8, "RES 6, C" },
	0xB2 = { Set_Bit_Instruction{ .Res, .D, 6 }, 8, "RES 6, D" },
	0xB3 = { Set_Bit_Instruction{ .Res, .E, 6 }, 8, "RES 6, E" },
	0xB4 = { Set_Bit_Instruction{ .Res, .H, 6 }, 8, "RES 6, H" },
	0xB5 = { Set_Bit_Instruction{ .Res, .L, 6 }, 8, "RES 6, L" },
	0xB6 = { Set_Bit_Instruction{ .Res, .HL_Indirect, 6 }, 16, "RES 6, [HL]" },
	0xB7 = { Set_Bit_Instruction{ .Res, .A, 6 }, 8, "RES 6, A" },

	0xB8 = { Set_Bit_Instruction{ .Res, .B, 7 }, 8, "RES 7, B" },
	0xB9 = { Set_Bit_Instruction{ .Res, .C, 7 }, 8, "RES 7, C" },
	0xBA = { Set_Bit_Instruction{ .Res, .D, 7 }, 8, "RES 7, D" },
	0xBB = { Set_Bit_Instruction{ .Res, .E, 7 }, 8, "RES 7, E" },
	0xBC = { Set_Bit_Instruction{ .Res, .H, 7 }, 8, "RES 7, H" },
	0xBD = { Set_Bit_Instruction{ .Res, .L, 7 }, 8, "RES 7, L" },
	0xBE = { Set_Bit_Instruction{ .Res, .HL_Indirect, 7 }, 16, "RES 7, [HL]" },
	0xBF = { Set_Bit_Instruction{ .Res, .A, 7 }, 8, "RES 7, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xC0 TO 0xCF      |
      +------------------------------------+*/
	0xC0 = { Set_Bit_Instruction{ .Set, .B, 0 }, 8, "SET 0, B" },
	0xC1 = { Set_Bit_Instruction{ .Set, .C, 0 }, 8, "SET 0, C" },
	0xC2 = { Set_Bit_Instruction{ .Set, .D, 0 }, 8, "SET 0, D" },
	0xC3 = { Set_Bit_Instruction{ .Set, .E, 0 }, 8, "SET 0, E" },
	0xC4 = { Set_Bit_Instruction{ .Set, .H, 0 }, 8, "SET 0, H" },
	0xC5 = { Set_Bit_Instruction{ .Set, .L, 0 }, 8, "SET 0, L" },
	0xC6 = { Set_Bit_Instruction{ .Set, .HL_Indirect, 0 }, 16, "SET 0, [HL]" },
	0xC7 = { Set_Bit_Instruction{ .Set, .A, 0 }, 8, "SET 0, A" },

	0xC8 = { Set_Bit_Instruction{ .Set, .B, 1 }, 8, "SET 1, B" },
	0xC9 = { Set_Bit_Instruction{ .Set, .C, 1 }, 8, "SET 1, C" },
	0xCA = { Set_Bit_Instruction{ .Set, .D, 1 }, 8, "SET 1, D" },
	0xCB = { Set_Bit_Instruction{ .Set, .E, 1 }, 8, "SET 1, E" },
	0xCC = { Set_Bit_Instruction{ .Set, .H, 1 }, 8, "SET 1, H" },
	0xCD = { Set_Bit_Instruction{ .Set, .L, 1 }, 8, "SET 1, L" },
	0xCE = { Set_Bit_Instruction{ .Set, .HL_Indirect, 1 }, 16, "SET 1, [HL]" },
	0xCF = { Set_Bit_Instruction{ .Set, .A, 1 }, 8, "SET 1, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xD0 TO 0xDF      |
      +------------------------------------+*/
	0xD0 = { Set_Bit_Instruction{ .Set, .B, 2 }, 8, "SET 2, B" },
	0xD1 = { Set_Bit_Instruction{ .Set, .C, 2 }, 8, "SET 2, C" },
	0xD2 = { Set_Bit_Instruction{ .Set, .D, 2 }, 8, "SET 2, D" },
	0xD3 = { Set_Bit_Instruction{ .Set, .E, 2 }, 8, "SET 2, E" },
	0xD4 = { Set_Bit_Instruction{ .Set, .H, 2 }, 8, "SET 2, H" },
	0xD5 = { Set_Bit_Instruction{ .Set, .L, 2 }, 8, "SET 2, L" },
	0xD6 = { Set_Bit_Instruction{ .Set, .HL_Indirect, 2 }, 16, "SET 2, [HL]" },
	0xD7 = { Set_Bit_Instruction{ .Set, .A, 2 }, 8, "SET 2, A" },

	0xD8 = { Set_Bit_Instruction{ .Set, .B, 3 }, 8, "SET 3, B" },
	0xD9 = { Set_Bit_Instruction{ .Set, .C, 3 }, 8, "SET 3, C" },
	0xDA = { Set_Bit_Instruction{ .Set, .D, 3 }, 8, "SET 3, D" },
	0xDB = { Set_Bit_Instruction{ .Set, .E, 3 }, 8, "SET 3, E" },
	0xDC = { Set_Bit_Instruction{ .Set, .H, 3 }, 8, "SET 3, H" },
	0xDD = { Set_Bit_Instruction{ .Set, .L, 3 }, 8, "SET 3, L" },
	0xDE = { Set_Bit_Instruction{ .Set, .HL_Indirect, 3 }, 16, "SET 3, [HL]" },
	0xDF = { Set_Bit_Instruction{ .Set, .A, 3 }, 8, "SET 3, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xE0 TO 0xEF      |
      +------------------------------------+*/
	0xE0 = { Set_Bit_Instruction{ .Set, .B, 4 }, 8, "SET 4, B" },
	0xE1 = { Set_Bit_Instruction{ .Set, .C, 4 }, 8, "SET 4, C" },
	0xE2 = { Set_Bit_Instruction{ .Set, .D, 4 }, 8, "SET 4, D" },
	0xE3 = { Set_Bit_Instruction{ .Set, .E, 4 }, 8, "SET 4, E" },
	0xE4 = { Set_Bit_Instruction{ .Set, .H, 4 }, 8, "SET 4, H" },
	0xE5 = { Set_Bit_Instruction{ .Set, .L, 4 }, 8, "SET 4, L" },
	0xE6 = { Set_Bit_Instruction{ .Set, .HL_Indirect, 4 }, 16, "SET 4, [HL]" },
	0xE7 = { Set_Bit_Instruction{ .Set, .A, 4 }, 8, "SET 4, A" },

	0xE8 = { Set_Bit_Instruction{ .Set, .B, 5 }, 8, "SET 5, B" },
	0xE9 = { Set_Bit_Instruction{ .Set, .C, 5 }, 8, "SET 5, C" },
	0xEA = { Set_Bit_Instruction{ .Set, .D, 5 }, 8, "SET 5, D" },
	0xEB = { Set_Bit_Instruction{ .Set, .E, 5 }, 8, "SET 5, E" },
	0xEC = { Set_Bit_Instruction{ .Set, .H, 5 }, 8, "SET 5, H" },
	0xED = { Set_Bit_Instruction{ .Set, .L, 5 }, 8, "SET 5, L" },
	0xEE = { Set_Bit_Instruction{ .Set, .HL_Indirect, 5 }, 16, "SET 5, [HL]" },
	0xEF = { Set_Bit_Instruction{ .Set, .A, 5 }, 8, "SET 5, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xF0 TO 0xFF      |
      +------------------------------------+*/
	0xF0 = { Set_Bit_Instruction{ .Set, .B, 6 }, 8, "SET 6, B" },
	0xF1 = { Set_Bit_Instruction{ .Set, .C, 6 }, 8, "SET 6, C" },
	0xF2 = { Set_Bit_Instruction{ .Set, .D, 6 }, 8, "SET 6, D" },
	0xF3 = { Set_Bit_Instruction{ .Set, .E, 6 }, 8, "SET 6, E" },
	0xF4 = { Set_Bit_Instruction{ .Set, .H, 6 }, 8, "SET 6, H" },
	0xF5 = { Set_Bit_Instruction{ .Set, .L, 6 }, 8, "SET 6, L" },
	0xF6 = { Set_Bit_Instruction{ .Set, .HL_Indirect, 6 }, 16, "SET 6, [HL]" },
	0xF7 = { Set_Bit_Instruction{ .Set, .A, 6 }, 8, "SET 6, A" },

	0xF8 = { Set_Bit_Instruction{ .Set, .B, 7 }, 8, "SET 7, B" },
	0xF9 = { Set_Bit_Instruction{ .Set, .C, 7 }, 8, "SET 7, C" },
	0xFA = { Set_Bit_Instruction{ .Set, .D, 7 }, 8, "SET 7, D" },
	0xFB = { Set_Bit_Instruction{ .Set, .E, 7 }, 8, "SET 7, E" },
	0xFC = { Set_Bit_Instruction{ .Set, .H, 7 }, 8, "SET 7, H" },
	0xFD = { Set_Bit_Instruction{ .Set, .L, 7 }, 8, "SET 7, L" },
	0xFE = { Set_Bit_Instruction{ .Set, .HL_Indirect, 7 }, 16, "SET 7, [HL]" },
	0xFF = { Set_Bit_Instruction{ .Set, .A, 7 }, 8, "SET 7, A" },
}

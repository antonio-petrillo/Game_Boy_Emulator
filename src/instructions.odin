package main

Flag_Set :: bit_set[Flags]

NOP_Instruction :: struct { }

Jump_Arg :: enum { A16, HL, E8 }
Jump_Kind :: enum { JP, JR } // NOTE: absolute and relative
Jump_Condition :: enum { None, Zero, Non_Zero, Carry, Non_Carry }
Jump_Instruction :: struct {
	kind: Jump_Kind,
	cond: Jump_Condition,
	arg: Jump_Arg,
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

Instruction_Kind :: union {
	NOP_Instruction,
	Jump_Instruction,
	Load_16_Instruction,
	Load_R8_R8,
	Load_A_A16,
	LDH_Instruction,
	Load_HL_SP,
	Increment_Instruction,
	Interrupt_Master_Enable_Instruction,
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
	0x08 = { Load_16_Instruction{ .A16 }, 20, "LD [a16], SP" },
	0x0A = { Load_R8_R8{ .A, .BC }, 8, "LD C, n8" },
	0x0C = { Increment_Instruction{ .Inc, .C }, 4, "INC C" },
	0x0D = { Increment_Instruction{ .Dec, .C }, 4, "DEC C" },
	0x0E = { Load_R8_R8{ .C, .N8 }, 8, "LD C, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x10 TO 0x1F      |
      +------------------------------------+*/
	0x11 = { Load_16_Instruction{ .DE }, 12,  "LD DE, n16"},
	0x12 = { Load_R8_R8{ .DE, .A }, 8, "LD [DE], A" },
	0x13 = { Increment_Instruction{ .Inc, .DE }, 8, "INC DE" },
	0x14 = { Increment_Instruction{ .Inc, .D }, 4, "INC D" },
	0x15 = { Increment_Instruction{ .Dec, .D }, 4, "DEC D" },
	0x16 = { Load_R8_R8{ .D, .N8 }, 8, "LD D, n8" },
	0x18 = { Jump_Instruction{ .JR, .None, .E8, 12 }, 12, "JR e8" },
	0x1A = { Load_R8_R8{ .A, .DE }, 8, "LD A, [DE]" },
	0x1C = { Increment_Instruction{ .Inc, .E }, 4, "INC E" },
	0x1D = { Increment_Instruction{ .Dec, .E }, 4, "DEC E" },
	0x1E = { Load_R8_R8{ .E, .N8 }, 8, "LD E, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x20 TO 0x2F      |
      +------------------------------------+*/
	0x20 = { Jump_Instruction{ .JR, .Non_Zero, .E8, 12 }, 8, "JR NZ, e8" },
	0x21 = { Load_16_Instruction{ .HL }, 12,  "LD HL, n16"},
	0x22 = { Load_R8_R8{ .HL_Plus, .A }, 8, "LD [HL+], A" },
	0x23 = { Increment_Instruction{ .Inc, .HL }, 8, "INC HL" },
	0x24 = { Increment_Instruction{ .Inc, .H }, 4, "INC H" },
	0x25 = { Increment_Instruction{ .Dec, .H }, 4, "DEC H" },
	0x26 = { Load_R8_R8{ .H, .N8 }, 8, "LD H, n8" },
	0x28 = { Jump_Instruction{ .JR, .Zero, .E8, 12 }, 8, "JR Z, e8" },
	0x2A = { Load_R8_R8{ .A, .HL_Plus }, 8, "LD A, [HL+]" },
	0x2C = { Increment_Instruction{ .Inc, .L }, 4, "INC L" },
	0x2D = { Increment_Instruction{ .Dec, .L }, 4, "DEC L" },
	0x2E = { Load_R8_R8{ .L, .N8 }, 8, "LD L, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x30 TO 0x3F      |
      +------------------------------------+*/
	0x30 = { Jump_Instruction{ .JR, .Non_Carry, .E8, 12 }, 8, "JR NC, e8" },
	0x31 = { Load_16_Instruction{ .SP }, 12,  "LD SP, n16"},
	0x32 = { Load_R8_R8{ .HL_Minus, .A }, 8, "LD [HL-], A" },
	0x33 = { Increment_Instruction{ .Inc, .SP }, 8, "INC SP" },
	0x34 = { Increment_Instruction{ .Inc, .HL }, 12, "INC [HL]" },
	0x35 = { Increment_Instruction{ .Dec, .HL }, 12, "DEC [HL]" },
	0x36 = { Load_R8_R8{ .HL, .N8 }, 8, "LD [HL], n8" },
	0x38 = { Jump_Instruction{ .JR, .Carry, .E8, 12 }, 8, "JR C, e8" },
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
      | INSTRUCTION FROM 0x60 TO 0x6F      |
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
      | INSTRUCTION FROM 0xC0 TO 0xCF      |
      +------------------------------------+*/
	0xC2 = { Jump_Instruction{ .JP, .Non_Zero, .A16 , 16}, 12, "JP NZ, a16" },
	0xC3 = { Jump_Instruction{ .JP, .None, .A16, 16 }, 16, "JP a16" },
	0xCA = { Jump_Instruction{ .JP, .Zero, .A16, 16 }, 12, "JP Z, a16" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xD0 TO 0xDF      |
      +------------------------------------+*/
	0xD2 = { Jump_Instruction{ .JP, .Non_Carry, .A16 , 16}, 12, "JP NC, a16" },
	0xDA = { Jump_Instruction{ .JP, .Carry, .A16, 16 }, 12, "JP C, a16" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xE0 TO 0xEF      |
      +------------------------------------+*/
	0xE0 = { LDH_Instruction{ .A8_Indirect, .A }, 12, "LDH [a8], A" },
	0xE2 = { LDH_Instruction{ .C_Indirect, .A }, 8, "LDH [C], A" },
	0xEA = { .A16, 16, "LD [a16], A" },
	0xE9 = { Jump_Instruction{ .JP, .None, .HL, 4 }, 4, "JP HL" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xF0 TO 0xFF      |
      +------------------------------------+*/
	0xF0 = { LDH_Instruction{ .A, .A8_Indirect }, 12, "LDH A, [a8]" },
	0xF2 = { LDH_Instruction{ .A, .C_Indirect }, 8, "LDH A, [C]" },
	0xF3 = { .DI, 4, "DI" },
	0xF8 = { .HL, 12, "LD HL, SP + e8" },
	0xF9 = { .HL, 12, "LD SP, HL" },
	0xFB = { .EI, 4, "EI" },
}

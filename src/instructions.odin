package main

Immediate :: enum { Imm16, Imm8, Signed_Imm8 }
Addressing :: enum { Direct, Indirect }
Register :: enum { A, Flags, B, C, D, E ,H, L, AF, BC, DE, HL, HL_Minus, HL_Plus, SP, PC }
Flag_Set :: bit_set[Flags]

NOP_Instruction :: struct { t_cycles: u64 }

Jump_Arg :: enum { A16, HL }
Jump_Instruction :: struct {
	arg: Jump_Arg,
	t_cycles: u64,
}
Conditional_Jump_Instruction :: struct {
	cond: Flag_Set,
	arg: Jump_Arg,
	t_cycles1: u64,
	t_cycles2: u64,
}

Load_16_Arg :: enum {
	BC, DE, HL, SP, A16,
}
Load_16_Instruction :: struct {
	arg: Load_16_Arg,
	t_cycles: u64,
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
	t_cycles: u64,
}

Instruction_Kind :: union {
	NOP_Instruction,
	Jump_Instruction,
	Conditional_Jump_Instruction,
	Load_16_Instruction,
	Load_R8_R8,
}

Instruction :: struct {
	kind: Instruction_Kind,
	disassembly: string,
}

INSTRUCTIONS_TABLE := [0xFF]Instruction {
	/*+------------------------------------+
      | INSTRUCTION FROM 0x00 TO 0x0F      |
      +------------------------------------+*/
	0x00 = { NOP_Instruction{ 4 }, "NOP" },
	0x01 = { Load_16_Instruction{ .BC, 12 },  "LD BC, n16"},
	0x02 = { Load_R8_R8{ .BC, .A, 8 }, "LD [BC], A" },
	0x06 = { Load_R8_R8{ .B, .N8, 8 }, "LD B, n8" },
	0x08 = { Load_16_Instruction{ .A16, 20 }, "LD [a16], SP" },
	0x0A = { Load_R8_R8{ .A, .BC, 8 }, "LD C, n8" },
	0x0E = { Load_R8_R8{ .C, .N8, 8 }, "LD C, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x10 TO 0x1F      |
      +------------------------------------+*/
	0x11 = { Load_16_Instruction{ .DE, 12 },  "LD DE, n16"},
	0x12 = { Load_R8_R8{ .DE, .A, 8 }, "LD [DE], A" },
	0x16 = { Load_R8_R8{ .D, .N8, 8 }, "LD D, n8" },
	0x1A = { Load_R8_R8{ .A, .DE, 8 }, "LD A, [DE]" },
	0x1E = { Load_R8_R8{ .E, .N8, 8 }, "LD E, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x20 TO 0x2F      |
      +------------------------------------+*/
	0x21 = { Load_16_Instruction{ .HL, 12 },  "LD HL, n16"},
	0x22 = { Load_R8_R8{ .HL_Plus, .A, 8 }, "LD [HL+], A" },
	0x26 = { Load_R8_R8{ .H, .N8, 8 }, "LD H, n8" },
	0x2A = { Load_R8_R8{ .A, .HL_Plus, 8 }, "LD A, [HL+]" },
	0x2E = { Load_R8_R8{ .L, .N8, 8 }, "LD L, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x30 TO 0x3F      |
      +------------------------------------+*/
	0x31 = { Load_16_Instruction{ .SP, 12 },  "LD SP, n16"},
	0x32 = { Load_R8_R8{ .HL_Minus, .A, 8 }, "LD [HL-], A" },
	0x36 = { Load_R8_R8{ .HL, .N8, 8 }, "LD [HL], n8" },
	0x3A = { Load_R8_R8{ .A, .HL_Minus, 8 }, "LD A, [HL-]" },
	0x3E = { Load_R8_R8{ .A, .N8, 8 }, "LD A, n8" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x40 TO 0x4F      |
      +------------------------------------+*/
	0x40 = { Load_R8_R8{ .B, .B, 4 }, "LD B, B" },
	0x41 = { Load_R8_R8{ .B, .C, 4 }, "LD B, C" },
	0x42 = { Load_R8_R8{ .B, .D, 4 }, "LD B, D" },
	0x43 = { Load_R8_R8{ .B, .E, 4 }, "LD B, E" },
	0x44 = { Load_R8_R8{ .B, .H, 4 }, "LD B, H" },
	0x45 = { Load_R8_R8{ .B, .L, 4 }, "LD B, L" },
	0x46 = { Load_R8_R8{ .B, .HL, 8 }, "LD B, [HL]" },
	0x47 = { Load_R8_R8{ .B, .A, 4 }, "LD B, A" },
	0x48 = { Load_R8_R8{ .C, .B, 4 }, "LD C, B" },
	0x49 = { Load_R8_R8{ .C, .C, 4 }, "LD C, C" },
	0x4A = { Load_R8_R8{ .C, .D, 4 }, "LD C, D" },
	0x4B = { Load_R8_R8{ .C, .E, 4 }, "LD C, E" },
	0x4C = { Load_R8_R8{ .C, .H, 4 }, "LD C, H" },
	0x4D = { Load_R8_R8{ .C, .L, 4 }, "LD C, L" },
	0x4E = { Load_R8_R8{ .C, .HL, 8 }, "LD C, [HL]" },
	0x4F = { Load_R8_R8{ .C, .A, 4 }, "LD C, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x50 TO 0x5F      |
      +------------------------------------+*/
	0x50 = { Load_R8_R8{ .D, .B, 4 }, "LD D, B" },
	0x51 = { Load_R8_R8{ .D, .C, 4 }, "LD D, C" },
	0x52 = { Load_R8_R8{ .D, .D, 4 }, "LD D, D" },
	0x53 = { Load_R8_R8{ .D, .E, 4 }, "LD D, E" },
	0x54 = { Load_R8_R8{ .D, .H, 4 }, "LD D, H" },
	0x55 = { Load_R8_R8{ .D, .L, 4 }, "LD D, L" },
	0x56 = { Load_R8_R8{ .D, .HL, 8 }, "LD D, [HL]" },
	0x57 = { Load_R8_R8{ .D, .A, 4 }, "LD D, A" },
	0x58 = { Load_R8_R8{ .E, .B, 4 }, "LD E, B" },
	0x59 = { Load_R8_R8{ .E, .C, 4 }, "LD E, C" },
	0x5A = { Load_R8_R8{ .E, .D, 4 }, "LD E, D" },
	0x5B = { Load_R8_R8{ .E, .E, 4 }, "LD E, E" },
	0x5C = { Load_R8_R8{ .E, .H, 4 }, "LD E, H" },
	0x5D = { Load_R8_R8{ .E, .L, 4 }, "LD E, L" },
	0x5E = { Load_R8_R8{ .E, .HL, 8 }, "LD E, [HL]" },
	0x5F = { Load_R8_R8{ .E, .A, 4 }, "LD E, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0x60 TO 0x6F      |
      +------------------------------------+*/
	0x60 = { Load_R8_R8{ .H, .B, 4 }, "LD H, B" },
	0x61 = { Load_R8_R8{ .H, .C, 4 }, "LD H, C" },
	0x62 = { Load_R8_R8{ .H, .D, 4 }, "LD H, D" },
	0x63 = { Load_R8_R8{ .H, .E, 4 }, "LD H, E" },
	0x64 = { Load_R8_R8{ .H, .H, 4 }, "LD H, H" },
	0x65 = { Load_R8_R8{ .H, .L, 4 }, "LD H, L" },
	0x66 = { Load_R8_R8{ .H, .HL, 8 }, "LD H, [HL]" },
	0x67 = { Load_R8_R8{ .H, .A, 4 }, "LD H, A" },
	0x68 = { Load_R8_R8{ .L, .B, 4 }, "LD L, B" },
	0x69 = { Load_R8_R8{ .L, .C, 4 }, "LD L, C" },
	0x6A = { Load_R8_R8{ .L, .D, 4 }, "LD L, D" },
	0x6B = { Load_R8_R8{ .L, .E, 4 }, "LD L, E" },
	0x6C = { Load_R8_R8{ .L, .H, 4 }, "LD L, H" },
	0x6D = { Load_R8_R8{ .L, .L, 4 }, "LD L, L" },
	0x6E = { Load_R8_R8{ .L, .HL, 8 }, "LD L, [HL]" },
	0x6F = { Load_R8_R8{ .L, .A, 4 }, "LD L, A" },


	/*+------------------------------------+
      | INSTRUCTION FROM 0x60 TO 0x6F      |
      +------------------------------------+*/
	0x70 = { Load_R8_R8{ .HL, .B, 8 }, "LD [HL], B" },
	0x71 = { Load_R8_R8{ .HL, .C, 8 }, "LD [HL], C" },
	0x72 = { Load_R8_R8{ .HL, .D, 8 }, "LD [HL], D" },
	0x73 = { Load_R8_R8{ .HL, .E, 8 }, "LD [HL], E" },
	0x74 = { Load_R8_R8{ .HL, .H, 8 }, "LD [HL], H" },
	0x75 = { Load_R8_R8{ .HL, .L, 8 }, "LD [HL], L" },
	0x77 = { Load_R8_R8{ .HL, .A, 8 }, "LD [HL], A" },
	0x78 = { Load_R8_R8{ .A, .B, 4 }, "LD A, B" },
	0x79 = { Load_R8_R8{ .A, .C, 4 }, "LD A, C" },
	0x7A = { Load_R8_R8{ .A, .D, 4 }, "LD A, D" },
	0x7B = { Load_R8_R8{ .A, .E, 4 }, "LD A, E" },
	0x7C = { Load_R8_R8{ .A, .H, 4 }, "LD A, H" },
	0x7D = { Load_R8_R8{ .A, .L, 4 }, "LD A, L" },
	0x7E = { Load_R8_R8{ .A, .HL, 8 }, "LD A, [HL]" },
	0x7F = { Load_R8_R8{ .A, .A, 4 }, "LD A, A" },

	/*+------------------------------------+
      | INSTRUCTION FROM 0xC0 TO 0xCF      |
      +------------------------------------+*/
	0xC3 = { Jump_Instruction{ .A16, 16 }, "JP a16" },
}

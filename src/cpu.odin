package main

import "core:fmt"
import "core:os"
import "core:log"

when ODIN_ENDIAN == .Little {
	_Registers :: struct #raw_union {
		r: struct { flags, a, c, b, e, d, l, h: u8 },
		l: struct { af, bc, de, hl: u16 },
	}
} else {
	_Registers :: struct #raw_union {
		r: struct { a, flags, b, c, d, e, h, l: u8 },
		l: struct { af, bc, de, hl: u16 },
	}
}

CPU_LR3590 :: struct {
	regs: _Registers,
	sp, pc: u16,
	bus: Bus,

	t_cycles: u64,
}

Flags :: enum u8 { Z, N, H, C }

is_flag_set :: proc(cpu: ^CPU_LR3590, flag: Flags) -> (b: bool) {
	switch flag {
	case .Z: b = cpu.regs.r.flags & 0x80 != 0
	case .N: b = cpu.regs.r.flags & 0x40 != 0
	case .H: b = cpu.regs.r.flags & 0x20 != 0
	case .C: b = cpu.regs.r.flags & 0x10 != 0
	}
	return
}

set_flag :: proc(cpu: ^CPU_LR3590, flag: Flags, value: bool) {
	switch flag {
	case .Z: if value { cpu.regs.r.flags |= 0x80 } else { cpu.regs.r.flags &~= 0x80 }
	case .N: if value { cpu.regs.r.flags |= 0x40 } else { cpu.regs.r.flags &~= 0x40 }
	case .H: if value { cpu.regs.r.flags |= 0x20 } else { cpu.regs.r.flags &~= 0x20 }
	case .C: if value { cpu.regs.r.flags |= 0x10 } else { cpu.regs.r.flags &~= 0x10 }
	}
}

fetch_u8 :: proc(cpu: ^CPU_LR3590) -> u8 {
	n := bus_read_u8(&cpu.bus, cpu.pc)
	cpu.pc += 1
	return n
}

fetch_u16 :: proc(cpu: ^CPU_LR3590) -> u16 {
	low, high := bus_read_u8(&cpu.bus, cpu.pc), bus_read_u8(&cpu.bus, cpu.pc + 1)
	cpu.pc += 2
	return (u16(high) << 8) | u16(low)
}

cpu_step :: proc(cpu: ^CPU_LR3590) {
	opcode := fetch_u8(cpu)
	instr := INSTRUCTIONS_TABLE[opcode]

	switch kind in instr.kind {
	case NOP_Instruction:
		cpu.t_cycles += kind.t_cycles
	case Jump_Instruction:
		unconditional_jump(cpu, kind.arg)
		cpu.t_cycles += kind.t_cycles
	case Conditional_Jump_Instruction:
		jump_to_else := conditional_jump(cpu, kind.cond, kind.arg)
		cpu.t_cycles += jump_to_else ? kind.t_cycles1 : kind.t_cycles2
	case Load_16_Instruction:
		load_16(cpu, kind)
		cpu.t_cycles += kind.t_cycles
	case Load_R8_R8:
		load_r8_r8(cpu, kind)
		cpu.t_cycles += kind.t_cycles
	}

	when ODIN_DEBUG {
		log.infof("OPCODE[0x%02x]: %s", opcode, instr.disassembly if instr.disassembly != "" else "Not Implemented Yet")
		file := (^os.File)(context.user_ptr)
		dump_cpu_to_file(cpu, file)
	}
}

load_r8_r8 :: proc(cpu: ^CPU_LR3590, instr: Load_R8_R8) {
	src: u8
	switch instr.src {
	case .A: src = cpu.regs.r.a
	case .B: src = cpu.regs.r.b
	case .C: src = cpu.regs.r.c
	case .D: src = cpu.regs.r.d
	case .E: src = cpu.regs.r.e
	case .H: src = cpu.regs.r.h
	case .L: src = cpu.regs.r.l
	case .HL: src = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	case .HL_Plus:
		src = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
		cpu.regs.l.hl += 1
	case .HL_Minus:
		src = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
		cpu.regs.l.hl -= 1
	case .BC: src = bus_read_u8(&cpu.bus, cpu.regs.l.bc)
	case .DE: src = bus_read_u8(&cpu.bus, cpu.regs.l.de)
	case .N8: src = fetch_u8(cpu)
	}

	switch instr.dest {
	case .A: cpu.regs.r.a = src
	case .B: cpu.regs.r.b = src
	case .C: cpu.regs.r.c = src
	case .D: cpu.regs.r.d = src
	case .E: cpu.regs.r.e = src
	case .H: cpu.regs.r.h = src
	case .L: cpu.regs.r.l = src
	case .BC: bus_write_u8(&cpu.bus, cpu.regs.l.bc, src)
	case .DE: bus_write_u8(&cpu.bus, cpu.regs.l.bc, src)
	case .HL: bus_write_u8(&cpu.bus, cpu.regs.l.bc, src)
	case .HL_Plus:
		bus_write_u8(&cpu.bus, cpu.regs.l.bc, src)
		cpu.regs.l.hl += 1
	case .HL_Minus:
		bus_write_u8(&cpu.bus, cpu.regs.l.bc, src)
		cpu.regs.l.hl -= 1
	}
}

load_16 :: proc(cpu: ^CPU_LR3590, instr: Load_16_Instruction) {
	value := fetch_u16(cpu)

	switch instr.arg {
	case .BC:
		cpu.regs.l.bc = value
	case .DE:
		cpu.regs.l.de = value
	case .HL:
		cpu.regs.l.hl = value
	case .A16:
		bus_write_u16(&cpu.bus, value, cpu.sp)
	case .SP:
		cpu.sp = value
	}
}

unconditional_jump :: proc(cpu: ^CPU_LR3590, arg: Jump_Arg) {
	addr: u16
	switch arg {
	case .A16: addr = fetch_u16(cpu)
	case .HL: addr = cpu.regs.l.hl
	}
	cpu.pc = addr
}

conditional_jump :: proc(cpu: ^CPU_LR3590, cond: Flag_Set, arg: Jump_Arg) -> bool {
	for flag in cond {
		if !is_flag_set(cpu, flag) { return false }
	}

	addr: u16
	switch arg {
	case .A16: addr = fetch_u16(cpu)
	case .HL: addr = cpu.regs.l.hl
	}
	cpu.pc = addr
	return true
}

// NOTE: to use with gameboy_doctor
dump_cpu_to_file :: proc(cpu: ^CPU_LR3590, f: ^os.File) {
	cpu_fmt_string ::  "A:%02x F:%02x B:%02x C:%02x D:%02x E:%02x H:%02x L:%02x SP:%04x PC:%04x PCMEM:%02x,%02x,%02x,%02x"
	mem_0 := bus_read_u8(&cpu.bus, cpu.pc)
	mem_1 := bus_read_u8(&cpu.bus, cpu.pc + 1)
	mem_2 := bus_read_u8(&cpu.bus, cpu.pc + 2)
	mem_3 := bus_read_u8(&cpu.bus, cpu.pc + 3)
	fmt.fprintfln(f, cpu_fmt_string,
				  cpu.regs.r.a, cpu.regs.r.flags,
				  cpu.regs.r.b, cpu.regs.r.c,
				  cpu.regs.r.d, cpu.regs.r.e,
				  cpu.regs.r.h, cpu.regs.r.l,
				  cpu.sp, cpu.pc,
				  mem_0, mem_1, mem_2, mem_3)
}

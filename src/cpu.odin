package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:log"

when DEBUG_INSTR {
	instructions_count: u64
}

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
	ime: bool,
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

stack_push :: proc(cpu: ^CPU_LR3590, value: u16) {
	cpu.sp -= 2
	bus_write_u16(&cpu.bus, cpu.sp, value)
}

stack_pop :: proc(cpu: ^CPU_LR3590) -> u16 {
	value := bus_read_u16(&cpu.bus, cpu.sp)
	cpu.sp += 2
	return value
}

cpu_step :: proc(cpu: ^CPU_LR3590) {
	opcode := fetch_u8(cpu)
	instr := INSTRUCTIONS_TABLE[opcode]
	cpu.t_cycles += instr.t_cycles

	when DEBUG_INSTR {
		instructions_count += 1
		if instr.disassembly == "" {
			log.warnf("[instruction count: %06d], OPCODE[0x%02x]: NOT IMPLEMENTED YET", instructions_count, opcode)
			os.exit(-1)
		}
		log.infof("[instruction count: %06d], OPCODE[0x%02x]: %s", instructions_count, opcode, instr.disassembly)
	}

	switch kind in instr.kind {
	case NOP_Instruction: // NO OP
	case Ret_Instruction:
		branched := ret_instruction(cpu, kind)
		if branched {
			cpu.t_cycles -= instr.t_cycles
			cpu.t_cycles += kind.alt_t_cycles
		}
	case Branch_Instruction:
		branched := branch_instruction(cpu, kind)
		if branched {
			cpu.t_cycles -= instr.t_cycles
			cpu.t_cycles += kind.alt_t_cycles
		}
	case Load_16_Instruction:
		load_16(cpu, kind)
	case Load_R8_R8:
		load_r8_r8(cpu, kind)
	case Load_A_A16:
		load_a_a16(cpu, kind)
	case Load_HL_SP:
		load_hl_sp(cpu, kind)
	case Increment_Instruction:
		switch increment_op in kind.arg {
		case Increment_Arg_8:
			increment_r8(cpu, kind.kind, increment_op)
		case Increment_Arg_16:
			increment_r16(cpu, kind.kind, increment_op)
		}
	case Interrupt_Master_Enable_Instruction:
		ime_instruction(cpu, kind)
	case LDH_Instruction:
		ldh_instruction(cpu, kind)
	case Stack_Instruction:
		stack_instruction(cpu, kind)
	case Math_R8_R8_Instruction:
		math_instruction(cpu, kind)
	case Prefix:
		prefix_instruction(cpu)
	case Rotate_Instruction_A: {
		rotate_instruction_a(cpu, kind)
	}
	}

	when DEBUG_INSTR {
		file := (^os.File)(context.user_ptr)
		dump_cpu_to_file(cpu, file)
	}
}

rotate_instruction_a :: proc(cpu: ^CPU_LR3590, instr: Rotate_Instruction_A) {
	set_flag(cpu, .Z, false)
	set_flag(cpu, .N, false)
	set_flag(cpu, .H, false)

	switch instr.kind {
	case .Left:
		if instr.use_carry_bit_from_byte {
			bit_carry := (cpu.regs.r.a & 0x80) != 0
			set_flag(cpu, .C, bit_carry)
			cpu.regs.r.a <<= 1

			if bit_carry { cpu.regs.r.a |= 0x01 }
		} else {
			carry := u8(is_flag_set(cpu, .C) ? 0x01 : 0x00)
			set_flag(cpu, .C, cpu.regs.r.a & 0x80 != 0)

			cpu.regs.r.a <<= 1
			cpu.regs.r.a |= carry
		}
	case .Right:
		if instr.use_carry_bit_from_byte {
			bit_carry := (cpu.regs.r.a & 0x01) != 0
			set_flag(cpu, .C, bit_carry)
			cpu.regs.r.a >>= 1

			if bit_carry { cpu.regs.r.a |= 0x80 }
		} else {
			carry := u8(is_flag_set(cpu, .C) ? 0x80 : 0x00)
			set_flag(cpu, .C, cpu.regs.r.a & 0x01 != 0)

			cpu.regs.r.a >>= 1
			cpu.regs.r.a |= carry
		}
	}
}

shift_instruction :: proc(cpu: ^CPU_LR3590, instr: Shift_Instruction) {
	value: u8
	switch instr.arg {
	case .A: value = cpu.regs.r.a
	case .B: value = cpu.regs.r.b
	case .C: value = cpu.regs.r.c
	case .D: value = cpu.regs.r.d
	case .E: value = cpu.regs.r.e
	case .H: value = cpu.regs.r.h
	case .L: value = cpu.regs.r.l
	case .HL_Indirect: value = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	}

	carry_bit: u8

	switch instr.kind {
	case .Logical:
		switch instr.rotation_kind {
		case .Left: panic("Logical Shift is only Right (clockwise)")
		case .Right:
			set_flag(cpu, .C, value & 0x1 != 0)
			value >>= 1
		}
	case .Arithmetic:
		switch instr.rotation_kind {
		case .Left:
			set_flag(cpu, .C, value & 0x80 != 0)
			value <<= 1
		case .Right:
			msb := value & 0x80
			set_flag(cpu, .C, value & 0x01 != 0)
			value >>= 1
			value |= msb
		}
	}

	set_flag(cpu, .N, false)
	set_flag(cpu, .H, false)
	set_flag(cpu, .Z, value == 0)

	switch instr.arg {
	case .A: cpu.regs.r.a = value
	case .B: cpu.regs.r.b = value
	case .C: cpu.regs.r.c = value
	case .D: cpu.regs.r.d = value
	case .E: cpu.regs.r.e = value
	case .H: cpu.regs.r.h = value
	case .L: cpu.regs.r.l = value
	case .HL_Indirect: bus_write_u8(&cpu.bus, cpu.regs.l.hl, value)
	}
}

swap_instruction :: proc(cpu: ^CPU_LR3590, instr: Swap_Instruction) {
	value: u8
	switch instr.arg {
	case .A: value = cpu.regs.r.a
	case .B: value = cpu.regs.r.b
	case .C: value = cpu.regs.r.c
	case .D: value = cpu.regs.r.d
	case .E: value = cpu.regs.r.e
	case .H: value = cpu.regs.r.h
	case .L: value = cpu.regs.r.l
	case .HL_Indirect: value = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	}

	value = ((value & 0x0F) << 0x4) | ((value & 0xF0) >> 0x4)

	switch instr.arg {
	case .A: cpu.regs.r.a = value
	case .B: cpu.regs.r.b = value
	case .C: cpu.regs.r.c = value
	case .D: cpu.regs.r.d = value
	case .E: cpu.regs.r.e = value
	case .H: cpu.regs.r.h = value
	case .L: cpu.regs.r.l = value
	case .HL_Indirect: bus_write_u8(&cpu.bus, cpu.regs.l.hl, value)
	}
}

rotate_instruction :: proc(cpu: ^CPU_LR3590, instr: Rotate_Instruction) {
	value: u8
	switch instr.arg {
	case .A: value = cpu.regs.r.a
	case .B: value = cpu.regs.r.b
	case .C: value = cpu.regs.r.c
	case .D: value = cpu.regs.r.d
	case .E: value = cpu.regs.r.e
	case .H: value = cpu.regs.r.h
	case .L: value = cpu.regs.r.l
	case .HL_Indirect: value = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	}

	switch instr.kind {
	case .Left:
		if instr.use_carry_bit_from_byte {
			carry := (value & 0x80) >> 0x7
			value <<= 1
			value += carry
		} else {
			carry := is_flag_set(cpu, .C)
			set_flag(cpu, .C, value & 0x80 != 0)
			value <<= 1
			if carry { value |= 0x01 }
		}
	case .Right:
		if instr.use_carry_bit_from_byte {
			carry := value & 0x01
			value >>= 1

			set_flag(cpu, .C, carry != 0)
			if carry != 0 {
				value |= 0x80
			}
		} else {
			carry := is_flag_set(cpu, .C)
			set_flag(cpu, .C, value & 0x01 != 0)
			value >>= 1
			if carry { value |= 0x80 }
		}
	}
	set_flag(cpu, .N, false)
	set_flag(cpu, .H, false)
	set_flag(cpu, .Z, value == 0)

	switch instr.arg {
	case .A: cpu.regs.r.a = value
	case .B: cpu.regs.r.b = value
	case .C: cpu.regs.r.c = value
	case .D: cpu.regs.r.d = value
	case .E: cpu.regs.r.e = value
	case .H: cpu.regs.r.h = value
	case .L: cpu.regs.r.l = value
	case .HL_Indirect: bus_write_u8(&cpu.bus, cpu.regs.l.hl, value)
	}
}

set_bit_instruction :: proc(cpu: ^CPU_LR3590, instr: Set_Bit_Instruction) {
	assert(instr.bit_index >= 0 && instr.bit_index < 8)
	switch instr.op {
	case .Set:
		switch instr.arg {
		case .A: cpu.regs.r.a |= 1 << instr.bit_index
		case .B: cpu.regs.r.b |= 1 << instr.bit_index
		case .C: cpu.regs.r.c |= 1 << instr.bit_index
		case .D: cpu.regs.r.d |= 1 << instr.bit_index
		case .E: cpu.regs.r.e |= 1 << instr.bit_index
		case .H: cpu.regs.r.h |= 1 << instr.bit_index
		case .L: cpu.regs.r.l |= 1 << instr.bit_index
		case .HL_Indirect:
			hl_indirect := bus_read_u8(&cpu.bus, cpu.regs.l.hl)
			hl_indirect |= 1 << instr.bit_index
			bus_write_u8(&cpu.bus, cpu.regs.l.hl, hl_indirect)
		}
	case .Res:
		switch instr.arg {
		case .A: cpu.regs.r.a &~= 1 << instr.bit_index
		case .B: cpu.regs.r.b &~= 1 << instr.bit_index
		case .C: cpu.regs.r.c &~= 1 << instr.bit_index
		case .D: cpu.regs.r.d &~= 1 << instr.bit_index
		case .E: cpu.regs.r.e &~= 1 << instr.bit_index
		case .H: cpu.regs.r.h &~= 1 << instr.bit_index
		case .L: cpu.regs.r.l &~= 1 << instr.bit_index
		case .HL_Indirect:
			hl_indirect := bus_read_u8(&cpu.bus, cpu.regs.l.hl)
			hl_indirect &~= 1 << instr.bit_index
			bus_write_u8(&cpu.bus, cpu.regs.l.hl, hl_indirect)
		}
	}
}

test_bit_instruction :: proc(cpu: ^CPU_LR3590, instr: Test_Bit_Instruction) {
	assert(instr.bit_index >= 0 && instr.bit_index < 8)
	set_flag(cpu, .N, false)
	set_flag(cpu, .C, true)

	value: u8
	switch instr.arg {
	case .A: value = cpu.regs.r.a
	case .B: value = cpu.regs.r.b
	case .C: value = cpu.regs.r.c
	case .D: value = cpu.regs.r.d
	case .E: value = cpu.regs.r.e
	case .H: value = cpu.regs.r.h
	case .L: value = cpu.regs.r.l
	case .HL_Indirect: value = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	}

	set_flag(cpu, .Z, value & (1 << instr.bit_index) == 0)
}

prefix_instruction :: proc(cpu: ^CPU_LR3590) {
	opcode := fetch_u8(cpu)
	instr := PREFIX_INSTRUCTIONS_TABLE[opcode]
	cpu.t_cycles += instr.t_cycles

	switch kind in instr.kind {
	case Test_Bit_Instruction:
		test_bit_instruction(cpu, kind)
	case Swap_Instruction:
		swap_instruction(cpu, kind)
	case Rotate_Instruction:
		rotate_instruction(cpu, kind)
	case Set_Bit_Instruction:
		set_bit_instruction(cpu, kind)
	case Shift_Instruction:
		shift_instruction(cpu, kind)
	}

	when DEBUG_INSTR {
		instructions_count += 1
		if instr.disassembly == "" {
			log.warnf("[instruction count: %06d], PREFIX -> OPCODE[0x%02x]: NOT IMPLEMENTED YET", instructions_count, opcode)
			os.exit(-1)
		}
		log.infof("[instruction count: %06d], PREFIX -> OPCODE[0x%02x]: %s", instructions_count, opcode, instr.disassembly)
	}
}

load_hl_sp :: proc(cpu: ^CPU_LR3590, instr: Load_HL_SP) {
	set_flag(cpu, .Z, false)
	set_flag(cpu, .N, false)
	switch instr {
	case .HL:

		e8 := i8(fetch_u8(cpu))
		value: int = int(cpu.sp) + int(e8)

		set_flag(cpu, .C, value & 0xFFFF000 != 0)
		set_flag(cpu, .H, ((cpu.sp & 0x0F) + u16(e8 & 0x0F)) > 0x0F)

		cpu.regs.l.hl = u16(value & 0x0000FFFF)
	case .SP:
		cpu.sp = cpu.regs.l.hl
	}
}

ldh_instruction :: proc(cpu: ^CPU_LR3590, instr: LDH_Instruction) {
	value: u8
	switch instr.src {
	case .A8_Indirect:
		addr := 0xFF00 | u16(fetch_u8(cpu))
		value = bus_read_u8(&cpu.bus, addr)
	case .C_Indirect:
		addr := 0xFF00 | u16(cpu.regs.r.c)
		value = bus_read_u8(&cpu.bus, addr)
	case .A:
		value = cpu.regs.r.a
	}

	switch instr.dest {
	case .A8_Indirect:
		addr := 0xFF00 | u16(fetch_u8(cpu))
		bus_write_u8(&cpu.bus, addr, value)
	case .C_Indirect:
		addr := 0xFF00 | u16(cpu.regs.r.c)
		bus_write_u8(&cpu.bus, addr, value)
	case .A:
		cpu.regs.r.a = value
	}
}

stack_instruction :: proc(cpu: ^CPU_LR3590, instr: Stack_Instruction) {
	switch instr.op {
	case .Push:
		switch instr.arg {
		case .BC: stack_push(cpu, cpu.regs.l.bc)
		case .DE: stack_push(cpu, cpu.regs.l.de)
		case .HL: stack_push(cpu, cpu.regs.l.hl)
		case .AF: stack_push(cpu, cpu.regs.l.af)
		}
	case .Pop:
		value := stack_pop(cpu)
		switch instr.arg {
		case .BC: cpu.regs.l.bc = value
		case .DE: cpu.regs.l.de = value
		case .HL: cpu.regs.l.hl = value
		case .AF: cpu.regs.l.af = value
		}
	}
}

ime_instruction :: proc(cpu: ^CPU_LR3590, op: Interrupt_Master_Enable_Instruction) {
	switch op {
	case .DI: cpu.ime = false
	case .EI: cpu.ime = true
	case .RETI:
		cpu.ime = true
		_ = ret_instruction(cpu, Ret_Instruction{.None, 16})
	}
}

increment_r8 :: proc(cpu: ^CPU_LR3590, op: Increment_Kind, arg: Increment_Arg_8) {
	reg: u8
	switch arg {
	case .A: reg = cpu.regs.r.a
	case .B: reg = cpu.regs.r.b
	case .C: reg = cpu.regs.r.c
	case .D: reg = cpu.regs.r.d
	case .E: reg = cpu.regs.r.e
	case .H: reg = cpu.regs.r.h
	case .L: reg = cpu.regs.r.l
	case .HL_Indirect: reg = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	}

	if op == .Inc {
		set_flag(cpu, .N, false)
		set_flag(cpu, .H, reg & 0x0F == 0x0F)
		reg += 1
	} else {
		set_flag(cpu, .N, true)
		set_flag(cpu, .H, reg & 0x0F == 0x00)
		reg -= 1
	}
	switch arg {
	case .A: cpu.regs.r.a = reg
	case .B: cpu.regs.r.b = reg
	case .C: cpu.regs.r.c = reg
	case .D: cpu.regs.r.d = reg
	case .E: cpu.regs.r.e = reg
	case .H: cpu.regs.r.h = reg
	case .L: cpu.regs.r.l = reg
	case .HL_Indirect: bus_write_u8(&cpu.bus, cpu.regs.l.hl, reg)
	}
	set_flag(cpu, .Z, reg == 0)
}

increment_r16 :: proc(cpu: ^CPU_LR3590, op: Increment_Kind, arg: Increment_Arg_16) {
	switch arg {
	case .BC: if op == .Inc { cpu.regs.l.bc += 1 } else { cpu.regs.l.bc -= 1 }
	case .DE: if op == .Inc { cpu.regs.l.de += 1 } else { cpu.regs.l.de -= 1 }
	case .HL: if op == .Inc { cpu.regs.l.hl += 1 } else { cpu.regs.l.hl -= 1 }
	case .SP: if op == .Inc { cpu.sp += 1 } else { cpu.sp -= 1 }
	}
}

load_a_a16 :: proc(cpu: ^CPU_LR3590, instr: Load_A_A16) {
	value := fetch_u16(cpu)
	switch instr {
	case .A: bus_write_u8(&cpu.bus, value, cpu.regs.r.a)
	case .A16: cpu.regs.r.a = bus_read_u8(&cpu.bus, value)
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
	case .DE: bus_write_u8(&cpu.bus, cpu.regs.l.de, src)
	case .HL: bus_write_u8(&cpu.bus, cpu.regs.l.hl, src)
	case .HL_Plus:
		bus_write_u8(&cpu.bus, cpu.regs.l.hl, src)
		cpu.regs.l.hl += 1
	case .HL_Minus:
		bus_write_u8(&cpu.bus, cpu.regs.l.hl, src)
		cpu.regs.l.hl -= 1
	}
}

load_16 :: proc(cpu: ^CPU_LR3590, instr: Load_16_Instruction) {
	value := fetch_u16(cpu)

	switch instr.dest {
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

ret_instruction :: proc(cpu: ^CPU_LR3590, instr: Ret_Instruction) -> bool {
	switch instr.cond {
	case .None:
	case .Zero: if !is_flag_set(cpu, .Z) { return false }
	case .Non_Zero: if is_flag_set(cpu, .Z) { return false }
	case .Carry: if !is_flag_set(cpu, .C) { return false }
	case .Non_Carry: if is_flag_set(cpu, .C) { return false }
	}

	cpu.pc = stack_pop(cpu)

	return true
}

branch_instruction :: proc(cpu: ^CPU_LR3590, instr: Branch_Instruction) -> bool {
	addr: u16
	switch instr.arg {
	case .A16: addr = fetch_u16(cpu)
	case .HL: addr = cpu.regs.l.hl
	case .E8:
		assert(instr.kind == .JR) // JR work only with E8
		e8 := i8(fetch_u8(cpu))
		addr = u16(i16(cpu.pc) + i16(e8))
	}

	switch instr.cond {
	case .None:
	case .Zero: if !is_flag_set(cpu, .Z) { return false }
	case .Non_Zero: if is_flag_set(cpu, .Z) { return false }
	case .Carry: if !is_flag_set(cpu, .C) { return false }
	case .Non_Carry: if is_flag_set(cpu, .C) { return false }
	}

	switch instr.kind {
	case .CALL:
		stack_push(cpu, cpu.pc)
		fallthrough
	case .JP, .JR:
		cpu.pc = addr
	}

	return true
}

math_instruction :: proc(cpu: ^CPU_LR3590, instr: Math_R8_R8_Instruction) {
	a := cpu.regs.r.a
	arg: u8
	switch instr.arg {
	case .A: arg = cpu.regs.r.a
	case .B: arg = cpu.regs.r.b
	case .C: arg = cpu.regs.r.c
	case .D: arg = cpu.regs.r.d
	case .E: arg = cpu.regs.r.e
	case .H: arg = cpu.regs.r.h
	case .L: arg = cpu.regs.r.l
	case .HL_Indirect: arg = bus_read_u8(&cpu.bus, cpu.regs.l.hl)
	case .N8: arg = fetch_u8(cpu)
	}

	result: u8
	carry, half_carry: bool
	switch instr.op {
	case .Add:
		result = a + arg
		carry = (a ~ arg ~ result) & 0x80 == 0x80
		half_carry = (a ~ arg ~ result) & 0x10 == 0x10
	case .Sub, .Cp:
		half_carry = (a & 0x0F) < (arg & 0x0F)
		carry = a < arg
		result = a - arg
	case .And:
		result = a & arg
	case .Or:
		result = a | arg
	case .Adc:
		arg += (is_flag_set(cpu, .C) ? 1 : 0)
		result = a + arg
		carry = (a ~ arg ~ result) & 0x80 == 0x80
		half_carry = (a ~ arg ~ result) & 0x10 == 0x10
	case .Sbc:
		arg += (is_flag_set(cpu, .C) ? 1 : 0)
		half_carry = (a & 0x0F) < (arg & 0x0F)
		carry = a < arg
		result = a - arg
	case .Xor:
		result = a ~ arg
	}

	for action, flag in instr.flag_actions {
		switch action {
		case .None: // Leave Flag invariated
		case .One: set_flag(cpu, flag, true)
		case .Zero: set_flag(cpu, flag, false)
		case .Compute:
			switch flag {
			case .N: panic("CPU flag 'N' has always hardcoded values")
			case .Z: set_flag(cpu, .Z, result == 0)
			case .C: set_flag(cpu, .C, carry)
			case .H: set_flag(cpu, .H, half_carry)
			}
		}
	}

	if instr.op != .Cp {
		cpu.regs.r.a = result
	}

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

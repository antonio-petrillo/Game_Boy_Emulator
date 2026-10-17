package main

import "core:log"

Long_Registers :: enum u8 {
	AF, BC, DE, HL,
}

Flags :: enum u8 {
	_unused_bit_0 = 0,
	_unused_bit_1 = 1,
	_unused_bit_2 = 2,
	_unused_bit_3 = 3,

	Carry = 4,
	Half_Carry = 5,
	Negative = 6,
	Zero = 7,
}

when ODIN_ENDIAN == .Little {

	Registers :: enum u8 {
		flags, a, c, b, e, d, l, h,
	}

	__Registers :: struct #raw_union #packed {
		registers: [Registers]u8,
		long_registers: [Long_Registers]u16,
		using _: struct {
			flags: bit_set[Flags],
			_: [7]u8,
		},
		using _: struct { f, a, c, b, e, d, l, h: u8 },
		using _: struct { af, bc, de, hl: u16 },
	}

} else {

	Registers :: enum u8 {
		a, flags, b, c, d, e, h, l,
	}

	__Registers :: struct #raw_union #packed {
		registers: [Registers]u8,
		long_registers: [Long_Registers]u16,
		using _: struct {
			_: u8,
			flags: bit_set[Flags],
			_: [6]u8,
		},
		using _: struct { a, f, b, c, d, e, h, l: u8 },
		using _: struct { af, bc, de, hl: u16 },
	}

}

CPU :: struct {
	using _: __Registers,
	sp, pc: u16,
	bus: ^Bus,
	t_cycles: u64,
}

fetch :: proc(cpu: ^CPU) -> u8 {
	n := bus_read(cpu.bus, cpu.pc)
	cpu.pc += 1
	return n
}

fetch_u16 :: proc(cpu: ^CPU) -> u16 {
	n := bus_read_u16(cpu.bus, cpu.pc)
	cpu.pc += 2
	return n
}

stack_push :: proc(cpu: ^CPU, value: u16) {
	cpu.sp -= 2
	bus_write_u16(cpu.bus, cpu.sp, value)
}

stack_pop :: proc(cpu: ^CPU) -> u16 {
	value := bus_read_u16(cpu.bus, cpu.sp)
	cpu.sp += 2
	return value
}

Alu_Op_Kind :: enum {
	Add,
	Sub,
	Add_Carry,
	Sub_Carry,
	Or,
	And,
	Xor,
	Compare,
}

// NOTE(nto): h & c are for 'half carry' and 'carry'
add :: proc(arg1, arg2: u8, carry: bool = false) -> (result: u8, h, c: bool) {
	sum := u16(arg1) + u16(arg2) + u16(carry)
	result = u8(sum)
	h = (arg1 & 0x0F) + (arg2 & 0x0F) + u8(carry) > 0x0F
	c = sum > 0xFF
	return
}

alu :: proc(cpu: ^CPU, op: Alu_Op_Kind, arg: u8) {
	result: u8
	half_carry, carry: bool
	switch op {
	case .Add:
		result, half_carry, carry = add(cpu.a, arg)
		cpu.a = result
		if half_carry { cpu.flags += { .Half_Carry } } else { cpu.flags -= { .Half_Carry } }
		if carry { cpu.flags += { .Carry } } else { cpu.flags -= { .Carry } }
		cpu.flags -= { .Negative }

	case .Sub:
		result, half_carry, carry = add(cpu.a, arg)
		cpu.a = result
		if !half_carry { cpu.flags += { .Half_Carry } } else { cpu.flags -= { .Half_Carry } }
		if !carry { cpu.flags += { .Carry } } else { cpu.flags -= { .Carry } }
		cpu.flags += { .Negative }

	case .Add_Carry:
		result, half_carry, carry = add(cpu.a, arg, .Carry in cpu.flags)
		cpu.a = result
		if half_carry { cpu.flags += { .Half_Carry } } else { cpu.flags -= { .Half_Carry } }
		if carry { cpu.flags += { .Carry } } else { cpu.flags -= { .Carry } }
		cpu.flags -= { .Negative }

	case .Sub_Carry:
		result, half_carry, carry = add(cpu.a, arg, .Carry in cpu.flags)
		cpu.a = result
		if !half_carry { cpu.flags += { .Half_Carry } } else { cpu.flags -= { .Half_Carry } }
		if !carry { cpu.flags += { .Carry } } else { cpu.flags -= { .Carry } }
		cpu.flags += { .Negative }

	case .Or:
		result = cpu.a | arg
		cpu.a = result
		cpu.flags -= { .Negative, .Carry, .Half_Carry }

	case .And:
		result = cpu.a & arg
		cpu.a = result
		cpu.flags -= { .Negative, .Carry }
		cpu.flags += { .Half_Carry }

	case .Xor:
		result = cpu.a ~ arg
		cpu.a = result
		cpu.flags -= { .Negative, .Carry, .Half_Carry }

	case .Compare:
		result, half_carry, carry = add(cpu.a,  -arg)
		if !half_carry { cpu.flags += { .Half_Carry } } else { cpu.flags -= { .Half_Carry } }
		if !carry { cpu.flags += { .Carry } } else { cpu.flags -= { .Carry } }
		cpu.flags += { .Negative }
	}

	if result == 0 { cpu.flags += { .Zero } } else { cpu.flags -= { .Zero } }
}

Inc_Or_Dec :: enum { Inc, Dec }


increment :: proc(cpu_flags: ^bit_set[Flags], reg: ^u8, op: Inc_Or_Dec) {
	switch op {
	case .Inc:
		if reg^ & 0x0F == 0x0F { cpu_flags^ += { .Half_Carry } } else { cpu_flags^ -= { .Half_Carry}}
		reg^ += 1
		cpu_flags^ -= { .Negative }
	case .Dec:
		if reg^ & 0x0F == 0x00 { cpu_flags^ -= { .Half_Carry } } else { cpu_flags^ += { .Half_Carry}}
		reg^ -= 1
		cpu_flags^ += { .Negative }
	}

	if reg^ == 0 { cpu_flags^ += { .Zero } } else { cpu_flags^ -= { .Zero } }
}


execute :: proc(cpu: ^CPU) {
	opcode := fetch(cpu)
	instruction := Instruction(opcode)

	when ODIN_DEBUG {
		log.infof("PC: 0x%04x, SP: 0x%04x, OPCODE: 0x%02x => INSTR: %v", cpu.pc, cpu.sp, opcode, instruction)
	}

	instr_t_cycles: u64
	#partial switch instruction {
	/*-------------------------------*
     | Instruction from 0x00 to 0x0F |
     *-------------------------------*/
	case .NOP: // 0x00
		instr_t_cycles = 4

	case .LD_BC_n16: // 0x01
		cpu.bc = fetch_u16(cpu)
		instr_t_cycles = 12

	case .LD_BC_Indirect_A: // 0x02
		bus_write(cpu.bus, cpu.bc, cpu.a)
		instr_t_cycles = 8

	case .INC_BC: // 0x03
		cpu.bc += 1
		instr_t_cycles = 8

	case .INC_B: // 0x04
		increment(&cpu.flags, &cpu.b, .Inc)
		instr_t_cycles = 4

	case .DEC_B: // 0x05
		increment(&cpu.flags, &cpu.b, .Dec)
		instr_t_cycles = 4

	case .LD_B_n8: // 0x06
		cpu.b = fetch(cpu)
		instr_t_cycles = 8

	case .RLCA: // 0x07
		carry: u8
		if 0x80 & cpu.a != 0 {
			carry: u8
			cpu.flags -= { .Carry }
		} else {
			cpu.flags -= { .Carry }
		}
		cpu.a = (cpu.a << 1) | carry
		cpu.flags -= { .Negative, .Zero, Half_Carry}



	/*-------------------------------*
     | Instruction from 0x10 to 0x1F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x20 to 0x2F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x30 to 0x3F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x40 to 0x4F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x50 to 0x5F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x60 to 0x6F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x70 to 0x7F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x80 to 0x8F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0x90 to 0x9F |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0xA0 to 0xAF |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0xB0 to 0xBF |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0xC0 to 0xCF |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0xD0 to 0xDF |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0xE0 to 0xEF |
     *-------------------------------*/
	/*-------------------------------*
     | Instruction from 0xF0 to 0xFF |
     *-------------------------------*/
	case: {
		log.fatalf("Not implemented yet!")
	}
	}
	cpu.t_cycles += instr_t_cycles
}

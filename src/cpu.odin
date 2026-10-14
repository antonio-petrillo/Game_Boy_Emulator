package main

import "core:log"

Long_Registers :: enum u8 {
	AF, BC, DE, HL,
}

when ODIN_ENDIAN == .Little {

	Registers :: enum u8 {
		Flags, A, C, B, E, D, L, H,
	}

	__Registers :: struct #raw_union {
			registers: [Registers]u8,
			long_registers: [Long_Registers]u16,
			using _: struct { Flags, A, C, B, E, D, L, H: u8 },
			using _: struct { AF, BC, DE, HL: u16 },
	}

} else {

	Registers :: enum u8 {
		A, Flags, B, C, D, E, H, L,
	}

	__Registers :: struct #raw_union {
		registers: [Registers]u8,
		long_registers: [Long_Registers]u16,
		using _: struct { A, Flags, B, C, D, E, H, L: u8 },
		using _: struct { AF, BC, DE, HL: u16 },
	}

}

CPU :: struct {
	using _: __Registers,
	sp, pc: u16,
	bus: ^Bus,
	t_cycles: u64,
}

Flags :: enum u8 { Z, N, H, C }

is_flag_set :: proc(cpu: ^CPU, flag: Flags) -> (b: bool) {
	switch flag {
	case .Z: b = cpu.Flags & 0x80 != 0
	case .N: b = cpu.Flags & 0x40 != 0
	case .H: b = cpu.Flags & 0x20 != 0
	case .C: b = cpu.Flags & 0x10 != 0
	}
	return
}

set_flag :: proc(cpu: ^CPU, flag: Flags, value: bool) {
	switch flag {
	case .Z: if value { cpu.Flags |= 0x80 } else { cpu.Flags &~= 0x80 }
	case .N: if value { cpu.Flags |= 0x40 } else { cpu.Flags &~= 0x40 }
	case .H: if value { cpu.Flags |= 0x20 } else { cpu.Flags &~= 0x20 }
	case .C: if value { cpu.Flags |= 0x10 } else { cpu.Flags &~= 0x10 }
	}
	return
}

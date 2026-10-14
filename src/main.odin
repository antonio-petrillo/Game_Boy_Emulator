package main

import "core:os"
import "core:log"

main :: proc() {
	context.logger = log.create_console_logger()
	log.info("GAME BOY EMULATOR - STARTED")
	defer log.info("GAME BOY EMULATOR - QUIT")

	cpu: CPU
	log.infof("\n--- cpu.[ A, F, AF ] := [ %d, %d, %d ]\n--- short := %v\n--- long := %v\n\n", cpu.A, cpu.Flags, cpu.AF, cpu.registers, cpu.long_registers)
	cpu.A = 0xFF
	cpu.Flags = 0xFF
	log.infof("\n--- cpu.[ A, F, AF ] := [ %d, %d, %d ]\n--- short := %v\n--- long := %v\n\n", cpu.A, cpu.Flags, cpu.AF, cpu.registers, cpu.long_registers)
	cpu.AF = 0x8888
	log.infof("\n--- cpu.[ A, F, AF ] := [ %d, %d, %d ]\n--- short := %v\n--- long := %v\n\n", cpu.A, cpu.Flags, cpu.AF, cpu.registers, cpu.long_registers)
	cpu.registers[.A] = 0x01
	cpu.registers[.Flags] = 0x80
	log.infof("\n--- cpu.[ A, F, AF ] := [ %d, %d, %d ]\n--- short := %v\n--- long := %v\n\n", cpu.A, cpu.Flags, cpu.AF, cpu.registers, cpu.long_registers)
}

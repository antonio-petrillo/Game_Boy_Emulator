package main

import "core:os"
import "core:log"

main :: proc() {
	context.logger = log.create_console_logger()
	log.info("GAME BOY EMULATOR - STARTED")
	defer log.info("GAME BOY EMULATOR - QUIT")

	cpu: CPU
	log.infof("cpu.[ A, F, AF ] := [ %d, %d, %d ]", cpu.A, cpu.Flags, cpu.AF)
	cpu.A = 0xFF
	cpu.Flags = 0xFF
	log.infof("cpu.[ A, F, AF ] := [ %d, %d, %d ]", cpu.A, cpu.Flags, cpu.AF)
	cpu.AF = 0x8888
	log.infof("cpu.[ A, F, AF ] := [ %d, %d, %d ]", cpu.A, cpu.Flags, cpu.AF)
}

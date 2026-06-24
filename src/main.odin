package main

import "core:log"
import "core:os"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	log_file, create_file_err := os.create("../log.txt")
	assert(create_file_err == nil)
	defer os.close(log_file)

	when ODIN_DEBUG {
		context.user_ptr = log_file
	}

	cpu := new(CPU_LR3590)
	defer free(cpu)

	path := "../deps/blargg/cpu_instrs/individual/06-ld r,r.gb"
	cart, err := cartridge_load(path)
	if err != nil {
		log.errorf("Can't load %q, error => %s", path, os.error_string(err))
		os.exit(-1)
	}
	defer {
		delete(cart.rom)
		free(cart)
	}

	cpu.bus.cart = cart
	cpu.regs.r.a = 0x01
	cpu.regs.r.flags = 0xB0
	cpu.regs.r.b = 0x00
	cpu.regs.r.c = 0x13
	cpu.regs.r.d = 0x00
	cpu.regs.r.e = 0xD8
	cpu.regs.r.h = 0x01
	cpu.regs.r.l = 0x4D
	cpu.sp = 0xFFFE
	cpu.pc = 0x0100

	dump_cpu_to_file(cpu, log_file)

	for i in 0..<10 do cpu_step(cpu)

}

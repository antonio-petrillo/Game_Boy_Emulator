package main

import "core:os"
import "core:log"

main :: proc() {
	context.logger = log.create_console_logger()
	log.info("GAME BOY EMULATOR - STARTED")
	defer log.info("GAME BOY EMULATOR - QUIT")

}

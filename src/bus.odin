package main

import "core:fmt"

Bus :: struct {
	cartridge: Cartridge,
	vram: [0x2000]u8, // 0x8000 - 0x9FFF
	wram: [0x2000]u8, // 0xC000 - 0xDFFF
	oam:  [0xA0]u8,   // 0xFE00 - 0xFE9F
	io:   [0x80]u8,   // 0xFF00 - 0xFF7F
	hram: [0x7F]u8,   // 0xFF80 - 0xFFFE
	ie: u8,           // 0xFFFF
}

bus_read :: proc(bus: ^Bus, addr: u16) -> u8 {
	switch addr {
	case 0x0000 ..= 0x7FFF:
		return cart_read(&bus.cartridge, addr)
	case 0x8000 ..= 0x9FFF:
		return bus.vram[addr - 0x8000]
	case 0xA000 ..= 0xBFFF:
		return cart_read(&bus.cartridge, addr)
	case 0xC000 ..= 0xDFFF:
		return bus.wram[addr - 0xC000]
	case 0xE000 ..= 0xFDFF: // ECHO RAM
		return bus.wram[addr - 0xE000]
	case 0xFE00 ..= 0xFE9F:
		return bus.oam[addr - 0xFE00]
	case 0xFEA0 ..= 0xFEFF:
		when ODIN_DEBUG {
			fmt.eprintfln("Reat to unusable memory 0x%04x [0xFEA0 ..= 0XFEFF]", addr)
		}
		return 0xFF
	case 0xFF00 ..= 0xFF7F:
		if addr == 0xFF44 {
			/* NOTE LY STUB */
			return 0x90
		}
		return bus.io[addr - 0xFF00]
	case 0xFF80 ..= 0xFFFE:
		return bus.hram[addr - 0xFF80]
	case 0xFFFF:
		return bus.ie
	}
}

bus_write :: proc(bus: ^Bus, addr: u16, value: u8) {
	switch addr {
	case 0x0000 ..= 0x7FFF:
		cart_write(&bus.cartridge, addr, value)
	case 0x8000 ..= 0x9FFF:
		bus.vram[addr - 0x8000] = value
	case 0xA000 ..= 0xBFFF:
		cart_write(&bus.cartridge, addr, value)
	case 0xC000 ..= 0xDFFF:
		bus.wram[addr - 0xC000] = value
	case 0xE000 ..= 0xFDFF: // ECHO ram
		bus.wram[addr - 0xE000] = value
	case 0xFE00 ..= 0xFE9F:
		bus.oam[addr - 0xFE00] = value
	case 0xFEA0 ..= 0xFEFF:
		when ODIN_DEBUG {
			fmt.eprintfln("Write to unusable memory 0x%04x [0xFEA0 ..= 0XFEFF]", addr)
		}
	case 0xFF00 ..= 0xFF7F:
		bus.io[addr - 0xFF00] = value
		/* NOTE: hack for Blargg's tests */
		if addr == 0xFF02 && value == 0x81 {
			fmt.printf("%c", rune(bus.io[0x01]))
			bus.io[0x02] = 0x00
		}
	case 0xFF80 ..= 0xFFFE:
		bus.hram[addr - 0xFF80] = value
	case 0xFFFF:
		bus.ie = value
	}
}

bus_read_u16 :: proc(bus: ^Bus, addr: u16) -> u16 {
	low, high := bus_read(bus, addr), bus_read(bus, addr + 1)
	return u16(high) << 8 | u16(low)
}

bus_write_u16 :: proc(bus: ^Bus, addr: u16, value: u16) {
	low, high := u8(value), u8(value >> 8)
	bus_write(bus, addr, low)
	bus_write(bus, addr + 1, high)
}

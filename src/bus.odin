package main

Bus :: struct {
	cart: ^Cartridge,
	vram: [0x2000]u8,
	eram: [0x2000]u8,
	wram: [0x2000]u8,
	oam: [0xA0]u8,
	io: [0x80]u8,
	hram: [0xFFFE - 0xFF80 + 0x1]u8,
	ie: u8,
}

bus_read_u8 :: proc(bus: ^Bus, addr: u16) -> (n: u8) {
	when ODIN_DEBUG {
		if addr == 0xFF44 { return 0x90 }
	}

	switch addr {
	case 0x0000 ..= 0x7FFF:
		n = cartridge_read(bus.cart, addr)
	case 0x8000 ..= 0x9FFF:
		n = bus.vram[addr - 0x8000]
	case 0xA000 ..= 0xBFFF:
		n = bus.eram[addr - 0xA000]
	case 0xC000 ..= 0xDFFF:
		n = bus.wram[addr - 0xC000]
	case 0xE000 ..= 0xFDFF:
		n = bus.wram[addr - 0xE000] // echo
	case 0xFE00 ..= 0xFE9F:
		n = bus.oam[addr - 0xFE00]
	case 0xFEA0 ..= 0xFEFF:
		n = 0xFF // unusable
	case 0xFF00 ..= 0xFF7F:
		n = bus.io[addr - 0xFF00]
	case 0xFF80 ..= 0xFFFE:
		n = bus.hram[addr - 0xFF80]
	case 0xFFFF:
		n = bus.ie
	}
	return
}

bus_write_u8 :: proc(bus: ^Bus, addr: u16, value: u8) {
	switch addr {
	case 0x0000 ..= 0x7FFF:
		cartridge_write(bus.cart, addr, value)
	case 0x8000 ..= 0x9FFF:
		bus.vram[addr - 0x8000] = value
	case 0xA000 ..= 0xBFFF:
		bus.eram[addr - 0xA000] = value
	case 0xC000 ..= 0xDFFF:
		bus.wram[addr - 0xC000] = value
	case 0xE000 ..= 0xFDFF:
		bus.wram[addr - 0xE000] = value // echo
	case 0xFE00 ..= 0xFE9F:
		bus.oam[addr - 0xFE00] = value
	case 0xFEA0 ..= 0xFEFF:
		// unusable
	case 0xFF00 ..= 0xFF7F:
		bus.io[addr - 0xFF00] = value
	case 0xFF80 ..= 0xFFFE:
		bus.hram[addr - 0xFF80] = value
	case 0xFFFF:
		bus.ie = value
	}
	return
}

bus_read_u16 :: proc(bus: ^Bus, addr: u16) -> u16 {
	low, high := bus_read_u8(bus, addr), bus_read_u8(bus, addr + 1)
	return (u16(high) << 8) | u16(low)
}

bus_write_u16 :: proc(bus: ^Bus, addr: u16, value: u16) {
	low, high := u8(value), u8(value >> 8)
	bus_write_u8(bus, addr, low)
	bus_write_u8(bus, addr + 1, high)
}

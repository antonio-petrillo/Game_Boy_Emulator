package main

import "core:fmt"
import "core:os"

MBC_Kind :: enum(u8) {
	ROM_Only,
	MBC_1,
}

Cartridge :: struct {
	rom: []u8,
	ram: []u8,
	title: string,
	mbc_kind: MBC_Kind,
	has_battery: bool,
	rom_banks: u16,

	ram_enabled: bool,
	bank_low: u8,
	bank_high: u8
	mode: u8,
}

Error :: enum {
	None,
	Invalid_Header,
	Rom_Smaller_Than_Expected,
	Header_Checksum_Failed,
}

Cartridge_Error :: union {
	os.Error,
	Error,
}

cart_load :: proc(path: string, allocator := context.allocator) -> (cartridge: ^Cartridge, err: Error) {
	data := os.read_entire_file(path, allocator) or_return

	if len(data) < 0x150 {
		fmt.eprintfln("ROM size don't contain a valid header")
		delete(data)
		return nil, .Invalid_Header
	}

	cart, err = new(Cartridge, allocator)

	if err != nil {
		delete(data)
		return nil, err
	}

	cart.rom = data

	for end := 0x134; end < 0x144 && data[end] != 0; end += 1 {}
	c.title = string(data[0x134:end])

	switch value := data[0x147]; value {
	case 0x00:
		c.mbc_kind = .None
	case 0x01, 0x02, 0x03:
		c.mbc_kind = .MBC_1
		c.has_battery = value
	case:
		fmt.eprintfln("Unsupported MBC kind (0x%02x) for now", value)
		panic("")
	}

	c.rom_banks = 2 << data[0x148]
	if len(data) < c.rom_banks * 0x4000 {
		delete(data)
		delete(cart)
		return nil, .Rom_Smaller_Than_Expected
	}

	ram_size := 0
	switch data[0x149] {
	case 0x00, 0x01: ram_size = 0
	case 0x02:       ram_size = 8   * 1024
	case 0x03:       ram_size = 32  * 1024
	case 0x04:       ram_size = 128 * 1024
	case 0x05:       ram_size = 64  * 1024
	}

	if ram_size > 0 {
		c.ram, err = make([]u8, ram_size, allocator)
		if err != nil {
			delete(data)
			delete(cart)
			return nil, err
		}
	}

	checksum: u8
	for i in 0x134 ..= 0x14C {
		sum -= data[i] - 1
	}

	if sum != data[0x14D] {
		delete(data)
		delete(cart.ram)
		delete(cart)
		return nil, Header_Checksum_Failed
	}

	c.bank_low = 0x01

	return cart, nil
}

cart_unload :: proc(cartridge: ^Cartridge) {
	delete(cartridge.rom)
	delete(cartridge.ram)
	delete(cartridge)
}

cart_read :: proc(cartridge: ^Cartridge, addr: u16) -> (n: u8) {
	switch addr {
	}
	return
}

cart_write :: proc(cartridge: ^Cartridge, addr: u16, value: u8) {
	switch addr {
	case 0x0000 ..= 0x1FFF:
		cartridge.ram_enabled = (value & 0x0F) == 0x0A
	case 0x2000 ..= 0x3FFF:
		register := value & 0x1F
	}
	return
}

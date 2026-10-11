package main

import "base:runtime"
import "core:fmt"
import "core:os"

MBC_Kind :: enum(u8) {
	ROM_Only,
	MBC_1,
}

Mode_Kind :: enum {
	Simple,
	Advanced,
}

Cartridge :: struct {
	rom: []u8,
	ram: []u8,
	title: string,
	mbc_kind: MBC_Kind,
	has_battery: bool,
	rom_banks: u16,
	bank_low, bank_high: u8,

	ram_enabled: bool,

	mode: Mode_Kind,

	read_proc: proc(cart: ^Cartridge, addr: u16) -> u8,
	write_proc: proc(cart: ^Cartridge, addr: u16, value: u8),
}

Parse_Cartridge_Error :: enum {
	None,
	Invalid_Header,
	Rom_Size_Is_Not_What_Expected,
	RAM_Unknown_Size,
	ROM_Unknown_Size,
	Header_Checksum_Failed,
	Unknown_MBC_Kind,
}

Cartridge_Error :: union {
	os.Error,
	runtime.Allocator_Error,
	Parse_Cartridge_Error,
}

cartridge_load :: proc(path: string, allocator := context.allocator) -> (_cart: ^Cartridge, err: Cartridge_Error) {
	data := os.read_entire_file(path, allocator) or_return

	defer if err != nil {
		delete(data)
	}

	if len(data) < 0x150 {
		fmt.eprintfln("ROM size don't contain a valid header")
		return nil, .Invalid_Header
	}

	cart := new(Cartridge, allocator) or_return

	defer if err != nil {
		free(cart)
	}

	cart.rom = data

	end := 0x134
	for ; end < 0x144 && data[end] != 0; end += 1 {}
	cart.title = string(data[0x134:end])

	switch value := data[0x147]; value {
	case 0x00:
		cart.mbc_kind = .ROM_Only
		cart.read_proc = cart_read_rom_only
		cart.write_proc = cart_write_rom_only
	case 0x01, 0x02, 0x03:
		cart.mbc_kind = .MBC_1
		cart.has_battery = value == 0x03
		cart.read_proc = cart_read_mbc1
		cart.write_proc = cart_write_mbc1

	case:
		fmt.eprintfln("Unsupported MBC kind (0x%02x) for now", value)
		return nil, .Unknown_MBC_Kind
	}

	switch value := data[0x148]; value {
	case 0x00 ..= 0x08: cart.rom_banks = 2 << value
	case 0x52:          cart.rom_banks = 72
	case 0x53:          cart.rom_banks = 80
	case 0x54:          cart.rom_banks = 96
	case: return nil, .ROM_Unknown_Size
	}

	if len(data) < int(cart.rom_banks) * 0x4000 {
		return nil, .Rom_Size_Is_Not_What_Expected
	}

	ram_size := 0
	switch data[0x149] {
	case 0x00: ram_size = 0
	case 0x01:       /* UNUSED */
	case 0x02:       ram_size = 8   * runtime.Kilobyte
	case 0x03:       ram_size = 32  * runtime.Kilobyte
	case 0x04:       ram_size = 128 * runtime.Kilobyte
	case 0x05:       ram_size = 64  * runtime.Kilobyte
	case:
		return nil, .RAM_Unknown_Size
	}

	if ram_size > 0 {
		cart.ram = make([]u8, ram_size, allocator) or_return
	}

	defer if ram_size > 0 && err != nil {
		delete(cart.ram)
	}

	cart.bank_low = 0x01

	checksum: u8
	for i in 0x134 ..= 0x14C {
		checksum = checksum - data[i] - 1
	}

	if checksum != data[0x14D] {
		return nil, .Header_Checksum_Failed
	}

	return cart, nil
}

cart_unload :: proc(cartridge: ^Cartridge) {
	delete(cartridge.rom)
	delete(cartridge.ram)
	free(cartridge)
}

cart_read_rom_only :: proc(cartridge: ^Cartridge, addr: u16) -> (n: u8) {
	if addr >= 0x8000 { return 0xFF }
	return cartridge.rom[addr]
}

cart_write_rom_only :: proc(cartridge: ^Cartridge, addr: u16, value: u8) {  }

cart_read_mbc1 :: proc(cart: ^Cartridge, addr: u16) -> (n: u8) {
	/* TODO */
	switch addr {
	case 0x0000 ..= 0x3FFF:
		switch cart.mode {
		case .Simple:
			return cart.rom[addr]
		case .Advanced:
			bank := (u32(cart.bank_high) << 5) % u32(cart.rom_banks)
			return cart.rom[bank * 0x4000 + u32(addr)]
		}

	case 0x4000 ..= 0x7FFF:
		bank := (u32(cart.bank_high) << 5) | u32(cart.bank_low & 0x1F)

		if bank & 0x1F == 0 {
			bank += 1
		}

		bank %= u32(cart.rom_banks)
		return cart.rom[bank * 0x4000 + u32(addr - 0x4000)]

	case 0xA000 ..= 0xBFFF:
		if !cart.ram_enabled || len(cart.ram) == 0 {
			return 0xFF
		}

		switch cart.mode {
		case .Simple:
			return cart.ram[addr - 0xA000]
		case .Advanced:
			ram_addr := (u32(cart.bank_high) * 0x2000 + u32(addr - 0xA000)) % u32(len(cart.ram))
			return cart.ram[ram_addr]
		}

	}
	return 0xFF
}

cart_write_mbc1 :: proc(cart: ^Cartridge, addr: u16, value: u8) {
	switch addr {
	case 0x0000 ..= 0x1FFF:
		cart.ram_enabled = (value & 0x0F) == 0x0A

	case 0x2000 ..= 0x3FFF:
		cart.bank_low = value & 0x1F
		if cart.bank_low == 0 {
			cart.bank_low = 1
		}

	case 0x4000 ..= 0x5FFF:
		cart.bank_high = value & 0x03

	case 0x6000 ..= 0x7FFF:
		cart.mode = value & 0x01 == 0 ? .Simple : .Advanced

	case 0xA000 ..= 0xBFFF:
		if !cart.ram_enabled || len(cart.ram) == 0 {
			return
		}

		switch cart.mode {
		case .Simple:
			cart.ram[addr - 0xA000] = value
		case .Advanced:
			ram_addr := (u32(cart.bank_high) * 0x2000 + u32(addr - 0xA000)) % u32(len(cart.ram))
			cart.ram[ram_addr] = value
		}
	}
}

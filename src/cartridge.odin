package main

import "core:os"
import "base:runtime"

// TODO: only MBC0 for now, implement the rest
Cartridge :: struct {
	rom: []u8,
}

cartridge_load :: proc(path: string, allocator := context.allocator) -> (cart: ^Cartridge, err: os.Error) {
	data := os.read_entire_file(path, allocator) or_return

	cart, err = new(Cartridge, allocator)

	if err != nil {
		delete(data)
		return nil, err
	}

	cart.rom = data
	return cart, nil
}

cartridge_read :: proc(cart: ^Cartridge, addr: u16) -> u8{
	return cart.rom[addr]
}

cartridge_write :: proc(cart: ^Cartridge, addr: u16, value: u8) {
	// TODO: not implemented for MBC0
}

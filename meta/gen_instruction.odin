#+feature dynamic-literals
package meta

import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:strings"

INPUT_FILE :: #config(IN, "../assets/Opcodes.json")
OUTPUT_FILE :: #config(OUT, "../src/instructions.odin")
INDIRECT :: "Indirect"

main :: proc() {
	allocator := context.temp_allocator
	data, read_err := os.read_entire_file(INPUT_FILE, allocator)

	if read_err != nil {
		fmt.eprintfln("Can't load json: %v", read_err)
		return
	}

	json_data, parse_err := json.parse(data, allocator = allocator)
	if parse_err != nil {
		fmt.eprintfln("Can't parse json: %v", parse_err)
		return
	}
	root, ok := json_data.(json.Object)
	if !ok {
		fmt.eprintfln("JSON file is not what I expected\nDowload it from 'https://gbdev.io/gb-opcodes/Opcodes.json'", parse_err)
		return
	}
	unprefixed := root["unprefixed"].(json.Object)
	prefixed := root["cbprefixed"].(json.Object)

	file, create_file_err := os.create(OUTPUT_FILE)
	if create_file_err != nil {
		fmt.eprintfln("Can't create output file")
		return
	}
	defer os.close(file)

	fmt.fprintfln(file, `package main

Instruction :: enum u8 {{`)
	codegen(file, unprefixed, allocator = allocator)


	fmt.fprintfln(file, `

Prefix_Insturction :: enum u8 {{`)
	codegen(file, prefixed, true, allocator = allocator)

}

codegen :: proc(file: ^os.File, obj: json.Object, is_prefixed := false, allocator := context.allocator) {
	illegal_instruction_id := 0
	tok := struct{}{}
	illegal_instructions := map[string]struct {} {
		"0xD3" = tok, "0xDB" = tok, "0xDD" = tok,
		"0xE3" = tok, "0xE4" = tok, "0xEB" = tok, "0xEC" = tok, "0xED" = tok,
		"0xF5" = tok, "0xFC" = tok, "0xFD" = tok,
	}
	operand_translation := map[string]string {
		"$00" = "00",
		"$10" = "10",
		"$20" = "20",
		"$30" = "30",
		"$08" = "08",
		"$18" = "18",
		"$28" = "28",
		"$38" = "38",
	}

	operands: [dynamic; 8]string // NOTE(nto): at most 3 operands and at most all are INDIRECT + INCREMENT + DECREMENT
	for instr in 0x00 ..= 0xFF  {
		code := fmt.tprintf("0x%02X", instr)
		entry := obj[code].(json.Object)
		if !is_prefixed && code in illegal_instructions {
			fmt.fprintfln(file, "\tILLEGAL_%02x = %s,", illegal_instruction_id, code)
			illegal_instruction_id += 1
			continue
		}

		fmt.fprintf(file, "\t%s", entry["mnemonic"].(string))

		for _operand in entry["operands"].(json.Array) {
			operand := _operand.(json.Object)
			name :=  operand["name"].(string)
			if name in operand_translation {
				name = operand_translation[name]
			}
			if name == "HL" {
				if increment, ok := operand["increment"].(bool); ok && increment {
					name = "HL_Increment"
				} else if decrement, ok := operand["decrement"].(bool); ok && decrement {
					name = "HL_Decrement"
				}
			}
			append(&operands, name)
			if !operand["immediate"].(bool) {
				append(&operands, INDIRECT)
			}

		}

		enum_entry_name := strings.join(operands[:], sep = "_", allocator = allocator)

		if len(operands) > 0 {
			fmt.fprintf(file, "_%s", enum_entry_name)
		}
		fmt.fprintfln(file, " = %s,", code)
		clear(&operands)
	}

	fmt.fprintfln(file, "}")
}

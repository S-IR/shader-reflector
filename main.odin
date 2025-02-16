package shader_reflector
import "core:/math"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "core:unicode/utf8/utf8string"

default_args :: proc() -> Args {
	return {path = "", mainFnName = "main"}
}


main :: proc() {
	args := os.args[1:]

	path: string
	defer delete(path)

	fmt.printfln("args %v", args)
	for arg in args {
		if !strings.has_prefix(arg, "-") {
			if len(path) > 0 do panicf("invalid argument : `%v `. All arguments except for the path must start with `-`` ", arg)
			path = arg
		}

	}
	if len(path) == 0 do panicf("path not provided")

	path = filepath.clean(path)

	fnArgs := default_args()
	fnArgs.path = path
	start_search(fnArgs)
}

ShaderTypeModifier :: enum {
	MISSING,
	RowMajor,
	ColumnMajor,
}
ShaderType :: enum {
	MISSING,
	Float,
	Matrix,
}

ShaderStructField :: struct {
	name:                 string,
	semanticModifier:     string,
	type:                 ShaderType,
	typeMatrixDimensions: [2]int,
	typeModifier:         ShaderTypeModifier,
	typeArrayDimensions:  [5]int,
}
ShaderStruct :: struct {
	name:   string,
	fields: [dynamic]ShaderStructField,
}
ShaderTag :: enum {
	MISSING,
	Struct,
	Fn,
}

MAX_SHADER_STRUCTS :: 1024
shaderStructs := [MAX_SHADER_STRUCTS]ShaderStruct{}
currShaderStructI := 0
MAX_FIELD_NAME :: 36

structWord :: "struct"

float4x4Word :: "float4x4"
floatWord :: "float"
matrixWord :: "matix"

rowMajorWord :: "row_major"
columnMajorWord :: "column_major"

line := 1
pos := 0
path: string
Args :: struct {
	path:       string,
	mainFnName: string,
}
ShaderFileInfo :: struct {
	mainFnName: string,
	path:       string,
	structs:    []ShaderStruct,
}

start_search :: proc(args: Args) -> ShaderFileInfo {


	path = args.path
	file, fileExists := os.read_entire_file(args.path)
	if !fileExists {
		panicf("invalid shader path:  %v", args.path)
	}
	defer delete(file)


	currTag: ShaderTag = .MISSING
	currField: ShaderStructField = {}


	defer free_all(context.temp_allocator)

	braceNestedLevel := 0


	currStruct: ^ShaderStruct = nil
	currStructHasSemantic := false
	fileStr: utf8string.String
	utf8string.init(&fileStr, string(file))
	fmt.println("START")

	i := 0
	lenS := utf8string.len(&fileStr)


	fileLoop: for i < lenS {
		defer skip_i(&i, 1, &fileStr)


		prevChar := utf8string.at(&fileStr, max(i - 1, 0))
		if utf8string.at(&fileStr, i) == '\r' do continue

		defer pos += 1
		// if i < next do continue


		if utf8string.at(&fileStr, i) == ' ' || utf8string.at(&fileStr, i) == '\t' do continue

		if utf8string.at(&fileStr, i) == '\n' {
			new_line()
			continue
		}


		// Skip comments
		if i < lenS - 1 && utf8string.at(&fileStr, i) == '/' {
			temp := utf8string.at(&fileStr, i + 1)
			if temp == '/' {
				skip_i(&i, 2, &fileStr)

				for i < lenS && utf8string.at(&fileStr, i) != '\n' do skip_i(&i, 1, &fileStr)
				new_line()

			} else if utf8string.at(&fileStr, i + 1) == '*' {
				skip_i(&i, 2, &fileStr)

				for i < lenS - 1 &&
				    !(utf8string.at(&fileStr, i) == '*' && utf8string.at(&fileStr, i + 1) == '/') {
					if utf8string.at(&fileStr, i) == '\n' do new_line()
					skip_i(&i, 1, &fileStr)
					continue
				}

				//skipping 2 with the +1 from defer i+=1 
				skip_i(&i, 1, &fileStr)
				continue

			}

		}


		switch true {

		case unicode.is_space(utf8string.at(&fileStr, i)):
			continue

		case is_substr_at_i(&fileStr, i, structWord) &&
		     unicode.is_space(utf8string.at(&fileStr, i + utf8.rune_count(structWord))):
			currTag = .Struct
			currStruct = &shaderStructs[currShaderStructI]
			skip_i(&i, utf8.rune_count(structWord), &fileStr)
			continue
		case currTag == .Struct && len(currStruct.name) == 0:
			name, amountToSkip, valid := find_word_from_i(&fileStr, i)
			if !valid {
				skip_i(&i, amountToSkip, &fileStr)
				panicflp("invalid struct name")
			}
			if utf8.rune_count(name) > MAX_FIELD_NAME {
				panicflp(
					"field name too long (over %d characters long): '%s'",
					MAX_FIELD_NAME,
					name,
				)
			}

			currStruct.name = name
			currStruct.fields = make([dynamic]ShaderStructField)
			skip_i(&i, amountToSkip, &fileStr)
			continue
		case utf8string.at(&fileStr, i) == '{':
			if currTag != .Struct && currTag != .Fn {
				panicflp("invalid syntax for file %v ")
			}
			braceNestedLevel += 1
			if braceNestedLevel > 1 do panicflp("no nesting brackets allowed ")

		// case utf8string.at(&fileStr, i) == ':':
		// 	panicflp("invalid semicolon usage")


		case utf8string.at(&fileStr, i) == '}':
			braceNestedLevel -= 1
			if braceNestedLevel < 0 do panicflp("invalid syntax. forgot to close braces ")


			skip_i(&i, 1, &fileStr)
			skip_spaces(&fileStr, &i)
			if utf8string.at(&fileStr, i) != ';' do panicflp("you forgot to put a ; at the end of the struct")
			if currTag == .Struct {
				currStruct = nil
				currShaderStructI += 1
			}
			currTag = nil

		//case we're in a struct and we are reading names
		case braceNestedLevel == 1 && len(currStruct.name) > 0:
			assert(currField.type == .MISSING)

			//get the type
			type, dims, typeSkip := get_type_of_field(&fileStr, i)
			//if no type first check for the type modifier
			if type == .MISSING {
				typeModifier, modifierSkip := get_type_modifier_of_field(&fileStr, i)
				if typeModifier == .MISSING {
					panicflp("unknown type or type modifier : %s ", find_word_from_i(&fileStr, i))
				}
				currField.typeModifier = typeModifier

				skip_i(&i, modifierSkip, &fileStr)
				skip_spaces(&fileStr, &i)
				//then get the type
				type, dims, typeSkip = get_type_of_field(&fileStr, i)
				if type == .MISSING {
					panicflp("unknown type  : %s ", find_word_from_i(&fileStr, i))
				}
			}
			currField.type = type
			currField.typeMatrixDimensions = dims
			skip_i(&i, typeSkip, &fileStr)
			skip_spaces(&fileStr, &i)


			//get name
			name, skipName, valid := find_word_from_i(&fileStr, i, {'['})
			if !valid {
				skip_i(&i, skipName, &fileStr)
				panicflp("invalid struct field name")
			}
			currField.name = name
			skip_i(&i, skipName, &fileStr)
			skip_spaces(&fileStr, &i)

			if utf8string.at(&fileStr, i) == '[' {
				arraySizes, skipFromDimensions := find_type_array_dimensions(&fileStr, i)
				assert(skipFromDimensions > 0)
				currField.typeArrayDimensions = arraySizes
				skip_i(&i, skipFromDimensions)
				skip_spaces(&fileStr, &i)

			}

			if utf8string.at(&fileStr, i) == ':' {
				skip_i(&i, 1, &fileStr)
				skip_spaces(&fileStr, &i)
				semantic, skipSemantic, valid := find_word_from_i(&fileStr, i)
				if !valid {
					skip_i(&i, skipSemantic, &fileStr)
					panicflp("invalid struct semantic name")
				}
				skip_i(&i, skipSemantic, &fileStr)
				skip_spaces(&fileStr, &i)
				currField.semanticModifier = semantic

			}
			if utf8string.at(&fileStr, i) != ';' {
				fmt.printfln("rune (%v)", utf8string.at(&fileStr, i))

				fmt.printfln("surrounding %v", utf8string.slice(&fileStr, i, i + 10))
				panicflp("you forgot a semicolon for this struct field")
			}


			append(&currStruct^.fields, currField)
			currField = {}

		case is_substr_at_i(&fileStr, i, "main"):
			break fileLoop
		// fmt.printfln("structs:")
		// for i in 0 ..< currShaderStructI {
		// 	fmt.printfln("%v", shaderStructs[i])
		// }
		// continue

		}
	}
	for i in 0 ..< currShaderStructI {
		currStruct := shaderStructs[i]
		validate_struct(currStruct)

	}
	res: ShaderFileInfo = {
		path       = args.path,
		mainFnName = args.mainFnName,
		structs    = shaderStructs[0:currShaderStructI],
	}
	return res
}
new_line :: proc() {
	line += 1
	pos = 0
}


validate_struct :: proc(currStruct: ShaderStruct) {
	assert(len(currStruct.name) > 0)
	if len(currStruct.fields) > 0 {
		for field in currStruct.fields {
			assert(len(field.name) > 0)
			if !valid_struct_field(field) do panicf("wrong type. modifier:(%v) type:(%v) and dimensions:(%v) ", field.typeModifier, field.type, field.typeMatrixDimensions)
		}
	}
}


valid_struct_field :: proc(field: ShaderStructField) -> bool {
	ValidFloatModifiers: []ShaderTypeModifier : {.MISSING}
	ValidMatrixModifier: []ShaderTypeModifier : {.RowMajor, .MISSING, .ColumnMajor}


	if field.type == .Float {
		assert(field.typeMatrixDimensions[0] > 0)
		if field.typeMatrixDimensions[0] > 4 ||
		   field.typeMatrixDimensions[1] > 4 ||
		   field.typeMatrixDimensions[0] < 0 ||
		   field.typeMatrixDimensions[1] < 0 {
			return false
		}

		if field.typeMatrixDimensions[1] > 0 {
			//this is a matrix type
			if !slice.contains(ValidMatrixModifier, field.typeModifier) {
				return false
			}
		}

		if !slice.contains(ValidFloatModifiers, field.typeModifier) do return false
	}

	if field.type == .Matrix && !slice.contains(ValidMatrixModifier, field.typeModifier) {
		return false
	}

	return true

}
get_type_modifier_of_field :: proc(
	s: ^utf8string.String,
	i: int,
) -> (
	type: ShaderTypeModifier,
	amountToSkip: int,
) {
	assert(i >= 0)

	switch true {

	case is_substr_at_i(s, i, rowMajorWord):
		return .RowMajor, strings.rune_count(rowMajorWord)

	case is_substr_at_i(s, i, columnMajorWord):
		return .ColumnMajor, strings.rune_count(columnMajorWord)
	case:
		return .MISSING, 0
	// panicflp("unknown type : %s ", find_word_from_i(s, i))
	}

}
get_type_of_field :: proc(
	s: ^utf8string.String,
	i: int,
) -> (
	type: ShaderType,
	typeMatrixDimensions: [2]int,
	amountToSkip: int,
) {
	assert(i >= 0)


	switch true {


	case is_substr_at_i(s, i, floatWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(floatWord))
		return .Float, dims, strings.rune_count(floatWord) + skip


	case is_substr_at_i(s, i, matrixWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(matrixWord))
		return .Matrix, dims, strings.rune_count(matrixWord) + skip

	case:
		return .MISSING, {}, 0
	// panicflp("unknown type : %s ", find_word_from_i(s, i))
	}


}


skip_i :: proc(i: ^int, amount: int, stringForDebugPrinting: ^utf8string.String = nil) {
	assert(i != nil)

	if (ODIN_DEBUG == true) && (stringForDebugPrinting != nil) {
		// Start from the current position i^
		for j in i^ ..< i^ + amount {
			if j < utf8string.len(stringForDebugPrinting) {
				char := utf8string.at(stringForDebugPrinting, j)
				fmt.printf("%v", char)
			}
		}
	}

	// Increment i^ by amount (not amount + 1)
	i^ += amount
	pos += amount
}
skip_spaces :: proc(s: ^utf8string.String, i: ^int) {
	for i^ < utf8string.len(s) && unicode.is_space(utf8string.at(s, i^)) {
		skip_i(i, 1, s)
	}
}
spaces_that_follow :: proc(s: ^utf8string.String, i: int) -> int {
	count: int = 0
	for i < utf8string.len(s) && unicode.is_space(utf8string.at(s, i + count)) {
		count += 1
	}
	return count
}


get_type_matrix_dimensions :: proc(s: ^utf8string.String, i: int) -> ([2]int, int) {

	firstChar := utf8string.at(s, i)
	if unicode.is_space(firstChar) do return {1, 0}, 1

	if !unicode.is_number(firstChar) do panicflp("invalid character symbol %v ", firstChar)

	first, ok := strconv.parse_int(utf8string.slice(s, i, i + 1))
	if !ok do panicflp("invalid character symbol %v ", firstChar)

	secondChar := utf8string.at(s, i + 1)
	if secondChar != 'x' {
		if !unicode.is_space(secondChar) {
			panicflp("invalid syntax. should've hadd a space here")
		}
		return {first, 0}, 1
	}


	thirdChar := utf8string.at(s, i + 2)
	second, okSecond := strconv.parse_int(utf8string.slice(s, i + 2, i + 3))
	if !okSecond do panicflp("invalid character symbol. need a second digit %v ", firstChar)

	forthChar := utf8string.at(s, i + 3)
	if !unicode.is_space(forthChar) do panicflp("invalid syntax. required space here")

	return {first, second}, 4


}
find_type_array_dimensions :: proc(s: ^utf8string.String, i: int) -> ([5]int, int) {
	startChar := utf8string.at(s, i)
	if startChar == ';' do return {}, 0

	if startChar != '[' do panicflp("invalid syntax. either put a ; or open an [ to open an array type")


	res: [5]int = {}
	currResultIndex := 0
	offsetFromI := 0


	for utf8string.at(s, i + offsetFromI) == '[' {
		MAX_DIGIT_LEN :: 10
		digits: [MAX_DIGIT_LEN]int
		digitsLen := 0

		// if utf8string.at(s, i + offsetFromI) != '[' do panicflp("invalid syntax for doing an array type. put a [")

		//skip the first [
		offsetFromI += 1

		for unicode.is_digit(utf8string.at(s, i + offsetFromI + digitsLen)) {
			digits[digitsLen], _ = strconv.parse_int(
				utf8string.slice(s, i + offsetFromI + digitsLen, i + offsetFromI + digitsLen + 1),
			)

			if digitsLen > len(digits) {
				panicflp(
					"what on planet earth are you doing trying to create an array type with this many digits (%v) ?max is %v ",
					digitsLen,
					len(digits),
				)
			}

			digitsLen += 1

		}

		if utf8string.at(s, i + offsetFromI + digitsLen) != ']' {
			line += offsetFromI + digitsLen
			panicflp("invalid character")
		}

		arraySize := 0
		for i in 0 ..< digitsLen {
			arraySize += int(math.pow_f64(10, f64(digitsLen - i - 1))) * digits[i]
		}
		res[currResultIndex] = arraySize

		currResultIndex += 1
		//1 for ] + the number of digits
		offsetFromI += 1 + digitsLen
	}
	skipSpaces := i + offsetFromI + spaces_that_follow(s, i + offsetFromI)
	fmt.printfln("!dwa!  (%v)", utf8string.slice(s, skipSpaces - 5, skipSpaces + 5))
	fmt.printfln("!dwa 1!(%v)", utf8string.at(s, skipSpaces))


	if utf8string.at(s, skipSpaces) != ':' && utf8string.at(s, skipSpaces) != ';' {
		panicflp("invalid array syntax. should have a ; or : for syntax modifiers at the end")
	}

	return res, offsetFromI

}


find_word_from_i :: proc(
	s: ^utf8string.String,
	i: int,
	extraStopAts: []rune = {},
) -> (
	res: string,
	amountToSkip: int,
	valid: bool,
) {


	// if strings.is_space() utf8string.at(s,i )
	j := i
	currRune := utf8string.at(s, j)

	if !unicode.is_letter(currRune) {
		return "", 0, false
	}
	for j < utf8string.len(s) && (j - i) < MAX_FIELD_NAME && !is_end_of_name(s, j, extraStopAts) {
		currRune = utf8string.at(s, j)

		if !unicode.is_letter(currRune) &&
		   !unicode.is_number(currRune) &&
		   !strings.is_delimiter(currRune) {
			return "", 0, false
		}

		j += 1
	}
	return utf8string.slice(s, i, j), j - i, true
}
is_substr_at_i :: proc(s: ^utf8string.String, i: int, subStr: string) -> bool {
	numOfRunes := utf8.rune_count(subStr)
	if i + numOfRunes >= utf8string.len(s) do return false
	return utf8string.slice(s, i, i + numOfRunes) == subStr
}
is_end_of_name :: proc(s: ^utf8string.String, j: int, extraStopAts: []rune = {}) -> bool {
	currRune := utf8string.at(s, j)
	return(
		j >= utf8string.len(s) ||
		currRune == ';' ||
		currRune == '\n' ||
		strings.is_space(currRune) ||
		slice.contains(extraStopAts, currRune) \
	)
}
panicflp :: proc(fmtArg: string, args: ..any) {
	userStr := fmt.tprintf(fmtArg, ..args)
	linePosStr := fmt.tprintf("(line: %d, pos: %d , path: %s)", line, pos, path)
	fullStr := fmt.tprintf("%s | %s", userStr, linePosStr)
	panic(fullStr)

}
panicf :: proc(fmtArg: string, args: ..any) {
	panic(fmt.tprintfln(fmtArg, ..args))
}

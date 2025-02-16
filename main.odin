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
	Static,
	//interpolation values
	Nointerpolation,
	Linear,
	Centroid,
	NoPerspective,
	Sample,

	//if it is a nested struct use the "matrix dimensions"[0] as a way to keep track of the index of the struct that's nested
}
rowMajorWord :: "row_major"
columnMajorWord :: "column_major"
nointerpolationWord :: "nointerpolation"
sampleWord :: "sample"
centroidWord :: "centroid"
linearWord :: "linear"
staticWord :: "static"
noPerspectiveWord :: "noperspective"

ShaderType :: enum {
	MISSING,
	Float,
	Matrix,
	Bool,
	Int,
	Uint,
	Half,
	Double,
	Min16float,
	Min16int,
	Min12int,
	Min16uint,
	Int64_t,
	Uint64_t,


	//texture types
	Texture1D,
	Texture1DArray,
	Texture2D,
	Texture2DArray,
	Texture3D,
	TextureCube,
	TextureCubeArray,
	Texture2DMS,
	Texture2DMSArray,
	RWTexture1D,
	RWTexture1DArray,
	RWTexture2D,
	RWTexture2DArray,
	RWTexture3D,
	NestedStruct,
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

floatWord :: "float"
matrixWord :: "matix"

boolWord :: "bool"
intWord :: "int"
uintWord :: "uint"
dwordWord :: "dword"
halfWord :: "half"
doubleWord :: "double"
min16floatWord :: "min16float"
min16intWord :: "min16int"
min12intWord :: "min12int"
min16uintWord :: "min16uint"
int64_tWord :: "int64_t"
uint64_tWord :: "uint64_t"

texture1DWord :: "texture1D"
texture1DArrayWord :: "texture1DArray"
texture2DWord :: "texture2D"
texture2DArrayWord :: "texture2DArray"
texture3DWord :: "texture3D"
textureCubeWord :: "textureCube"
textureCubeArrayWord :: "textureCubeArray"
texture2DMSWord :: "texture2DMS"
texture2DMSArrayWord :: "texture2DMSArray"
rWTexture1DWord :: "rWTexture1D"
rWTexture1DArrayWord :: "rWTexture1DArray"
rWTexture2DWord :: "rWTexture2D"
rWTexture2DArrayWord :: "rWTexture2DArray"
rWTexture3DWord :: "rWTexture3D"

packoffsetWord :: "packoffset"


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
			name, skipName, valid := find_word_from_i(&fileStr, i, {'[', ':'})
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

				//ignore pack offsets in naked structs
				if semantic == packoffsetWord {
					skip_i(&i, utf8.rune_count(packoffsetWord), &fileStr)
					count := 0
					maxRounds := 10
					for count < maxRounds &&
					    i < utf8string.len(&fileStr) &&
					    utf8string.at(&fileStr, i + count) != ')' {
						count += 1
					}
					skip_i(&i, 1, &fileStr)
				}


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
	ValidArithmeticModifiers: []ShaderTypeModifier : {
		.MISSING,
		.Static,
		.Nointerpolation,
		.Linear,
		.Centroid,
		.NoPerspective,
		.Sample,
	}
	ValidMatrixModifier: []ShaderTypeModifier : {.RowMajor, .MISSING, .ColumnMajor}


	ArithmeticList: []ShaderType : []ShaderType {
		.Float,
		.Bool,
		.Int,
		.Uint,
		.Half,
		.Double,
		.Min16float,
		.Min16int,
		.Min12int,
		.Min16uint,
		.Int64_t,
		.Uint64_t,
	}
	if field.type == .Matrix && !slice.contains(ValidMatrixModifier, field.typeModifier) {
		return false
	} else if slice.contains(ArithmeticList, field.type) {
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
		} else {
			if !slice.contains(ValidArithmeticModifiers, field.typeModifier) do return false
		}

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
	case is_substr_at_i(s, i, nointerpolationWord):
		return .Nointerpolation, strings.rune_count(nointerpolationWord)
	case is_substr_at_i(s, i, centroidWord):
		return .Centroid, strings.rune_count(centroidWord)
	case is_substr_at_i(s, i, sampleWord):
		return .Sample, strings.rune_count(sampleWord)
	case is_substr_at_i(s, i, noPerspectiveWord):
		return .NoPerspective, strings.rune_count(noPerspectiveWord)
	case is_substr_at_i(s, i, linearWord):
		return .Linear, strings.rune_count(linearWord)

	case is_substr_at_i(s, i, staticWord):
		return .Static, strings.rune_count(staticWord)
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


	case is_substr_at_i(s, i, min16floatWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(min16floatWord))
		return .Min16float, dims, strings.rune_count(min16floatWord) + skip
	case is_substr_at_i(s, i, min16intWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(min16intWord))
		return .Min16int, dims, strings.rune_count(min16intWord) + skip

	case is_substr_at_i(s, i, min12intWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(min12intWord))
		return .Min12int, dims, strings.rune_count(min12intWord) + skip


	case is_substr_at_i(s, i, min16uintWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(min16uintWord))
		return .Min16uint, dims, strings.rune_count(min16uintWord) + skip


	case is_substr_at_i(s, i, int64_tWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(int64_tWord))
		return .Int64_t, dims, strings.rune_count(int64_tWord) + skip

	case is_substr_at_i(s, i, uint64_tWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(uint64_tWord))
		return .Uint64_t, dims, strings.rune_count(uint64_tWord) + skip


	case is_substr_at_i(s, i, floatWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(floatWord))
		return .Float, dims, strings.rune_count(floatWord) + skip


	case is_substr_at_i(s, i, matrixWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(matrixWord))
		return .Matrix, dims, strings.rune_count(matrixWord) + skip

	case is_substr_at_i(s, i, boolWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(boolWord))
		return .Bool, dims, strings.rune_count(boolWord) + skip


	case is_substr_at_i(s, i, intWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(intWord))
		return .Int, dims, strings.rune_count(intWord) + skip


	case is_substr_at_i(s, i, uintWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(uintWord))
		return .Uint, dims, strings.rune_count(intWord) + skip


	case is_substr_at_i(s, i, dwordWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(dwordWord))
		return .Uint, dims, strings.rune_count(dwordWord) + skip

	case is_substr_at_i(s, i, halfWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(halfWord))
		return .Half, dims, strings.rune_count(halfWord) + skip


	case is_substr_at_i(s, i, doubleWord):
		dims, skip := get_type_matrix_dimensions(s, i + utf8.rune_count(doubleWord))
		return .Double, dims, strings.rune_count(doubleWord) + skip


	case is_substr_at_i(s, i, texture1DWord):
		return .Texture1D, {}, strings.rune_count(texture1DWord)
	case is_substr_at_i(s, i, texture1DArrayWord):
		return .Texture1DArray, {}, strings.rune_count(texture1DArrayWord)
	case is_substr_at_i(s, i, texture2DWord):
		return .Texture2D, {}, strings.rune_count(texture2DWord)
	case is_substr_at_i(s, i, texture2DArrayWord):
		return .Texture2DArray, {}, strings.rune_count(texture2DArrayWord)
	case is_substr_at_i(s, i, texture3DWord):
		return .Texture3D, {}, strings.rune_count(texture3DWord)
	case is_substr_at_i(s, i, textureCubeWord):
		return .TextureCube, {}, strings.rune_count(textureCubeWord)
	case is_substr_at_i(s, i, textureCubeArrayWord):
		return .TextureCubeArray, {}, strings.rune_count(textureCubeArrayWord)
	case is_substr_at_i(s, i, texture2DMSWord):
		return .Texture2DMS, {}, strings.rune_count(texture2DMSWord)
	case is_substr_at_i(s, i, texture2DMSArrayWord):
		return .Texture2DMSArray, {}, strings.rune_count(texture2DMSArrayWord)
	case is_substr_at_i(s, i, rWTexture1DWord):
		return .RWTexture1D, {}, strings.rune_count(rWTexture1DWord)
	case is_substr_at_i(s, i, rWTexture1DArrayWord):
		return .RWTexture1DArray, {}, strings.rune_count(rWTexture1DArrayWord)
	case is_substr_at_i(s, i, rWTexture2DWord):
		return .RWTexture2D, {}, strings.rune_count(rWTexture2DWord)
	case is_substr_at_i(s, i, rWTexture2DArrayWord):
		return .RWTexture2DArray, {}, strings.rune_count(rWTexture2DArrayWord)
	case is_substr_at_i(s, i, rWTexture3DWord):
		return .RWTexture3D, {}, strings.rune_count(rWTexture3DWord)

	case is_nested_struct_type(s, i) != -1:
		index := is_nested_struct_type(s, i)
		return .NestedStruct, {index, 0}, utf8.rune_count(shaderStructs[index].name)


	case:
		return .MISSING, {}, 0
	// panicflp("unknown type : %s ", find_word_from_i(s, i))
	}

	is_nested_struct_type :: proc(s: ^utf8string.String, i: int) -> int {
		for i in 0 ..< currShaderStructI {
			currStrct := shaderStructs[i]
			if is_substr_at_i(s, i, currStrct.name, true) do return i
		}
		return -1
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
is_substr_at_i :: proc(
	s: ^utf8string.String,
	i: int,
	subStr: string,
	requireSpaceAtTheEnd := false,
) -> bool {
	numOfRunes := utf8.rune_count(subStr)
	if i + numOfRunes >= utf8string.len(s) do return false

	if requireSpaceAtTheEnd {
		if !unicode.is_space(utf8string.at(s, i + numOfRunes)) do return false
	}
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

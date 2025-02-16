package shader_reflector

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:testing"
@(test)
test_read_structs :: proc(t: ^testing.T) {
	path := filepath.join({"test-files", "structs.hlsl"})

	testing.expect(t, os.exists(path))

	fnArgs := default_args()
	fnArgs.path = path
	res := start_search(fnArgs)

	testing.expect_value(t, res.path, path)
	testing.expect_value(t, res.mainFnName, "main")
	testing.expect_value(t, len(res.structs), 4)


	testing.expect_value(t, res.structs[0].name, "FloatStruct")
	testing.expect_value(t, len(res.structs[0].fields), 4)


	testing.expect_value(t, res.structs[0].fields[0].type, ShaderType.Float)
	testing.expect_value(t, res.structs[0].fields[0].typeMatrixDimensions, [2]int{4, 0})

	testing.expect_value(t, res.structs[0].fields[0].name, "position")
	testing.expect_value(t, res.structs[0].fields[0].semanticModifier, "")

	testing.expect_value(t, res.structs[0].fields[1].type, ShaderType.Float)
	testing.expect_value(t, res.structs[0].fields[1].typeMatrixDimensions, [2]int{3, 0})
	testing.expect_value(t, res.structs[0].fields[1].name, "normal")
	testing.expect_value(t, res.structs[0].fields[1].semanticModifier, "")


	testing.expect_value(t, res.structs[0].fields[2].type, ShaderType.Float)
	testing.expect_value(t, res.structs[0].fields[2].typeMatrixDimensions, [2]int{2, 0})
	testing.expect_value(t, res.structs[0].fields[2].name, "texCoord")
	testing.expect_value(t, res.structs[0].fields[2].semanticModifier, "")

	testing.expect_value(t, res.structs[0].fields[3].type, ShaderType.Float)
	testing.expect_value(t, res.structs[0].fields[3].typeMatrixDimensions, [2]int{1, 0})
	testing.expect_value(t, res.structs[0].fields[3].name, "scalar")
	testing.expect_value(t, res.structs[0].fields[3].semanticModifier, "")

	//struct 1

	testing.expect_value(t, res.structs[1].name, "Output")
	testing.expect_value(t, res.structs[1].fields[0].type, ShaderType.Float)
	testing.expect_value(t, res.structs[1].fields[0].typeMatrixDimensions, [2]int{2, 0})
	testing.expect_value(t, res.structs[1].fields[0].name, "TexCoord")
	testing.expect_value(t, res.structs[1].fields[0].semanticModifier, "TEXCOORD0")

	testing.expect_value(t, res.structs[1].fields[1].type, ShaderType.Float)
	testing.expect_value(t, res.structs[1].fields[1].typeMatrixDimensions, [2]int{4, 0})
	testing.expect_value(t, res.structs[1].fields[1].name, "Position")
	testing.expect_value(t, res.structs[1].fields[1].semanticModifier, "SV_Position")

	//struct 2
	testing.expect_value(t, res.structs[2].name, "EmptyStruct")
	testing.expect_value(t, len(res.structs[2].fields), 0)

	//struct 3
	testing.expect_value(t, res.structs[3].name, "ArrayStruct")
	testing.expect_value(t, res.structs[3].fields[0].type, ShaderType.Float)
	testing.expect_value(t, res.structs[3].fields[0].typeMatrixDimensions, [2]int{2, 2})
	testing.expect_value(t, res.structs[3].fields[0].typeArrayDimensions, [5]int{1, 2, 3, 0, 0})
	testing.expect_value(t, res.structs[3].fields[0].name, "a")
	testing.expect_value(t, res.structs[3].fields[0].semanticModifier, "TEXCOORD0")

	testing.expect_value(t, res.structs[3].fields[1].type, ShaderType.Float)
	testing.expect_value(t, res.structs[3].fields[1].typeMatrixDimensions, [2]int{4, 4})
	testing.expect_value(t, res.structs[3].fields[1].typeArrayDimensions, [5]int{10, 1, 0, 0, 0})
	testing.expect_value(t, res.structs[3].fields[1].name, "b")
	testing.expect_value(t, res.structs[3].fields[1].semanticModifier, "SV_Depth")


}

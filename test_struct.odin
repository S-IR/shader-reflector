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
	testing.expect_value(t, len(res.structs), 6)


	//struct 0
	{
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

	}

	//struct 1
	{
		testing.expect_value(t, res.structs[1].name, "Output")
		testing.expect_value(t, res.structs[1].fields[0].type, ShaderType.Float)
		testing.expect_value(t, res.structs[1].fields[0].typeMatrixDimensions, [2]int{2, 0})
		testing.expect_value(t, res.structs[1].fields[0].name, "TexCoord")
		testing.expect_value(t, res.structs[1].fields[0].semanticModifier, "TEXCOORD0")

		testing.expect_value(t, res.structs[1].fields[1].type, ShaderType.Float)
		testing.expect_value(t, res.structs[1].fields[1].typeMatrixDimensions, [2]int{4, 0})
		testing.expect_value(t, res.structs[1].fields[1].name, "Position")
		testing.expect_value(t, res.structs[1].fields[1].semanticModifier, "SV_Position")
	}


	//struct 2
	{
		testing.expect_value(t, res.structs[2].name, "EmptyStruct")
		testing.expect_value(t, len(res.structs[2].fields), 0)
	}
	//struct 3
	{
		testing.expect_value(t, res.structs[3].name, "ArrayStruct")
		testing.expect_value(t, res.structs[3].fields[0].type, ShaderType.Float)
		testing.expect_value(t, res.structs[3].fields[0].typeMatrixDimensions, [2]int{2, 2})
		testing.expect_value(
			t,
			res.structs[3].fields[0].typeArrayDimensions,
			[5]int{1, 2, 3, 0, 0},
		)
		testing.expect_value(t, res.structs[3].fields[0].name, "a")
		testing.expect_value(t, res.structs[3].fields[0].semanticModifier, "TEXCOORD0")

		testing.expect_value(t, res.structs[3].fields[1].type, ShaderType.Float)
		testing.expect_value(t, res.structs[3].fields[1].typeMatrixDimensions, [2]int{4, 4})
		testing.expect_value(
			t,
			res.structs[3].fields[1].typeArrayDimensions,
			[5]int{10, 1, 0, 0, 0},
		)
		testing.expect_value(t, res.structs[3].fields[1].name, "b")
		testing.expect_value(t, res.structs[3].fields[1].semanticModifier, "SV_Depth")

	}

	//struct 4
	{
		testing.expect_value(t, res.structs[4].name, "OtherNumberTypes")
		testing.expect_value(t, len(res.structs[4].fields), 14)

		// Field 0: nointerpolation int a : TEXCOORD2;
		testing.expect_value(t, res.structs[4].fields[0].name, "a")
		testing.expect_value(t, res.structs[4].fields[0].type, ShaderType.Int)
		testing.expect_value(
			t,
			res.structs[4].fields[0].typeModifier,
			ShaderTypeModifier.Nointerpolation,
		)

		testing.expect_value(t, res.structs[4].fields[0].semanticModifier, "TEXCOORD2")

		// Field 1: linear bool b;
		testing.expect_value(t, res.structs[4].fields[0].name, "a")
		testing.expect_value(t, res.structs[4].fields[0].type, ShaderType.Int)
		testing.expect_value(
			t,
			res.structs[4].fields[0].typeModifier,
			ShaderTypeModifier.Nointerpolation,
		)
		testing.expect_value(t, res.structs[4].fields[0].semanticModifier, "TEXCOORD2")

		// Field 1: linear bool b;
		testing.expect_value(t, res.structs[4].fields[1].name, "b")
		testing.expect_value(t, res.structs[4].fields[1].type, ShaderType.Bool)
		testing.expect_value(t, res.structs[4].fields[1].typeModifier, ShaderTypeModifier.Linear)
		testing.expect_value(t, res.structs[4].fields[1].semanticModifier, "")

		// Field 2: static int c;
		testing.expect_value(t, res.structs[4].fields[2].name, "c")
		testing.expect_value(t, res.structs[4].fields[2].type, ShaderType.Int)
		testing.expect_value(t, res.structs[4].fields[2].typeModifier, ShaderTypeModifier.Static)
		testing.expect_value(t, res.structs[4].fields[2].semanticModifier, "")

		// Field 3: centroid uint d;
		testing.expect_value(t, res.structs[4].fields[3].name, "d")
		testing.expect_value(t, res.structs[4].fields[3].type, ShaderType.Uint)
		testing.expect_value(t, res.structs[4].fields[3].typeModifier, ShaderTypeModifier.Centroid)
		testing.expect_value(t, res.structs[4].fields[3].semanticModifier, "")

		// Field 4: noperspective dword e;
		testing.expect_value(t, res.structs[4].fields[4].name, "e")
		testing.expect_value(t, res.structs[4].fields[4].type, ShaderType.Uint) // assuming dword maps to uint
		testing.expect_value(
			t,
			res.structs[4].fields[4].typeModifier,
			ShaderTypeModifier.NoPerspective,
		)
		testing.expect_value(t, res.structs[4].fields[4].semanticModifier, "")

		// Field 5: sample half f;
		testing.expect_value(t, res.structs[4].fields[5].name, "f")
		testing.expect_value(t, res.structs[4].fields[5].type, ShaderType.Half)
		testing.expect_value(t, res.structs[4].fields[5].typeModifier, ShaderTypeModifier.Sample)
		testing.expect_value(t, res.structs[4].fields[5].semanticModifier, "")

		// Field 6: float g;
		testing.expect_value(t, res.structs[4].fields[6].name, "g")
		testing.expect_value(t, res.structs[4].fields[6].type, ShaderType.Float)
		testing.expect_value(t, res.structs[4].fields[6].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[6].semanticModifier, "")

		// Field 7: double h;
		testing.expect_value(t, res.structs[4].fields[7].name, "h")
		testing.expect_value(t, res.structs[4].fields[7].type, ShaderType.Double)
		testing.expect_value(t, res.structs[4].fields[7].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[7].semanticModifier, "")

		// Field 8: min16float i;
		testing.expect_value(t, res.structs[4].fields[8].name, "i")
		testing.expect_value(t, res.structs[4].fields[8].type, ShaderType.Min16float)
		testing.expect_value(t, res.structs[4].fields[8].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[8].semanticModifier, "")

		// Field 9: min16int k;
		testing.expect_value(t, res.structs[4].fields[9].name, "k")
		testing.expect_value(t, res.structs[4].fields[9].type, ShaderType.Min16int)
		testing.expect_value(t, res.structs[4].fields[9].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[9].semanticModifier, "")

		// Field 10: min16uint m;
		testing.expect_value(t, res.structs[4].fields[10].name, "m")
		testing.expect_value(t, res.structs[4].fields[10].type, ShaderType.Min16uint)
		testing.expect_value(t, res.structs[4].fields[10].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[10].semanticModifier, "")

		// Field 11: int64_t n;
		testing.expect_value(t, res.structs[4].fields[11].name, "n")
		testing.expect_value(t, res.structs[4].fields[11].type, ShaderType.Int64_t)
		testing.expect_value(t, res.structs[4].fields[11].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[11].semanticModifier, "")

		// Field 12: uint64_t o;
		testing.expect_value(t, res.structs[4].fields[12].name, "o")
		testing.expect_value(t, res.structs[4].fields[12].type, ShaderType.Uint64_t)
		testing.expect_value(t, res.structs[4].fields[12].typeModifier, ShaderTypeModifier.MISSING)
		testing.expect_value(t, res.structs[4].fields[12].semanticModifier, "")
	}


	//struct 5
	testing.expect_value(t, res.structs[5].name, "Wrapper")
	testing.expect_value(t, len(res.structs[5].fields), 1)


	testing.expect_value(t, res.structs[5].fields[0].type, ShaderType.NestedStruct)
	testing.expect_value(t, res.structs[5].fields[0].name, "nested")
	index := res.structs[5].fields[0].typeMatrixDimensions[0]
	testing.expect(t, index < len(res.structs))
	testing.expect_value(t, res.structs[index].name, "OtherNumberTypes")

	testing.expect_value(t, res.structs[0].fields[0].semanticModifier, "")


}

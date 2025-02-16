
//skip me pls
//skip me pls

/*
skip me
skip me
skip me
skip me
skip me
skip me
skip me

*/

struct FloatStruct
{
    float4 position;
    float3 normal;
    float2 texCoord;
    float scalar;
};

struct Output
{
    
    float2 TexCoord  : TEXCOORD0;
    float4 Position : SV_Position;
};
struct EmptyStruct {
};


struct ArrayStruct
{
    
    float2x2 a[1][2][3]  : TEXCOORD0;
    float4x4 b[10][1] : SV_Depth;
};
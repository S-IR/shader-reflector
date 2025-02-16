
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

struct OtherNumberTypes
{
    nointerpolation int a: TEXCOORD2; 
    linear bool b;
    static int c;
    centroid uint d;
    noperspective dword e;
    sample half f;
     float g;
     double h;
     min16float i;
     min16int k;
     min16uint m;
     int64_t n;
     uint64_t o;
     float pwda ;

};
struct Wrapper{
    OtherNumberTypes nested;
    Output nested2[10];
};
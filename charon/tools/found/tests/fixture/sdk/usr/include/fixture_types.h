// Types another SDK header declares, as simd's vector types and sys's typedefs are: no framework's Headers/ folder holds them. A
// declaration of Fixture.framework reaches them, so the framework's shard keeps their typedef rows (decls: the foreign typedefs a
// declaration reaches, through the chain each one names).
typedef __attribute__((__ext_vector_type__(3))) float fx_float3;
typedef fx_float3 fx_vector3;
typedef unsigned char fx_byte;
typedef fx_byte fx_family;

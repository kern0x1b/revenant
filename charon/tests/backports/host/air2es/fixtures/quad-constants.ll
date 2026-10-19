target triple = "air64-apple-ios12.0.0"

@_Z8use_tint.MTL_FC_INIT_0_b = internal unnamed_addr addrspace(2) externally_initialized constant i8 undef, section "air.fc_initializer", align 1
@_Z4gain.MTL_FC_INIT_1_f = internal unnamed_addr addrspace(2) externally_initialized constant float undef, section "air.fc_initializer", align 4
@__metal_implicit_fc_pred_0 = internal addrspace(2) global i8 0, align 1

declare i8 @air.normalize_function_constant_predicate.i8(i8)
declare i1 @air.is_function_constant_defined(ptr addrspace(2))

define internal void @initialise() section "air.static_init" {
  %1 = load i8, ptr addrspace(2) @_Z8use_tint.MTL_FC_INIT_0_b, align 1
  %2 = tail call i8 @air.normalize_function_constant_predicate.i8(i8 %1)
  store i8 %2, ptr addrspace(2) @__metal_implicit_fc_pred_0, align 1
  ret void
}

define <4 x float> @constFragment(<4 x float> %0) {
  %2 = load i8, ptr addrspace(2) @__metal_implicit_fc_pred_0, align 1
  %3 = icmp ne i8 %2, 0
  %4 = load float, ptr addrspace(2) @_Z4gain.MTL_FC_INIT_1_f, align 4
  %5 = tail call i1 @air.is_function_constant_defined(ptr addrspace(2) @_Z4gain.MTL_FC_INIT_1_f)
  %6 = select i1 %5, float %4, float 2.500000e-01
  %7 = select i1 %3, float %6, float 7.500000e-01
  %8 = insertelement <4 x float> undef, float %7, i64 0
  %9 = insertelement <4 x float> %8, float %7, i64 1
  %10 = insertelement <4 x float> %9, float %7, i64 2
  %11 = insertelement <4 x float> %10, float 1.000000e+00, i64 3
  ret <4 x float> %11
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @constFragment, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}

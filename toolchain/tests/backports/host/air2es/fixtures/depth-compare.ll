target triple = "air64-apple-ios12.0.0"

define <4 x float> @shadowCompare(<4 x float> %0, <2 x float> %1, ptr addrspace(1) %2, ptr addrspace(2) %3, ptr addrspace(2) readonly "air-buffer-no-alias" %4) {
  %reference = load float, ptr addrspace(2) %4, align 4
  %sampled = call { float, i8 } @air.sample_compare_depth_2d.f32(ptr addrspace(1) %2, ptr addrspace(2) %3, i32 1, <2 x float> %1, float %reference, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.000000e+00, float 0.000000e+00, i32 0)
  %lit = extractvalue { float, i8 } %sampled, 0
  %c0 = insertelement <4 x float> undef, float %lit, i64 0
  %c1 = insertelement <4 x float> %c0, float %lit, i64 1
  %c2 = insertelement <4 x float> %c1, float %lit, i64 2
  %c3 = insertelement <4 x float> %c2, float 1.000000e+00, i64 3
  ret <4 x float> %c3
}

declare { float, i8 } @air.sample_compare_depth_2d.f32(ptr addrspace(1), ptr addrspace(2), i32, <2 x float>, float, i1, <2 x i32>, i1, float, float, i32)

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @shadowCompare, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5, !6, !7, !8, !9}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!6 = !{i32 1, !"air.fragment_input", !"generated(5coordDv2_f)", !"air.center", !"air.perspective", !"air.arg_type_name", !"float2", !"air.arg_name", !"coord"}
!7 = !{i32 2, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample", !"air.arg_type_name", !"depth2d<float, sample>", !"air.arg_name", !"shadowMap"}
!8 = !{i32 3, !"air.sampler", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"comparer"}
!9 = !{i32 4, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float", !"air.arg_name", !"reference"}

target triple = "air64-apple-ios12.0.0"

define <4 x float> @quadFragment(<4 x float> %0, <2 x float> %1, ptr addrspace(1) %2, ptr addrspace(2) %3, ptr addrspace(2) readonly "air-buffer-no-alias" %4) {
  %6 = tail call <4 x float> @air.sample_texture_2d.v4f32(ptr addrspace(1) %2, ptr addrspace(2) %3, <2 x float> %1, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.000000e+00, i32 0)
  %7 = load <4 x float>, ptr addrspace(2) %4, align 16
  %8 = fmul fast <4 x float> %6, %7
  %9 = shufflevector <4 x float> %8, <4 x float> undef, <4 x i32> <i32 2, i32 1, i32 0, i32 3>
  %10 = extractelement <4 x float> %8, i64 3
  %11 = fcmp olt float %10, 5.000000e-01
  %12 = select i1 %11, <4 x float> %8, <4 x float> %9
  ret <4 x float> %12
}

declare <4 x float> @air.sample_texture_2d.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x float>, i1, <2 x i32>, i1, float, i32)

!air.version = !{!0}
!air.fragment = !{!17}

!0 = !{i32 2, i32 1, i32 0}
!17 = !{ptr @quadFragment, !18, !20}
!18 = !{!19}
!19 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!20 = !{!21, !22, !23, !24, !25}
!21 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!22 = !{i32 1, !"air.fragment_input", !"generated(5coordDv2_f)", !"air.center", !"air.perspective", !"air.arg_type_name", !"float2", !"air.arg_name", !"coord"}
!23 = !{i32 2, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"picture"}
!24 = !{i32 3, !"air.sampler", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"picker"}
!25 = !{i32 4, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"tint"}

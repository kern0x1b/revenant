target triple = "air64-apple-ios12.0.0"

define <{ <4 x float>, <4 x float> }> @pairFragment(<4 x float> %0, ptr addrspace(2) readonly "air-buffer-no-alias" %1) {
  %tint = load <4 x float>, ptr addrspace(2) %1, align 16
  %half = fmul fast <4 x float> %tint, <float 5.000000e-01, float 5.000000e-01, float 5.000000e-01, float 5.000000e-01>
  %first = insertvalue <{ <4 x float>, <4 x float> }> undef, <4 x float> %tint, 0
  %both = insertvalue <{ <4 x float>, <4 x float> }> %first, <4 x float> %half, 1
  ret <{ <4 x float>, <4 x float> }> %both
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @pairFragment, !2, !5}
!2 = !{!3, !4}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!"air.render_target", i32 1, i32 0, !"air.arg_type_name", !"float4"}
!5 = !{!6, !7}
!6 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!7 = !{i32 1, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"tint"}

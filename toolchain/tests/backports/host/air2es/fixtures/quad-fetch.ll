target triple = "air64-apple-ios12.0.0"

define <4 x float> @fetchFragment(<4 x float> %0, <4 x float> %1, ptr addrspace(2) readonly "air-buffer-no-alias" %2) {
  %4 = load <4 x float>, ptr addrspace(2) %2, align 16
  %5 = fmul fast <4 x float> %1, <float 5.000000e-01, float 5.000000e-01, float 5.000000e-01, float 5.000000e-01>
  %6 = fmul fast <4 x float> %4, <float 5.000000e-01, float 5.000000e-01, float 5.000000e-01, float 5.000000e-01>
  %7 = fadd fast <4 x float> %5, %6
  ret <4 x float> %7
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @fetchFragment, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5, !6, !7}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!6 = !{i32 1, !"air.render_target", i32 0, !"air.arg_type_name", !"float4", !"air.arg_name", !"previous"}
!7 = !{i32 2, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"tint"}

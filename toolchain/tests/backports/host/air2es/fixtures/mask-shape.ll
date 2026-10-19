target triple = "air64-apple-ios12.0.0"

define <4 x float> @maskShape(<4 x float> %0, <4 x float> %1) {
  %next = fadd fast <4 x float> %1, <float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>
  ret <4 x float> %next
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @maskShape, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 1, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5, !6}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!6 = !{i32 1, !"air.render_target", i32 1, !"air.arg_type_name", !"float4", !"air.arg_name", !"mask"}

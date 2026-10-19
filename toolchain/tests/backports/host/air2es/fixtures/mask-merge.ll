target triple = "air64-apple-ios12.0.0"

define <4 x float> @maskMerge(<4 x float> %0, <4 x float> %1) {
  %r = extractelement <4 x float> %1, i64 0
  %a = insertelement <4 x float> <float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00>, float %r, i64 0
  ret <4 x float> %a
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @maskMerge, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5, !6}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!6 = !{i32 1, !"air.render_target", i32 1, !"air.arg_type_name", !"float4", !"air.arg_name", !"mask"}

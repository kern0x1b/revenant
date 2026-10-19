target triple = "air64-apple-ios12.0.0"

define <{ <4 x float>, <4 x float> }> @fetchPairFragment(<4 x float> %0, <4 x float> %1) {
  %3 = insertvalue <{ <4 x float>, <4 x float> }> undef, <4 x float> %1, 0
  %4 = insertvalue <{ <4 x float>, <4 x float> }> %3, <4 x float> %0, 1
  ret <{ <4 x float>, <4 x float> }> %4
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @fetchPairFragment, !2, !5}
!2 = !{!3, !4}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!"air.render_target", i32 1, i32 0, !"air.arg_type_name", !"float4"}
!5 = !{!6, !7}
!6 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!7 = !{i32 1, !"air.render_target", i32 0, !"air.arg_type_name", !"float4", !"air.arg_name", !"previous"}

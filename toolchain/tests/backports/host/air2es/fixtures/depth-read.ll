target triple = "air64-apple-ios12.0.0"

define <4 x float> @depthRead(<4 x float> %0, <2 x float> %1, ptr addrspace(1) %2, ptr addrspace(2) %3) {
  %sampled = call { float, i8 } @air.sample_depth_2d.f32(ptr addrspace(1) %2, ptr addrspace(2) %3, i32 1, <2 x float> %1, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.000000e+00, float 0.000000e+00, i32 0)
  %depth = extractvalue { float, i8 } %sampled, 0
  %c0 = insertelement <4 x float> undef, float %depth, i64 0
  %c1 = insertelement <4 x float> %c0, float %depth, i64 1
  %c2 = insertelement <4 x float> %c1, float %depth, i64 2
  %c3 = insertelement <4 x float> %c2, float 1.000000e+00, i64 3
  ret <4 x float> %c3
}

declare { float, i8 } @air.sample_depth_2d.f32(ptr addrspace(1), ptr addrspace(2), i32, <2 x float>, i1, <2 x i32>, i1, float, float, i32)

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @depthRead, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5, !6, !7, !8}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!6 = !{i32 1, !"air.fragment_input", !"generated(5coordDv2_f)", !"air.center", !"air.perspective", !"air.arg_type_name", !"float2", !"air.arg_name", !"coord"}
!7 = !{i32 2, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample", !"air.arg_type_name", !"depth2d<float, sample>", !"air.arg_name", !"depthMap"}
!8 = !{i32 3, !"air.sampler", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"picker"}

target triple = "air64-apple-ios12.0.0"

define <{ <4 x float>, <4 x float> }> @depthVertex(i32 %0, ptr addrspace(2) readonly "air-buffer-no-alias" %1, ptr addrspace(2) readonly "air-buffer-no-alias" %2) {
  %4 = zext i32 %0 to i64
  %5 = getelementptr inbounds <4 x float>, ptr addrspace(2) %1, i64 %4
  %6 = load <4 x float>, ptr addrspace(2) %5, align 16
  %7 = getelementptr inbounds <4 x float>, ptr addrspace(2) %2, i64 %4
  %8 = load <4 x float>, ptr addrspace(2) %7, align 16
  %9 = insertvalue <{ <4 x float>, <4 x float> }> undef, <4 x float> %6, 0
  %10 = insertvalue <{ <4 x float>, <4 x float> }> %9, <4 x float> %8, 1
  ret <{ <4 x float>, <4 x float> }> %10
}

!air.version = !{!0}
!air.vertex = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @depthVertex, !2, !5}
!2 = !{!3, !4}
!3 = !{!"air.position", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!4 = !{!"air.vertex_output", !"generated(5shadeDv4_f)", !"air.arg_type_name", !"float4", !"air.arg_name", !"shade"}
!5 = !{!6, !7, !8}
!6 = !{i32 0, !"air.vertex_id", !"air.arg_type_name", !"uint", !"air.arg_name", !"vertexID"}
!7 = !{i32 1, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"positions"}
!8 = !{i32 2, !"air.buffer", !"air.location_index", i32 1, i32 1, !"air.read", !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"colors"}

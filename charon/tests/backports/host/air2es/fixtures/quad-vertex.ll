target triple = "air64-apple-ios12.0.0"

%struct.Corner = type { <2 x float>, <2 x float> }

define <{ <4 x float>, <2 x float> }> @quadVertex(i32 %0, ptr addrspace(2) readonly "air-buffer-no-alias" %1, ptr addrspace(2) readonly "air-buffer-no-alias" %2) {
  %4 = zext i32 %0 to i64
  %5 = getelementptr inbounds %struct.Corner, ptr addrspace(2) %1, i64 %4, i32 0
  %6 = load <2 x float>, ptr addrspace(2) %5, align 8
  %7 = load float, ptr addrspace(2) %2, align 4
  %8 = extractelement <2 x float> %6, i64 0
  %9 = extractelement <2 x float> %6, i64 1
  %10 = fmul fast float %8, %7
  %11 = fmul fast float %9, %7
  %12 = insertelement <4 x float> undef, float %10, i64 0
  %13 = insertelement <4 x float> %12, float %11, i64 1
  %14 = insertelement <4 x float> %13, float 0.000000e+00, i64 2
  %15 = insertelement <4 x float> %14, float 1.000000e+00, i64 3
  %16 = getelementptr inbounds %struct.Corner, ptr addrspace(2) %1, i64 %4, i32 1
  %17 = load <2 x float>, ptr addrspace(2) %16, align 8
  %18 = insertvalue <{ <4 x float>, <2 x float> }> undef, <4 x float> %15, 0
  %19 = insertvalue <{ <4 x float>, <2 x float> }> %18, <2 x float> %17, 1
  ret <{ <4 x float>, <2 x float> }> %19
}

!air.version = !{!0}
!air.language_version = !{!1}
!air.vertex = !{!2}
!0 = !{i32 2, i32 1, i32 0}
!1 = !{!"Metal", i32 2, i32 1, i32 0}
!2 = !{ptr @quadVertex, !3, !6}
!3 = !{!4, !5}
!4 = !{!"air.position", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!5 = !{!"air.vertex_output", !"generated(5coordDv2_f)", !"air.arg_type_name", !"float2", !"air.arg_name", !"coord"}
!6 = !{!7, !8, !9}
!7 = !{i32 0, !"air.vertex_id", !"air.arg_type_name", !"uint", !"air.arg_name", !"vertexID"}
!8 = !{i32 1, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"Corner", !"air.arg_name", !"corners"}
!9 = !{i32 2, !"air.buffer", !"air.location_index", i32 1, i32 1, !"air.read", !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float", !"air.arg_name", !"scale"}

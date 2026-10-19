target triple = "air64-apple-ios12.0.0"

define <{ <4 x float>, <2 x float>, <4 x float> }> @stageInVertex(<2 x float> %0, <2 x float> %1, <4 x float> %2, i32 %3, ptr addrspace(2) readonly "air-buffer-no-alias" %4) {
  %6 = load float, ptr addrspace(2) %4, align 4
  %7 = extractelement <2 x float> %0, i64 0
  %8 = extractelement <2 x float> %0, i64 1
  %9 = fmul fast float %7, %6
  %10 = fmul fast float %8, %6
  %11 = insertelement <4 x float> undef, float %9, i64 0
  %12 = insertelement <4 x float> %11, float %10, i64 1
  %13 = insertelement <4 x float> %12, float 0.000000e+00, i64 2
  %14 = insertelement <4 x float> %13, float 1.000000e+00, i64 3
  %15 = sitofp i32 %3 to float
  %16 = fmul fast float %15, 5.000000e-01
  %17 = extractelement <2 x float> %1, i64 0
  %18 = fadd fast float %17, %16
  %19 = insertelement <2 x float> %1, float %18, i64 0
  %20 = insertvalue <{ <4 x float>, <2 x float>, <4 x float> }> undef, <4 x float> %14, 0
  %21 = insertvalue <{ <4 x float>, <2 x float>, <4 x float> }> %20, <2 x float> %19, 1
  %22 = insertvalue <{ <4 x float>, <2 x float>, <4 x float> }> %21, <4 x float> %2, 2
  ret <{ <4 x float>, <2 x float>, <4 x float> }> %22
}

!air.version = !{!0}
!air.vertex = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @stageInVertex, !2, !6}
!2 = !{!3, !4, !5}
!3 = !{!"air.position", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!4 = !{!"air.vertex_output", !"generated(5coordDv2_f)", !"air.arg_type_name", !"float2", !"air.arg_name", !"coord"}
!5 = !{!"air.vertex_output", !"generated(5shadeDv4_f)", !"air.arg_type_name", !"float4", !"air.arg_name", !"shade"}
!6 = !{!7, !8, !9, !10, !11}
!7 = !{i32 0, !"air.vertex_input", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"float2", !"air.arg_name", !"position"}
!8 = !{i32 1, !"air.vertex_input", !"air.location_index", i32 1, i32 1, !"air.arg_type_name", !"float2", !"air.arg_name", !"coord"}
!9 = !{i32 2, !"air.vertex_input", !"air.location_index", i32 2, i32 1, !"air.arg_type_name", !"float4", !"air.arg_name", !"shade"}
!10 = !{i32 3, !"air.instance_id", !"air.arg_type_name", !"uint", !"air.arg_name", !"instance"}
!11 = !{i32 4, !"air.buffer", !"air.location_index", i32 1, i32 1, !"air.read", !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float", !"air.arg_name", !"scale"}

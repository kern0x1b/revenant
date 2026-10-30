define void @k_ult(ptr addrspace(1) %out, <2 x i32> %gid) {
entry:
  %g = extractelement <2 x i32> %gid, i64 0
  %h = extractelement <2 x i32> %gid, i64 1
  %c = icmp ult i32 %g, %h
  br i1 %c, label %write, label %join
write:
  tail call void @air.write_texture_2d.v4f32(ptr addrspace(1) %out, <2 x i32> %gid, <4 x float> <float 1.0, float 0.5, float 0.25, float 1.0>, i32 0, i32 2)
  br label %join
join:
  ret void
}
declare void @air.write_texture_2d.v4f32(ptr addrspace(1), <2 x i32>, <4 x float>, i32, i32)
!air.kernel = !{!8}
!8 = !{ptr @k_ult, !9, !10}
!9 = !{}
!10 = !{!11, !12}
!11 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.write", !"air.arg_type_name", !"texture2d<float, write>", !"air.arg_name", !"out"}
!12 = !{i32 1, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint2", !"air.arg_name", !"gid"}

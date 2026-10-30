define void @k_local(ptr addrspace(1) %out, <2 x i32> %gid) {
entry:
  %v = alloca <4 x float>, align 16
  store <4 x float> zeroinitializer, ptr %v, align 16
  %g = extractelement <2 x i32> %gid, i64 0
  %c = icmp eq i32 %g, 0
  br i1 %c, label %write, label %join
write:
  store <4 x float> <float 1.0, float 0.5, float 0.25, float 1.0>, ptr %v, align 16
  br label %join
join:
  %r = load <4 x float>, ptr %v, align 16
  tail call void @air.write_texture_2d.v4f32(ptr addrspace(1) %out, <2 x i32> %gid, <4 x float> %r, i32 0, i32 2)
  ret void
}
declare void @air.write_texture_2d.v4f32(ptr addrspace(1), <2 x i32>, <4 x float>, i32, i32)
!air.kernel = !{!8}
!8 = !{ptr @k_local, !9, !10}
!9 = !{}
!10 = !{!11, !12}
!11 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.write", !"air.arg_type_name", !"texture2d<float, write>", !"air.arg_name", !"out"}
!12 = !{i32 1, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint2", !"air.arg_name", !"gid"}

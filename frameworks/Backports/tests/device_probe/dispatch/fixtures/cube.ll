define void @k_cube(ptr addrspace(1) %out, ptr addrspace(1) %cube, ptr addrspace(2) %smp, <2 x i32> %gid) {
entry:
  %c = tail call <4 x float> @air.sample_texture_cube.v4f32(ptr addrspace(1) %cube, ptr addrspace(2) %smp, <3 x float> <float 0.0, float 1.0, float 0.0>, i32 0, float 0.0, i32 0)
  tail call void @air.write_texture_2d.v4f32(ptr addrspace(1) %out, <2 x i32> %gid, <4 x float> %c, i32 0, i32 2)
  ret void
}
declare <4 x float> @air.sample_texture_cube.v4f32(ptr addrspace(1), ptr addrspace(2), <3 x float>, i32, float, i32)
declare void @air.write_texture_2d.v4f32(ptr addrspace(1), <2 x i32>, <4 x float>, i32, i32)
!air.kernel = !{!8}
!8 = !{ptr @k_cube, !9, !10}
!9 = !{}
!10 = !{!11, !12, !13, !14}
!11 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.write", !"air.arg_type_name", !"texture2d<float, write>", !"air.arg_name", !"out"}
!12 = !{i32 1, !"air.texture", !"air.location_index", i32 1, i32 1, !"air.sample", !"air.arg_type_name", !"texturecube<float, sample>", !"air.arg_name", !"cubemap"}
!13 = !{i32 2, !"air.sampler", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"smp"}
!14 = !{i32 3, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint2", !"air.arg_name", !"gid"}

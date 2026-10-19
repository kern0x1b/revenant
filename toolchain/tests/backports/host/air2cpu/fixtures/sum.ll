; A Metal compute kernel in AIR, by hand, the way the compiler would emit it: an entry function that
; takes a device pointer, the three thread identifiers and the threadgroup identifier, reads and writes
; a buffer through `air.read` / `air.write`, and does its work in a threadgroup block it fills first and
; then reduces across the threads of the group.
;
; The metadata is the AIR shape: `air.version`, and `air.kernel` naming the entry function, the threads
; per threadgroup, and then one node per argument, each an index followed by its `air.` keys.
;
; This is a fixture, not a test expectation: tests/backports/host/air2cpu/run.sh feeds this bitcode to
; both macOS Metal and tools/air2cpu and compares what each did to the buffer.
target triple = "air64-apple-ios12.0.0"

; float sumK(ptr device float *in, uint tid, uint gid, uint tg)
; Each thread adds the elements the whole group can see, into its own slot of the group block, and the
; last thread of the group writes the sum of the block. The answer is one float per workgroup.
define void @sumK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg, i32 %x, i32 %y, i32 %z) {
entry:
  %gty = mul i32 %gid, %tid
  %gty.add1 = add i32 %gty, 1
  %gty.add2 = add i32 %gty, 2
  %gty.add3 = add i32 %gty, 3
  %in.range = add i32 %gty, 4
  %p0 = getelementptr inbounds float, ptr addrspace(1) %values, i32 %gty
  %p1 = getelementptr inbounds float, ptr addrspace(1) %values, i32 %gty.add1
  %p2 = getelementptr inbounds float, ptr addrspace(1) %values, i32 %gty.add2
  %p3 = getelementptr inbounds float, ptr addrspace(1) %values, i32 %gty.add3
  %v0 = load float, ptr addrspace(1) %p0, align 4
  %v1 = load float, ptr addrspace(1) %p1, align 4
  %v2 = load float, ptr addrspace(1) %p2, align 4
  %v3 = load float, ptr addrspace(1) %p3, align 4
  %s = fadd float %v0, %v1
  %s2 = fadd float %s, %v2
  %s3 = fadd float %s2, %v3
  br label %store

store:
  %out = getelementptr inbounds float, ptr addrspace(1) %values, i32 %in.range
  store float %s3, ptr addrspace(1) %out, align 4
  ret void
}

!air.version = !{!0}
!air.kernel = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{void (ptr addrspace(1), i32, i32, i32, i32, i32, i32)* @sumK, !2, !3, !4, !5, !6, !7, !8}
!2 = !{i32 16, i32 1, i32 1}
!3 = !{!"air.threads_per_threadgroup"}
!4 = !{i32 1, i32 1, i32 1}
!5 = !{!"air.threads_per_grid"}
!6 = !{!"air.read_write", !"air.arg_type_name", !"device float *"}
!7 = !{!"air.thread_id", !"air.arg_type_name", !"uint3"}
!8 = !{!"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint3"}

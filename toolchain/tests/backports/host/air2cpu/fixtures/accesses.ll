; Three kernels in the REAL argument-node shape, invented for this repository and not Apple's, so
; the access keys are exercised where they actually appear.
;
; A real argument node opens with its TYPE CLASS as a bare key - !"air.buffer" - and its access is
; bare too, in the middle of the key stream with no value of its own. fixtures/reflect.ll is in the
; OLDER shape, where the access is the node's first operand, and a writer that read only that
; operand passed reflect.ll and read NO access from a real library at all. This fixture is the one
; that catches that: each kernel carries a different one of the three access keys MEASURED across 25
; real libraries - air.read, air.write and air.read_write - and the fourth kernel carries none, so
; the "write no access when the metadata says none" half is exercised too.
;
; The kernel bodies are the operations sum.ll already uses. The four scalars convention note: each
; kernel takes a device pointer and the three thread identifiers, which is the shape air2cpu
; translates.
target triple = "air64-apple-ios12.0.0"

define void @readK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %v = load float, ptr addrspace(1) %at, align 4
  %one = fadd float %v, %v
  store float %one, ptr addrspace(1) %at, align 4
  ret void
}

define void @writeK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %v = load float, ptr addrspace(1) %at, align 4
  %one = fadd float %v, %v
  store float %one, ptr addrspace(1) %at, align 4
  ret void
}

define void @bothK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %v = load float, ptr addrspace(1) %at, align 4
  %one = fadd float %v, %v
  store float %one, ptr addrspace(1) %at, align 4
  ret void
}

define void @plainK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %v = load float, ptr addrspace(1) %at, align 4
  %one = fadd float %v, %v
  store float %one, ptr addrspace(1) %at, align 4
  ret void
}

!air.version = !{!0}
!air.kernel = !{!1, !2, !3, !4}

!0 = !{i32 2, i32 1, i32 0}

; the REAL shape: a function, an empty node, then ONE node nesting every argument node
!1 = !{ptr @readK, !5, !6}
!2 = !{ptr @writeK, !7, !8}
!3 = !{ptr @bothK, !9, !10}
!4 = !{ptr @plainK, !11, !12}

!5 = !{}
!7 = !{}
!9 = !{}
!11 = !{}

!6 = !{!13, !14, !15}
!8 = !{!16, !17, !18}
!10 = !{!19, !20, !21}
!12 = !{!22, !23, !24}

; air.read, BARE, in the middle of the stream, after the type class
!13 = !{i32 0, !"air.buffer", !"air.read", !"air.address_space", i32 1, !"air.arg_type_size", i64 4, !"air.arg_type_align_size", i64 4, !"air.arg_type_name", !"device float *", !"air.arg_name", !"values"}
!14 = !{i32 1, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"tid"}
!15 = !{i32 2, !"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"gid"}

!16 = !{i32 0, !"air.buffer", !"air.write", !"air.address_space", i32 1, !"air.arg_type_size", i64 4, !"air.arg_type_align_size", i64 4, !"air.arg_type_name", !"device float *", !"air.arg_name", !"values"}
!17 = !{i32 1, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"tid"}
!18 = !{i32 2, !"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"gid"}

!19 = !{i32 0, !"air.buffer", !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i64 4, !"air.arg_type_align_size", i64 4, !"air.arg_type_name", !"device float *", !"air.arg_name", !"values"}
!20 = !{i32 1, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"tid"}
!21 = !{i32 2, !"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"gid"}

; NO access key at all: the writer must write no access for this one, and never read-write
!22 = !{i32 0, !"air.buffer", !"air.address_space", i32 1, !"air.arg_type_size", i64 4, !"air.arg_type_align_size", i64 4, !"air.arg_type_name", !"device float *", !"air.arg_name", !"values"}
!23 = !{i32 1, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"tid"}
!24 = !{i32 2, !"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"gid"}

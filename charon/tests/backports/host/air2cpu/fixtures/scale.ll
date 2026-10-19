; A Metal compute kernel in AIR, by hand - invented for this repository, not Apple's, and not a
; test expectation. It exists because the one committed fixture (sum.ll) is a kernel air2cpu
; REFUSES: its entry takes six scalars where the call convention carries three, so the tool exits
; before it writes anything and the type tree beside the translation could never be read.
;
; The signature is the one the convention carries, which is what the refusal names: a device pointer,
; then the thread position, the threadgroup position and the group size - three scalars and no more.
; The work is one store per thread, with no reduction across the group, so the emitter has nothing to
; disagree about and the fixture is about the ARGSUMENT AND TYPE TREE rather than about the code.
;
; The metadata is the AIR shape, as sum.ll spells it: !air.version, and !air.kernel naming the entry
; function, the two threadgroup sizes, and then one node per argument, each its `air.` keys.
target triple = "air64-apple-ios12.0.0"

; void scaleK(ptr device float *in, uint tid, uint gid, uint tg)
; Each thread adds its neighbour's element into its own, so every thread's store is its own and the
; body is only the operations sum.ll already uses - getelementptr, load, add, fadd, store - because
; the fixture is about the ARGUMENT AND TYPE TREE and not about the emitter learning new arithmetic.
define void @scaleK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %next = add i32 %tid, 1
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %after = getelementptr inbounds float, ptr addrspace(1) %values, i32 %next
  %v = load float, ptr addrspace(1) %at, align 4
  %w = load float, ptr addrspace(1) %after, align 4
  %s = fadd float %v, %w
  store float %s, ptr addrspace(1) %at, align 4
  ret void
}

!air.version = !{!0}
!air.kernel = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{void (ptr addrspace(1), i32, i32, i32)* @scaleK, !2, !3, !4, !5, !6, !7}
!2 = !{i32 16, i32 1, i32 1}
!3 = !{!"air.threads_per_threadgroup"}
!4 = !{i32 1, i32 1, i32 1}
!5 = !{!"air.threads_per_grid"}
!6 = !{!"air.read_write", !"air.arg_type_name", !"device float *"}
!7 = !{!"air.thread_id", !"air.arg_type_name", !"uint3"}

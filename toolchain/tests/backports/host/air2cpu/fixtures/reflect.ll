; A module with two entry points, invented for this repository like scale.ll and not Apple's.
;
; It exists to exercise the arms of the type tree that scale.ll does not reach: a VECTOR argument, and
; what the AIR can and cannot say about the element type of a device buffer. Two kernels, because the
; two things need opposite answers from the translator:
;
;   reflectK is the ordinary one - a device pointer and the three scalars - and it TRANSLATES. Its
;   presence is what lets the module produce any output at all: air2cpu writes the C only when some
;   kernel translated, and writes the plist only after that.
;
;   vecK takes a float4 BY VALUE. The translator refuses it - typeOf() names scalars and pointers and
;   refuses a vector, an array or a struct - but the type tree is written from the module's entry
;   points rather than from the ones that translated, so its vector argument is still described. That
;   is the honest arrangement: the plist says what a kernel's arguments ARE, and the C beside it says
;   which kernels the port can run, and the two are not the same list.
;
; What this fixture also shows, and what no fixture can work around: the element type of a DEVICE
; BUFFER is not in the AIR's type system. LLVM has used opaque pointers since 15, so `ptr
; addrspace(1)` carries no pointee at all - the "device float *" of a Metal signature lives in the
; `air.arg_type_name` METADATA as a string, and air2cpu never reads that metadata. So a buffer's
; element type cannot be walked, and MTLPointerType's pointee is MTLUnknown on this port. That is a
; property of the data, not a gap in the writer.
target triple = "air64-apple-ios12.0.0"

; float reflectK(ptr device float *values, uint tid, uint gid, uint tg)
define void @reflectK(ptr addrspace(1) %values, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %v = load float, ptr addrspace(1) %at, align 4
  %next = add i32 %tid, 1
  %after = getelementptr inbounds float, ptr addrspace(1) %values, i32 %next
  %w = load float, ptr addrspace(1) %after, align 4
  %s = fadd float %v, %w
  store float %s, ptr addrspace(1) %at, align 4
  ret void
}

; float vecK(ptr device float *values, float4 tint, uint tid, uint gid, uint tg)
; The float4 is a vector BY VALUE, which is the one shape the AIR's type system still carries whole
; and the one the translator refuses.
define void @vecK(ptr addrspace(1) %values, <4 x float> %tint, i32 %tid, i32 %gid, i32 %tg) {
entry:
  %at = getelementptr inbounds float, ptr addrspace(1) %values, i32 %tid
  %v = load float, ptr addrspace(1) %at, align 4
  %e0 = extractelement <4 x float> %tint, i32 0
  %s = fadd float %v, %e0
  store float %s, ptr addrspace(1) %at, align 4
  ret void
}

!air.version = !{!0}
!air.kernel = !{!1, !10}
!air.kernel = !{!2, !11}

!0 = !{i32 2, i32 1, i32 0}

!1 = !{void (ptr addrspace(1), i32, i32, i32)* @reflectK, !3, !4, !5, !6, !7}
!2 = !{void (ptr addrspace(1), <4 x float>, i32, i32, i32)* @vecK, !8, !9, !12, !13, !14, !15}

!3 = !{i32 16, i32 1, i32 1}
!4 = !{!"air.threads_per_threadgroup"}
!5 = !{i32 1, i32 1, i32 1}
!6 = !{!"air.threads_per_grid"}
!7 = !{!"air.read_write", !"air.arg_type_name", !"device float *", !"air.arg_type_size", i64 4,
      !"air.arg_type_align_size", i64 4}

!8 = !{i32 16, i32 1, i32 1}
!9 = !{!"air.threads_per_threadgroup"}
!10 = !{i32 1, i32 1, i32 1}
!11 = !{!"air.threads_per_grid"}
!12 = !{!"air.read_write", !"air.arg_type_name", !"device float *", !"air.arg_type_size", i64 16,
       !"air.arg_type_align_size", i64 4, !"air.struct_type_info", !16}
!13 = !{!"air.read_only", !"air.arg_type_name", !"float4"}
!14 = !{!"air.thread_id", !"air.arg_type_name", !"uint3"}
!15 = !{!"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint3"}

; The members of the struct reflectK's buffer carries, as air.struct_type_info spells them: a flat
; list of name, offset, type, three at a time. The values are INVENTED for this fixture and are not
; Apple's: no Apple AIR was read to make them, because the host's Metal compiler service crash-loops
; and a real library could not be produced here. What is exercised is the SHAPE - that the writer
; finds a nested node where a string was and walks it - and the shape is what the reader depends on.
!16 = !{!"position", i64 0, !"float3", !"velocity", i64 12, !"float3"}

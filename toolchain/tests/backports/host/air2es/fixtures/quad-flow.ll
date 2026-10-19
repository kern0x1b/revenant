target triple = "air64-apple-ios12.0.0"

define <4 x float> @flowFragment(<4 x float> %0, ptr addrspace(2) readonly "air-buffer-no-alias" %1) {
entry:
  %n = load i32, ptr addrspace(2) %1, align 4
  %p = getelementptr inbounds i8, ptr addrspace(2) %1, i64 4
  %k = load float, ptr addrspace(2) %p, align 4
  br label %loop

loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %acc = phi float [ 0.000000e+00, %entry ], [ %acc.next, %loop ]
  %acc.next = fadd float %acc, %k
  %i.next = add i32 %i, 1
  %again = icmp slt i32 %i.next, %n
  br i1 %again, label %loop, label %exit

exit:
  %big = fcmp ogt float %acc.next, 2.500000e+00
  br i1 %big, label %large, label %small

large:
  %a = fmul float %acc.next, 5.000000e-02
  br label %done

small:
  %b = fmul float %acc.next, 2.000000e-01
  br label %done

done:
  %v = phi float [ %a, %large ], [ %b, %small ]
  %c0 = insertelement <4 x float> undef, float %v, i64 0
  %c1 = insertelement <4 x float> %c0, float %v, i64 1
  %c2 = insertelement <4 x float> %c1, float %v, i64 2
  %c3 = insertelement <4 x float> %c2, float 1.000000e+00, i64 3
  ret <4 x float> %c3
}

!air.version = !{!0}
!air.fragment = !{!1}

!0 = !{i32 2, i32 1, i32 0}
!1 = !{ptr @flowFragment, !2, !4}
!2 = !{!3}
!3 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!4 = !{!5, !6}
!5 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!6 = !{i32 1, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_size", i32 8, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"Loop", !"air.arg_name", !"loop"}

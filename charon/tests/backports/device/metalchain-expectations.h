/* metalchain-expectations.h - what Apple's own Metal answers, measured on this host and written down by
 * tests/backports/host/metal-census/chain-oracle.sh and chain-commit.sh, whose captured output is
 * tests/backports/host/metal-census/chain-expectations.txt.
 *
 * NOTHING HERE IS THE PORT'S ANSWER. Every value is Apple's, read off Apple's own objects:
 *
 *     MTLDevice.h:1240          -[MTLDevice newCommandAllocator]
 *     MTLDevice.h:1271          -[MTLDevice newMTL4CommandQueueWithDescriptor:error:]
 *     MTLDevice.h:1278          -[MTLDevice newCommandBuffer]
 *     MTL4CommandBuffer.h:71    -[MTL4CommandBuffer beginCommandBufferWithAllocator:]
 *     MTL4CommandBuffer.h:103   -[MTL4CommandBuffer endCommandBuffer]
 *     MTL4CommandQueue.h:231    -[MTL4CommandQueue commit:count:]   (a C ARRAY of buffers)
 *
 * tests/backports/device/metalchain.m holds the port to these. The device is where that comparison has
 * to happen: the port's queue is an EAGL object over OpenGL ES 2.0, so no host case can build it - which
 * is why the oracle is a captured table and this header, and the check is on the device.
 */
#ifndef METALCHAIN_EXPECTATIONS_H
#define METALCHAIN_EXPECTATIONS_H

/* A FRESH QUEUE'S LABEL IS nil - the descriptor's label is taken at the factory and nothing else is. */
static const int metalchain_queue_label_is_nil = 1;

/* A FRESH QUEUE HAS A DEVICE, and it is the one the queue was made from. */
static const int metalchain_queue_has_device = 1;

/* AND Metal 4's descriptor factory answers with a queue and NO ERROR, given a real
 * MTL4CommandQueueDescriptor - measured, after an earlier probe blamed the wrong selector (Metal 3's
 * -newCommandQueueWithDescriptor:) for a refusal that was not there. */
static const int metalchain_queue_from_descriptor_has_no_error = 1;

/* Metal 4's command buffer has NEITHER -status NOR -commandQueue. Two absences, found because a
 * -valueForKey:@"status" raised NSUnknownKeyException and killed the probe. The port's buffer must not
 * grow either. */
static const int metalchain_buffer_has_no_status = 1;
static const int metalchain_buffer_has_no_command_queue = 1;

/* A FRESH BUFFER'S LABEL IS nil and it HAS a device, exactly as a fresh queue's does. */
static const int metalchain_buffer_label_is_nil = 1;
static const int metalchain_buffer_has_device = 1;

/* -beginCommandBufferWithAllocator: ANSWERS WITHOUT RAISING, on the buffer and with an allocator. */
static const int metalchain_begin_answers = 1;

/* THE COMPUTE ENCODER IS VENDED, its fresh label is nil, and its -commandBuffer ANSWERS THE VERY BUFFER
 * IT CAME FROM - identity within one side, which is what a caller relies on. */
static const int metalchain_compute_encoder_label_is_nil = 1;
static const int metalchain_compute_encoder_answers_its_buffer = 1;

/* AND THE RENDER ENCODER, FOR A PASS WITH NO ATTACHMENTS, ANSWERS nil AND NOT AN EXCEPTION. That is the
 * shape the port has to match: a pass with nothing to draw into has no encoder. */
static const int metalchain_render_encoder_nil_for_empty_pass = 1;

/* -commit:count: RETURNS - on the header's own path (begun, ended, committed) and on the un-ended one
 * alike - measured in a process EXECed on its own, because Metal is not fork-safe and a child forked
 * from a process holding Metal objects dies on a signal that says nothing about the commit. The port's
 * queue therefore commits rather than refusing, and this is the row that says so. */
static const int metalchain_commit_returns = 1;
static const int metalchain_commit_returns_when_not_ended = 1;

/* AND THERE IS NO QUEUE-LEVEL WAIT FOR COMMAND BUFFERS: Metal 4's queue has no
 * -waitForCommandBuffers:, and MTL4CommandQueue.h agrees - its only waits are -waitForEvent:value: (:274)
 * and -waitForDrawable: (:308). The port's queue must not grow one. */
static const int metalchain_queue_has_no_wait_for_command_buffers = 1;

#endif

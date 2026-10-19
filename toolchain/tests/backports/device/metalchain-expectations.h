#ifndef METALCHAIN_EXPECTATIONS_H
#define METALCHAIN_EXPECTATIONS_H

static const int metalchain_queue_label_is_nil = 1;

static const int metalchain_queue_has_device = 1;

static const int metalchain_queue_from_descriptor_has_no_error = 1;

static const int metalchain_buffer_has_no_status = 1;
static const int metalchain_buffer_has_no_command_queue = 1;

static const int metalchain_buffer_label_is_nil = 1;
static const int metalchain_buffer_has_device = 1;

static const int metalchain_begin_answers = 1;

static const int metalchain_compute_encoder_label_is_nil = 1;
static const int metalchain_compute_encoder_answers_its_buffer = 1;

static const int metalchain_render_encoder_nil_for_empty_pass = 1;

static const int metalchain_commit_returns = 1;
static const int metalchain_commit_returns_when_not_ended = 1;

static const int metalchain_queue_has_no_wait_for_command_buffers = 1;

#endif

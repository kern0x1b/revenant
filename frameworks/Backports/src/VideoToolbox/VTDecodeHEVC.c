#include "VTDecodeHEVC.h"

#include <libavcodec/avcodec.h>
#include <libavutil/error.h>
#include <libavutil/pixfmt.h>
#include <stdlib.h>
#include <string.h>

struct RevenantVTHEVCDecoder {
    AVCodecContext *context;
    AVPacket *packet;
    AVFrame *frame;
};

static RevenantVTHEVCResult RevenantVTHEVCClassify(int error)
{
    if (error == AVERROR_INVALIDDATA)
        return RevenantVTHEVCBadData;
    if (error == AVERROR_PATCHWELCOME)
        return RevenantVTHEVCUnsupportedFormat;
    if (error == AVERROR(ENOMEM))
        return RevenantVTHEVCOutOfMemory;
    return RevenantVTHEVCMalfunction;
}

static RevenantVTHEVCMatrix RevenantVTHEVCMatrixOf(enum AVColorSpace space)
{
    switch (space) {
    case AVCOL_SPC_BT709:
        return RevenantVTHEVCMatrixBT709;
    case AVCOL_SPC_BT470BG:
    case AVCOL_SPC_SMPTE170M:
        return RevenantVTHEVCMatrixBT601;
    default:
        return RevenantVTHEVCMatrixUnspecified;
    }
}

static RevenantVTHEVCResult RevenantVTHEVCEmit(RevenantVTHEVCDecoder *decoder, RevenantVTHEVCSink sink, void *context)
{
    const AVFrame *frame = decoder->frame;
    if (frame->format != AV_PIX_FMT_YUV420P)
        return RevenantVTHEVCUnsupportedFormat;
    RevenantVTHEVCPicture picture = {
        .sequence = frame->pts,
        .width = frame->width,
        .height = frame->height,
        .luma = frame->data[0],
        .lumaStride = (size_t)frame->linesize[0],
        .chromaBlue = frame->data[1],
        .chromaBlueStride = (size_t)frame->linesize[1],
        .chromaRed = frame->data[2],
        .chromaRedStride = (size_t)frame->linesize[2],
        .fullRange = frame->color_range == AVCOL_RANGE_JPEG,
        .matrix = RevenantVTHEVCMatrixOf(frame->colorspace),
    };
    sink(context, &picture);
    return RevenantVTHEVCOK;
}

static RevenantVTHEVCResult RevenantVTHEVCDrain(RevenantVTHEVCDecoder *decoder, RevenantVTHEVCSink sink, void *context)
{
    for (;;) {
        const int received = avcodec_receive_frame(decoder->context, decoder->frame);
        if (received == AVERROR(EAGAIN) || received == AVERROR_EOF)
            return RevenantVTHEVCOK;
        if (received < 0)
            return RevenantVTHEVCClassify(received);
        const RevenantVTHEVCResult emitted = RevenantVTHEVCEmit(decoder, sink, context);
        av_frame_unref(decoder->frame);
        if (emitted != RevenantVTHEVCOK)
            return emitted;
    }
}

RevenantVTHEVCDecoder *RevenantVTHEVCDecoderCreate(const uint8_t *configuration, size_t size, int threads, RevenantVTHEVCResult *result)
{
    RevenantVTHEVCDecoder *decoder = calloc(1, sizeof(*decoder));
    if (!decoder) {
        *result = RevenantVTHEVCOutOfMemory;
        return NULL;
    }
    const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_HEVC);
    if (!codec) {
        *result = RevenantVTHEVCNoDecoder;
        RevenantVTHEVCDecoderDestroy(decoder);
        return NULL;
    }
    decoder->context = avcodec_alloc_context3(codec);
    if (!decoder->context) {
        *result = RevenantVTHEVCOutOfMemory;
        RevenantVTHEVCDecoderDestroy(decoder);
        return NULL;
    }
    decoder->context->extradata = av_mallocz(size + AV_INPUT_BUFFER_PADDING_SIZE);
    if (!decoder->context->extradata) {
        *result = RevenantVTHEVCOutOfMemory;
        RevenantVTHEVCDecoderDestroy(decoder);
        return NULL;
    }
    memcpy(decoder->context->extradata, configuration, size);
    decoder->context->extradata_size = (int)size;
    decoder->context->thread_count = threads;
    const int opened = avcodec_open2(decoder->context, codec, NULL);
    if (opened < 0) {
        *result = RevenantVTHEVCClassify(opened);
        RevenantVTHEVCDecoderDestroy(decoder);
        return NULL;
    }
    decoder->packet = av_packet_alloc();
    decoder->frame = av_frame_alloc();
    if (!decoder->packet || !decoder->frame) {
        *result = RevenantVTHEVCOutOfMemory;
        RevenantVTHEVCDecoderDestroy(decoder);
        return NULL;
    }
    *result = RevenantVTHEVCOK;
    return decoder;
}

RevenantVTHEVCResult RevenantVTHEVCDecoderDecode(RevenantVTHEVCDecoder *decoder, const uint8_t *data, size_t size, int64_t sequence, RevenantVTHEVCSink sink, void *context)
{
    AVPacket *packet = decoder->packet;
    av_packet_unref(packet);
    const int allocated = av_new_packet(packet, (int)size);
    if (allocated < 0)
        return RevenantVTHEVCClassify(allocated);
    memcpy(packet->data, data, size);
    packet->pts = sequence;
    packet->dts = AV_NOPTS_VALUE;
    int sent;
    for (;;) {
        sent = avcodec_send_packet(decoder->context, packet);
        if (sent != AVERROR(EAGAIN))
            break;
        const RevenantVTHEVCResult drained = RevenantVTHEVCDrain(decoder, sink, context);
        if (drained != RevenantVTHEVCOK) {
            av_packet_unref(packet);
            return drained;
        }
    }
    av_packet_unref(packet);
    if (sent < 0)
        return RevenantVTHEVCClassify(sent);
    return RevenantVTHEVCDrain(decoder, sink, context);
}

RevenantVTHEVCResult RevenantVTHEVCDecoderFinish(RevenantVTHEVCDecoder *decoder, RevenantVTHEVCSink sink, void *context)
{
    const int sent = avcodec_send_packet(decoder->context, NULL);
    if (sent < 0 && sent != AVERROR_EOF)
        return RevenantVTHEVCClassify(sent);
    for (;;) {
        const int received = avcodec_receive_frame(decoder->context, decoder->frame);
        if (received == AVERROR_EOF)
            break;
        if (received < 0)
            return RevenantVTHEVCClassify(received);
        const RevenantVTHEVCResult emitted = RevenantVTHEVCEmit(decoder, sink, context);
        av_frame_unref(decoder->frame);
        if (emitted != RevenantVTHEVCOK)
            return emitted;
    }
    avcodec_flush_buffers(decoder->context);
    return RevenantVTHEVCOK;
}

void RevenantVTHEVCDecoderDestroy(RevenantVTHEVCDecoder *decoder)
{
    if (!decoder)
        return;
    av_frame_free(&decoder->frame);
    av_packet_free(&decoder->packet);
    avcodec_free_context(&decoder->context);
    free(decoder);
}

package com.pomento.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer

/**
 * 오디오 파일을 16비트 PCM으로 풀어내는 디코더.
 *
 * 재생 엔진(SoLoud)이 내장한 디코더는 mp3, wav, ogg, flac뿐이라 m4a(AAC)를
 * 못 읽는다. 안드로이드의 MediaCodec은 AAC를 기본으로 지원하므로, 여기서 PCM을
 * 뽑아 엔진의 버퍼 스트림에 밀어넣는다. 이렇게 하면 EQ와 배속 같은 처리는
 * 그대로 두고 디코더만 갈아끼우는 셈이 된다.
 *
 * 파일 전체를 미리 풀지 않는다. 7시간짜리 음원을 PCM으로 다 풀면 몇 기가가 된다.
 * 재생이 필요한 만큼만 조금씩 읽어간다.
 */
class PcmDecoder private constructor(
    private val extractor: MediaExtractor,
    private val codec: MediaCodec,
    val sampleRate: Int,
    val channels: Int,
    val durationUs: Long,
) {
    private val bufferInfo = MediaCodec.BufferInfo()
    private var inputDone = false
    private var outputDone = false

    /** 앞으로 내보낼 PCM이 더 있는지. */
    val isFinished: Boolean get() = outputDone

    companion object {
        private const val TIMEOUT_US = 10_000L

        /** 열지 못하면 null. 호출한 쪽에서 엔진 기본 디코더로 넘긴다. */
        fun open(path: String): PcmDecoder? {
            if (!File(path).exists()) return null

            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(path)
            } catch (e: Exception) {
                extractor.release()
                return null
            }

            var trackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    format = f
                    break
                }
            }
            if (trackIndex < 0 || format == null) {
                extractor.release()
                return null
            }

            extractor.selectTrack(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME)!!

            val codec = try {
                MediaCodec.createDecoderByType(mime).also {
                    it.configure(format, null, null, 0)
                    it.start()
                }
            } catch (e: Exception) {
                extractor.release()
                return null
            }

            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION)
            } else {
                0L
            }

            return PcmDecoder(extractor, codec, sampleRate, channels, durationUs)
        }
    }

    /**
     * PCM을 [maxBytes]에 가깝게 모아서 돌려준다.
     * 더 낼 것이 없으면 빈 배열.
     */
    fun read(maxBytes: Int): ByteArray {
        if (outputDone) return ByteArray(0)

        val out = java.io.ByteArrayOutputStream(maxBytes)

        while (out.size() < maxBytes && !outputDone) {
            if (!inputDone) {
                val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inIndex >= 0) {
                    val inBuf: ByteBuffer? = codec.getInputBuffer(inIndex)
                    val size = if (inBuf == null) -1 else extractor.readSampleData(inBuf, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(
                            inIndex, 0, 0, 0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                        )
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(
                            inIndex, 0, size, extractor.sampleTime, 0,
                        )
                        extractor.advance()
                    }
                }
            }

            val outIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
            when {
                outIndex >= 0 -> {
                    if (bufferInfo.size > 0) {
                        val buf = codec.getOutputBuffer(outIndex)
                        if (buf != null) {
                            val chunk = ByteArray(bufferInfo.size)
                            buf.position(bufferInfo.offset)
                            buf.get(chunk, 0, bufferInfo.size)
                            out.write(chunk)
                        }
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                }
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    // 입력이 끝났는데 출력도 안 나오면 더 기다릴 이유가 없다.
                    if (inputDone) break
                }
                // INFO_OUTPUT_FORMAT_CHANGED 등은 그냥 넘긴다.
            }
        }

        return out.toByteArray()
    }

    /** [us] 지점으로 옮긴다. 실제로 이동한 위치를 마이크로초로 돌려준다. */
    fun seek(us: Long): Long {
        extractor.seekTo(us, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        codec.flush()
        inputDone = false
        outputDone = false
        return extractor.sampleTime.coerceAtLeast(0)
    }

    fun close() {
        try {
            codec.stop()
        } catch (_: Exception) {
        }
        try {
            codec.release()
        } catch (_: Exception) {
        }
        try {
            extractor.release()
        } catch (_: Exception) {
        }
    }
}

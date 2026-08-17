package com.pomento.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File

/**
 * audio_service가 백그라운드 재생과 잠금화면 컨트롤을 붙이려면 액티비티가
 * AudioServiceActivity를 상속해야 한다.
 */
class MainActivity : AudioServiceActivity() {

    private val methodChannelName = "com.pomento.app/media"
    private val decoderChannelName = "com.pomento.app/decoder"
    private val eventChannelName = "com.pomento.app/output_device"

    private var deviceCallback: AudioDeviceCallback? = null

    /** 열려 있는 디코더들. 한 번에 하나만 쓰지만 정리를 확실히 하려고 맵에 둔다. */
    private val decoders = mutableMapOf<Int, PcmDecoder>()
    private var nextDecoderId = 1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanAudio" -> result.success(scanAudio())
                    "copyUri" -> {
                        val uri = call.argument<String>("uri")
                        val dest = call.argument<String>("dest")
                        if (uri == null || dest == null) {
                            result.success(false)
                        } else {
                            result.success(copyUri(uri, dest))
                        }
                    }
                    "currentOutput" -> result.success(currentOutput())
                    else -> result.notImplemented()
                }
            }

        // 디코딩은 메인 스레드를 막으면 안 되므로 별도 큐에서 처리한다.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            decoderChannelName,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val dec = PcmDecoder.open(path)
                    if (dec == null) {
                        result.success(null)
                    } else {
                        val id = synchronized(decoders) {
                            val i = nextDecoderId++
                            decoders[i] = dec
                            i
                        }
                        result.success(
                            mapOf(
                                "id" to id,
                                "sampleRate" to dec.sampleRate,
                                "channels" to dec.channels,
                                "durationUs" to dec.durationUs,
                            )
                        )
                    }
                }

                "read" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val max = call.argument<Int>("maxBytes") ?: (128 * 1024)
                    val dec = synchronized(decoders) { decoders[id] }
                    if (dec == null) {
                        result.success(null)
                    } else {
                        val bytes = dec.read(max)
                        result.success(
                            mapOf("data" to bytes, "finished" to dec.isFinished)
                        )
                    }
                }

                "seek" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val us = (call.argument<Number>("us") ?: 0).toLong()
                    val dec = synchronized(decoders) { decoders[id] }
                    result.success(dec?.seek(us) ?: 0L)
                }

                "close" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val dec = synchronized(decoders) { decoders.remove(id) }
                    dec?.close()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val cb = object : AudioDeviceCallback() {
                        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>?) {
                            events?.success(currentOutput())
                        }

                        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>?) {
                            events?.success(currentOutput())
                        }
                    }
                    deviceCallback = cb
                    am.registerAudioDeviceCallback(cb, Handler(Looper.getMainLooper()))
                }

                override fun onCancel(arguments: Any?) {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    deviceCallback?.let { am.unregisterAudioDeviceCallback(it) }
                    deviceCallback = null
                }
            })
    }

    override fun onDestroy() {
        synchronized(decoders) {
            decoders.values.forEach { it.close() }
            decoders.clear()
        }
        super.onDestroy()
    }

    /**
     * 기기 미디어 저장소의 음원 목록.
     *
     * DATA 경로가 실제로 읽히면 그 경로를 같이 돌려준다. 읽히는 경우 파일을
     * 복사하지 않고 참조만 해서 저장 용량을 두 배로 쓰지 않는다. 안 읽히면
     * path를 null로 두고, 가져올 때 copyUri로 앱 저장소에 복사한다.
     */
    private fun scanAudio(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATA,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sort = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        try {
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                sort,
            )?.use { c ->
                val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val sizeCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dataCol = c.getColumnIndex(MediaStore.Audio.Media.DATA)

                while (c.moveToNext()) {
                    val id = c.getLong(idCol)
                    val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                        .buildUpon().appendPath(id.toString()).build().toString()

                    var path: String? = null
                    if (dataCol >= 0 && !c.isNull(dataCol)) {
                        val candidate = c.getString(dataCol)
                        if (!candidate.isNullOrBlank()) {
                            val f = File(candidate)
                            if (f.exists() && f.canRead()) path = candidate
                        }
                    }

                    out.add(
                        mapOf(
                            "uri" to uri,
                            "path" to path,
                            "title" to (c.getString(titleCol) ?: ""),
                            "artist" to (c.getString(artistCol) ?: ""),
                            "album" to (c.getString(albumCol) ?: ""),
                            "durationMs" to c.getLong(durCol),
                            "sizeBytes" to c.getLong(sizeCol),
                        )
                    )
                }
            }
        } catch (e: Exception) {
            return emptyList()
        }
        return out
    }

    private fun copyUri(uriString: String, dest: String): Boolean {
        return try {
            val uri = Uri.parse(uriString)
            val destFile = File(dest)
            destFile.parentFile?.mkdirs()
            contentResolver.openInputStream(uri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output, 1 shl 16)
                }
            } ?: return false
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 지금 소리가 나가는 출력 기기.
     *
     * API 31부터는 라우팅을 직접 물어볼 수 있다. 그 아래에서는 연결된 출력
     * 목록에서 우선순위로 고른다.
     */
    private fun currentOutput(): Map<String, Any?> {
        return try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val device: AudioDeviceInfo? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val attrs = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                    am.getAudioDevicesForAttributes(attrs).firstOrNull()
                        ?: pickFromList(am)
                } else {
                    pickFromList(am)
                }

            mapOf(
                "type" to normalizeType(device?.type),
                "productName" to (device?.productName?.toString() ?: ""),
            )
        } catch (e: Exception) {
            mapOf("type" to "unknown", "productName" to "")
        }
    }

    /** 연결된 출력 중 스피커가 아닌 것을 먼저 고른다. */
    private fun pickFromList(am: AudioManager): AudioDeviceInfo? {
        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.firstOrNull { it.type != AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            ?: devices.firstOrNull()
    }

    private fun normalizeType(type: Int?): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "speaker"

        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired"

        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_HEARING_AID -> "bluetooth"

        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"

        AudioDeviceInfo.TYPE_BUS,
        AudioDeviceInfo.TYPE_DOCK -> "car"

        else -> when {
            type == null -> "unknown"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                (type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    type == AudioDeviceInfo.TYPE_BLE_SPEAKER) -> "bluetooth"
            else -> "unknown"
        }
    }
}

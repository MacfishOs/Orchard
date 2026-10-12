/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

package dev.sfg.orchard.mobile.playback.smart

import android.media.MediaDataSource
import java.io.File
import java.io.RandomAccessFile

/**
 * High-performance, thread-safe [MediaDataSource] wrapper around an on-disk audio [File].
 * Allows [android.media.MediaExtractor] and [SongDecoder] to decode downloaded files
 * directly from local storage with minimal overhead.
 */
class FileMediaDataSource(private val file: File) : MediaDataSource() {
    private val raf: RandomAccessFile = RandomAccessFile(file, "r")
    private val length: Long = file.length()

    override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
        if (size == 0) return 0
        if (position >= length) return -1
        synchronized(raf) {
            raf.seek(position)
            val toRead = minOf(size.toLong(), length - position).toInt()
            return raf.read(buffer, offset, toRead)
        }
    }

    override fun getSize(): Long = length

    override fun close() {
        runCatching { raf.close() }
    }
}

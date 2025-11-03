package com.example.sportsapp

import android.content.Context
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import java.nio.charset.Charset
import java.util.concurrent.atomic.AtomicReference

/**
 * Responds to:
 * - SELECT AID (CLA=00 INS=A4 P1=04 P2=00 Lc=<len> Data=<AID> Le=00)
 * - Custom GET tokens:
 *   CLA=80 INS=0xA1 (attendance), CLA=80 INS=0xB1 (reward), P1=00 P2=00 Le=00
 * Returns payload as UTF-8 string (base64url), terminated with 0x90 0x00 status.
 */
class HceService : HostApduService() {

    enum class Mode { ATTENDANCE, REWARD }

    companion object {
        private const val AID = "F01234567890"
        private val selected = AtomicReference(false)
        private val modeRef = AtomicReference(Mode.ATTENDANCE)
        private val payloadRef = AtomicReference("")
        private val handler = Handler(Looper.getMainLooper())
        private var stopRunnable: Runnable? = null

        fun startBroadcast(ctx: Context, mode: Mode, base64UrlPayload: String, ttlSeconds: Int) {
            modeRef.set(mode)
            payloadRef.set(base64UrlPayload)
            selected.set(false)
            stopRunnable?.let { handler.removeCallbacks(it) }
            stopRunnable = Runnable {
                // After TTL, clear payload so APDUs fail
                payloadRef.set("")
            }
            handler.postDelayed(stopRunnable!!, (ttlSeconds * 1000).toLong())
        }

        fun stopBroadcast() {
            payloadRef.set("")
            selected.set(false)
            stopRunnable?.let { handler.removeCallbacks(it) }
            stopRunnable = null
        }

        private fun statusSuccess(data: ByteArray): ByteArray {
            val out = ByteArray(data.size + 2)
            System.arraycopy(data, 0, out, 0, data.size)
            out[out.size - 2] = 0x90.toByte()
            out[out.size - 1] = 0x00.toByte()
            return out
        }

        private fun hexToBytes(hex: String): ByteArray {
            val clean = hex.replace(" ", "")
            val out = ByteArray(clean.length / 2)
            var i = 0
            while (i < clean.length) {
                out[i / 2] = ((Character.digit(clean[i], 16) shl 4) + Character.digit(clean[i + 1], 16)).toByte()
                i += 2
            }
            return out
        }
    }

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        if (payloadRef.get().isEmpty()) {
            // No active broadcast
            return byteArrayOf(0x6A.toByte(), 0x82.toByte()) // file not found
        }

        // SELECT AID?
        if (isSelectAID(commandApdu)) {
            selected.set(true)
            return statusSuccess(byteArrayOf()) // OK
        }

        if (!selected.get()) {
            return byteArrayOf(0x69.toByte(), 0x85.toByte()) // conditions not satisfied
        }

        // Custom INS
        if (commandApdu.size >= 4 && commandApdu[0] == 0x80.toByte()) {
            val ins = commandApdu[1].toInt() and 0xFF
            val mode = modeRef.get()
            return when (ins) {
                0xA1 -> { // GET_ATTENDANCE_TOKEN
                    if (mode != Mode.ATTENDANCE) byteArrayOf(0x6A, 0x86.toByte())
                    else statusSuccess(payloadRef.get().toByteArray(Charset.forName("UTF-8")))
                }
                0xB1 -> { // GET_REWARD_TOKEN
                    if (mode != Mode.REWARD) byteArrayOf(0x6A, 0x86.toByte())
                    else statusSuccess(payloadRef.get().toByteArray(Charset.forName("UTF-8")))
                }
                else -> byteArrayOf(0x6D.toByte(), 0x00.toByte())
            }
        }

        return byteArrayOf(0x6D.toByte(), 0x00.toByte()) // INS not supported
    }

    override fun onDeactivated(reason: Int) {
        selected.set(false)
    }

    private fun isSelectAID(apdu: ByteArray): Boolean {
        if (apdu.size < 5) return false
        // 00 A4 04 00 Lc <AID> 00
        if (apdu[0] != 0x00.toByte() || apdu[1] != 0xA4.toByte()) return false
        val lc = apdu[4].toInt() and 0xFF
        if (apdu.size < 5 + lc) return false
        val aidBytes = apdu.copyOfRange(5, 5 + lc)
        val selAid = bytesToHex(aidBytes)
        return selAid.equals(AID, ignoreCase = true)
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val sb = StringBuilder()
        for (b in bytes) sb.append(String.format("%02X", b))
        return sb.toString()
    }
}
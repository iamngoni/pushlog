package za.co.codecraftsolutions.pushlog

import org.json.JSONObject

object WearProtocol {
    const val PATH = "/pushlog/workout"
    const val CAPABILITY = "pushlog_workout"

    fun encode(type: String, values: Map<String, Any?> = emptyMap()): ByteArray {
        val payload = JSONObject().put("type", type)
        values.forEach { (key, value) -> payload.put(key, value) }
        return payload.toString().toByteArray(Charsets.UTF_8)
    }

    fun decode(bytes: ByteArray): JSONObject =
        JSONObject(bytes.toString(Charsets.UTF_8))
}

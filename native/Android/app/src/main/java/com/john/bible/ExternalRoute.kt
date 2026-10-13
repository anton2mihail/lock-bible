package com.john.bible

import java.net.URI
import java.net.URLDecoder
import java.time.LocalDate

/** Accept the same public nrsv:// links as iOS, and Android's john:// alias. */
fun externalRoute(value:String?,defaultEdition:String="web-ce"):String? {
    if(value==null) return null
    return runCatching {
        val uri=URI(value)
        if(uri.scheme?.lowercase() !in setOf("nrsv","john","john11")) return null
        val query=uri.rawQuery.orEmpty().split('&').filter { it.contains('=') }.map { it.split('=',limit=2) }.associate { URLDecoder.decode(it[0],"UTF-8") to URLDecoder.decode(it[1],"UTF-8") }
        when(uri.host?.lowercase()) {
            "read","reader" -> {
                val book=query["book"]?.takeIf { it.matches(Regex("[A-Z0-9]{3}")) } ?: "JHN"
                val chapter=query["chapter"]?.toIntOrNull()?.takeIf { it>0 } ?: 1
                val edition=query["translation"]?.takeIf { it in setOf("web-ce","douay-rheims","vulgate") } ?: defaultEdition.takeIf { it in setOf("web-ce","douay-rheims","vulgate") } ?: "web-ce"
                val verse=query["verse"]?.takeIf { it.matches(Regex("[A-Za-z0-9]+")) }
                "reader/$edition/$book/$chapter"+(verse?.let { "/$it" } ?: "")
            }
            "daily" -> "daily/"+runCatching { LocalDate.parse(query["date"]).toString() }.getOrElse { LocalDate.now().toString() }
            "saved" -> "saved"
            "pray" -> when(uri.path) { "/lectio"->"lectio"; "/rosary"->"rosary"; else->null }
            "lectio" -> "lectio"
            "rosary" -> "rosary"
            else -> null
        }
    }.getOrNull()
}

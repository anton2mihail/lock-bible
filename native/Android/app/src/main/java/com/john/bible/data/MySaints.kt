package com.john.bible.data

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.MonthDay
import java.time.ZonedDateTime
import java.util.UUID

data class SaintObservance(val id:String,val tradition:String,val entryID:String,val monthDay:String,val name:String,
    val sourceURL:String,val calendarURL:String,val account:String,val isSummary:Boolean,val observanceNote:String?,val reviewedSummary:String?=null) {
    val displayAccount:String get()=reviewedSummary ?: account
    val displayIsSummary:Boolean get()=reviewedSummary!=null || isSummary
    val calendarName:String get()=if(tradition=="byzantine") "Byzantine Catholic · Ruthenian" else "Vatican News"
}
data class PersonalSaint(val id:String,val name:String,val subtitle:String,val artwork:String?,val artworkCredit:String?,val novenaID:String?,val commemorations:List<SaintObservance>) {
    fun observance(profile:SaintProfile)=commemorations.firstOrNull { it.id==profile.observanceID } ?: commemorations.first()
    fun widgetText(profile:SaintProfile)=if(id=="st-joseph") "St. Joseph, Patron of departing souls, pray for us. Amen" else observance(profile).account
}
data class SaintNote(val id:String=UUID.randomUUID().toString(),val text:String,val createdAt:Long=System.currentTimeMillis())
data class SaintProfile(val saved:Boolean=false,val reason:String="",val notes:List<SaintNote> = emptyList(),val observanceID:String?=null,
    val plannedFeastDate:String?=null,val reminderEnabled:Boolean=false,val reminderHour:Int=8,val reminderMinute:Int=0) {
    fun json()=JSONObject().put("saved",saved).put("reason",reason)
        .put("notes",JSONArray(notes.map { JSONObject().put("id",it.id).put("text",it.text).put("createdAt",it.createdAt) }))
        .put("observanceID",observanceID).put("plannedFeastDate",plannedFeastDate).put("reminderEnabled",reminderEnabled)
        .put("reminderHour",reminderHour).put("reminderMinute",reminderMinute)
    companion object {
        fun parse(value:JSONObject?):SaintProfile {
            if(value==null)return SaintProfile()
            val notes=value.optJSONArray("notes") ?: JSONArray()
            return SaintProfile(value.optBoolean("saved"),value.optString("reason"),(0 until notes.length()).mapNotNull { i ->
                notes.optJSONObject(i)?.let { SaintNote(it.getString("id"),it.getString("text"),it.getLong("createdAt")) }
            },value.optionalString("observanceID"),value.optionalString("plannedFeastDate"),value.optBoolean("reminderEnabled"),
                value.optInt("reminderHour",8).coerceIn(0,23),value.optInt("reminderMinute",0).coerceIn(0,59))
        }
    }
}
internal fun JSONObject.optionalString(key:String):String?=if(isNull(key))null else optString(key).takeIf { it.isNotBlank() }
fun personalSaintsFromJSON(array:JSONArray):List<PersonalSaint> = (0 until array.length()).map { i ->
    val row=array.getJSONObject(i);val entries=row.getJSONArray("commemorations")
    PersonalSaint(row.getString("id"),row.getString("name"),row.getString("subtitle"),row.optionalString("artwork"),row.optionalString("artworkCredit"),row.optionalString("novenaID"),
        (0 until entries.length()).map { j -> val e=entries.getJSONObject(j)
            SaintObservance(e.getString("id"),e.getString("tradition"),e.getString("entryID"),e.getString("monthDay"),e.getString("name"),
                e.getString("sourceURL"),e.getString("calendarURL"),e.getString("account"),e.getBoolean("isSummary"),e.optionalString("observanceNote"),e.optionalString("reviewedSummary")) })
}
object SaintDates {
    fun nextOccurrence(monthDay:String,from:LocalDate=LocalDate.now()):LocalDate {
        val day=MonthDay.parse("--$monthDay")
        return (from.year..from.year+8).mapNotNull { year -> if(day.isValidYear(year)) day.atYear(year) else null }.first { it>=from }
    }
    fun reminderDate(monthDay:String,hour:Int,minute:Int,now:ZonedDateTime=ZonedDateTime.now()):ZonedDateTime {
        var day=nextOccurrence(monthDay,now.toLocalDate())
        var next=day.atTime(hour,minute).atZone(now.zone)
        if(next<=now) { day=nextOccurrence(monthDay,day.plusDays(1));next=day.atTime(hour,minute).atZone(now.zone) }
        return next
    }
    fun planIsDue(profile:SaintProfile,now:LocalDate=LocalDate.now()):Boolean = runCatching {
        val feast=LocalDate.parse(profile.plannedFeastDate)
        now>=feast.minusDays(9) && now<feast
    }.getOrDefault(false)
}

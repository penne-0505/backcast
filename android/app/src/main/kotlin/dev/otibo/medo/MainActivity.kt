package dev.otibo.medo

import android.Manifest
import android.content.ContentProviderOperation
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
	companion object {
		private const val CHANNEL = "medo/calendar_export"
		private const val METHOD_SAVE_CALENDAR_EXPORT = "saveCalendarExport"
		private const val REQUEST_CODE_CALENDAR_PERMISSIONS = 0xA70
	}

	private var pendingResult: MethodChannel.Result? = null
	private var pendingEvents: List<CalendarExportEventPayload>? = null
	private var pendingCalendarId: Long? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				METHOD_SAVE_CALENDAR_EXPORT -> handleSaveCalendarExport(call, result)
				else -> result.notImplemented()
			}
		}
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray,
	) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)

		if (requestCode != REQUEST_CODE_CALENDAR_PERMISSIONS) {
			return
		}

		val result = pendingResult
		val events = pendingEvents
		val calendarId = pendingCalendarId
		pendingResult = null
		pendingEvents = null
		pendingCalendarId = null

		if (result == null || events == null) {
			return
		}

		if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
			try {
				val exportResult = saveCalendarExport(events, calendarId)
				result.success(exportResult)
			} catch (e: Exception) {
				result.error("save_failed", e.message, null)
			}
		} else {
			result.error(
				"permission_denied",
				"Calendar permissions were denied.",
				null,
			)
		}
	}

	private fun handleSaveCalendarExport(call: MethodCall, result: MethodChannel.Result) {
		try {
			val events = parseEvents(call.arguments)
			val args = call.arguments as? Map<*, *>
			val calendarId = (args?.get("calendarId") as? String)?.toLongOrNull()

			if (!hasCalendarPermissions()) {
				if (pendingResult != null) {
					throw IllegalStateException("Calendar export is already waiting for permissions.")
				}

				pendingResult = result
				pendingEvents = events
				pendingCalendarId = calendarId
				requestCalendarPermissions()
				return
			}

			val exportResult = saveCalendarExport(events, calendarId)
			result.success(exportResult)
		} catch (e: IllegalArgumentException) {
			result.error("invalid_payload", e.message, null)
		} catch (e: SecurityException) {
			result.error("permission_denied", e.message, null)
		} catch (e: IllegalStateException) {
			result.error("no_writable_calendar", e.message, null)
		} catch (e: Exception) {
			result.error("save_failed", e.message, null)
		}
	}

	private fun saveCalendarExport(events: List<CalendarExportEventPayload>, calendarId: Long?): Map<String, Any> {
		val resolvedCalendarId = calendarId ?: resolveWritableCalendarId()
			?: throw IllegalStateException("No writable calendar is available.")
		val calendarName = resolveCalendarName(resolvedCalendarId)
		val timezone = TimeZone.getDefault().id
		val operations = events.map { event ->
			ContentProviderOperation.newInsert(CalendarContract.Events.CONTENT_URI)
				.withValue(CalendarContract.Events.CALENDAR_ID, resolvedCalendarId)
				.withValue(CalendarContract.Events.TITLE, event.title)
				.withValue(CalendarContract.Events.DTSTART, event.startAtMillis)
				.withValue(CalendarContract.Events.DTEND, event.endAtMillis)
				.withValue(CalendarContract.Events.EVENT_TIMEZONE, timezone)
				.build()
		}

		contentResolver.applyBatch(CalendarContract.AUTHORITY, ArrayList(operations))

		return mapOf(
			"savedCount" to operations.size,
			"calendarName" to (calendarName ?: ""),
		)
	}

	private fun parseEvents(arguments: Any?): List<CalendarExportEventPayload> {
		val root = arguments as? Map<*, *> ?: throw IllegalArgumentException("Missing arguments.")
		val rawEvents = root["events"] as? List<*> ?: throw IllegalArgumentException("Missing events list.")
		if (rawEvents.isEmpty()) {
			throw IllegalArgumentException("At least one calendar event is required.")
		}

		return rawEvents.mapIndexed { index, item ->
			val map = item as? Map<*, *>
				?: throw IllegalArgumentException("Invalid event payload at index $index.")
			val title = map["title"] as? String
				?: throw IllegalArgumentException("Missing title for event at index $index.")
			val startAtMillis = (map["startAtMillis"] as? Number)?.toLong()
				?: throw IllegalArgumentException("Missing startAtMillis for event at index $index.")
			val endAtMillis = (map["endAtMillis"] as? Number)?.toLong()
				?: throw IllegalArgumentException("Missing endAtMillis for event at index $index.")

			CalendarExportEventPayload(
				id = (map["id"] as? String).orEmpty(),
				title = title,
				startAtMillis = startAtMillis,
				endAtMillis = endAtMillis,
			)
		}
	}

	private fun hasCalendarPermissions(): Boolean {
		return hasPermission(Manifest.permission.READ_CALENDAR) &&
			hasPermission(Manifest.permission.WRITE_CALENDAR)
	}

	private fun hasPermission(permission: String): Boolean {
		return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
	}

	private fun requestCalendarPermissions() {
		ActivityCompat.requestPermissions(
			this,
			arrayOf(
				Manifest.permission.READ_CALENDAR,
				Manifest.permission.WRITE_CALENDAR,
			),
			REQUEST_CODE_CALENDAR_PERMISSIONS,
		)
	}

	private fun resolveWritableCalendarId(): Long? {
		val projection = arrayOf(Calendars._ID)
		val selection = "${Calendars.VISIBLE} = 1 AND ${Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
		val selectionArgs = arrayOf(Calendars.CAL_ACCESS_CONTRIBUTOR.toString())
		val sortOrder = "${Calendars.IS_PRIMARY} DESC, ${Calendars.CALENDAR_ACCESS_LEVEL} DESC, ${Calendars._ID} ASC"

		contentResolver.query(
			Calendars.CONTENT_URI,
			projection,
			selection,
			selectionArgs,
			sortOrder,
		)?.use { cursor ->
			if (cursor.moveToFirst()) {
				return cursor.getLong(0)
			}
		}

		return null
	}

	private fun resolveCalendarName(calendarId: Long): String? {
		val projection = arrayOf(Calendars.CALENDAR_DISPLAY_NAME)
		val selection = "${Calendars._ID} = ?"
		val selectionArgs = arrayOf(calendarId.toString())

		contentResolver.query(
			Calendars.CONTENT_URI,
			projection,
			selection,
			selectionArgs,
			null,
		)?.use { cursor ->
			if (cursor.moveToFirst()) {
				return cursor.getString(0)
			}
		}

		return null
	}

	private data class CalendarExportEventPayload(
		val id: String,
		val title: String,
		val startAtMillis: Long,
		val endAtMillis: Long,
	)
}

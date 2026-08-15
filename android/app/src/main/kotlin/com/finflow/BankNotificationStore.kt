package com.finflow

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject

object BankNotificationStore {
    private const val databaseName = "finflow_bank_notifications.db"
    private const val databaseVersion = 2
    private const val maxQueueSize = 50
    private const val legacyPrefs = "finflow_bank_notifications"
    private const val legacyQueue = "pending"
    private const val legacyEnabled = "enabled"
    private const val legacyPackages = "packages"
    private const val packagesConfigured = "packages_configured"
    private const val diagnosticPrefix = "diagnostic_"

    @Volatile
    private var databaseHelper: StoreDatabase? = null

    fun isEnabled(context: Context): Boolean =
        setting(context, legacyEnabled) == "1"

    fun setEnabled(context: Context, enabled: Boolean) {
        putSetting(context, legacyEnabled, if (enabled) "1" else "0")
    }

    fun enabledPackages(context: Context): Set<String> {
        val database = helper(context).readableDatabase
        return buildSet {
            database.query(
                "enabled_packages",
                arrayOf("package_name"),
                null,
                null,
                null,
                null,
                null,
            ).use { cursor ->
                while (cursor.moveToNext()) add(cursor.getString(0))
            }
        }
    }

    fun setEnabledPackages(context: Context, packages: Set<String>) {
        val database = helper(context).writableDatabase
        database.beginTransaction()
        try {
            database.delete("enabled_packages", null, null)
            packages.forEach { packageName ->
                database.insertOrThrow(
                    "enabled_packages",
                    null,
                    ContentValues().apply {
                        put("package_name", packageName)
                    },
                )
            }
            database.insertWithOnConflict(
                "settings",
                null,
                ContentValues().apply {
                    put("key", packagesConfigured)
                    put("value", "1")
                },
                SQLiteDatabase.CONFLICT_REPLACE,
            )
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
    }

    fun configuration(context: Context): Map<String, Any> =
        mapOf(
            "enabled" to isEnabled(context),
            "packages" to enabledPackages(context).toList(),
            "packagesConfigured" to (setting(context, packagesConfigured) == "1"),
        )

    fun enqueue(context: Context, item: JSONObject): Boolean {
        val id = item.optString("id")
        if (id.isBlank()) return false
        val database = helper(context).writableDatabase
        val inserted = database.insertWithOnConflict(
            "pending_notifications",
            null,
            ContentValues().apply {
                put("id", id)
                put("package_name", item.optString("packageName"))
                put("title", item.optString("title"))
                put("body", item.optString("text"))
                put("posted_at", item.optLong("postedAt"))
                put("inserted_at", System.currentTimeMillis())
            },
            SQLiteDatabase.CONFLICT_IGNORE,
        )
        if (inserted == -1L) return false
        database.execSQL(
            """
            DELETE FROM pending_notifications
            WHERE id NOT IN (
                SELECT id
                FROM pending_notifications
                ORDER BY inserted_at DESC
                LIMIT $maxQueueSize
            )
            """.trimIndent(),
        )
        return true
    }

    fun pending(context: Context): List<Map<String, Any?>> {
        val database = helper(context).readableDatabase
        return buildList {
            database.query(
                "pending_notifications",
                arrayOf("id", "package_name", "title", "body", "posted_at"),
                null,
                null,
                null,
                null,
                "inserted_at ASC",
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    add(
                        mapOf(
                            "id" to cursor.getString(0),
                            "packageName" to cursor.getString(1),
                            "title" to cursor.getString(2),
                            "text" to cursor.getString(3),
                            "postedAt" to cursor.getLong(4),
                        ),
                    )
                }
            }
        }
    }

    fun remove(context: Context, id: String) {
        helper(context).writableDatabase.delete(
            "pending_notifications",
            "id = ?",
            arrayOf(id),
        )
    }

    fun containsPending(context: Context, id: String): Boolean {
        helper(context).readableDatabase.query(
            "pending_notifications",
            arrayOf("id"),
            "id = ?",
            arrayOf(id),
            null,
            null,
            null,
            "1",
        ).use { cursor -> return cursor.moveToFirst() }
    }

    fun recordDiagnostic(context: Context, key: String, value: Any?) {
        putSetting(context, "$diagnosticPrefix$key", value?.toString().orEmpty())
    }

    fun diagnostics(context: Context): Map<String, String> {
        val database = helper(context).readableDatabase
        return buildMap {
            database.query(
                "settings",
                arrayOf("key", "value"),
                "key LIKE ?",
                arrayOf("$diagnosticPrefix%"),
                null,
                null,
                null,
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    put(
                        cursor.getString(0).removePrefix(diagnosticPrefix),
                        cursor.getString(1),
                    )
                }
            }
        }
    }

    private fun setting(context: Context, key: String): String? {
        val database = helper(context).readableDatabase
        database.query(
            "settings",
            arrayOf("value"),
            "key = ?",
            arrayOf(key),
            null,
            null,
            null,
            "1",
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    private fun putSetting(context: Context, key: String, value: String) {
        helper(context).writableDatabase.insertWithOnConflict(
            "settings",
            null,
            ContentValues().apply {
                put("key", key)
                put("value", value)
            },
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    private fun helper(context: Context): StoreDatabase {
        databaseHelper?.let { return it }
        return synchronized(this) {
            databaseHelper ?: StoreDatabase(context.applicationContext).also {
                it.setWriteAheadLoggingEnabled(true)
                databaseHelper = it
            }
        }
    }

    private class StoreDatabase(
        private val context: Context,
    ) : SQLiteOpenHelper(context, databaseName, null, databaseVersion) {
        override fun onCreate(database: SQLiteDatabase) {
            database.execSQL(
                """
                CREATE TABLE settings (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                )
                """.trimIndent(),
            )
            database.execSQL(
                """
                CREATE TABLE enabled_packages (
                    package_name TEXT PRIMARY KEY NOT NULL
                )
                """.trimIndent(),
            )
            database.execSQL(
                """
                CREATE TABLE pending_notifications (
                    id TEXT PRIMARY KEY NOT NULL,
                    package_name TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    posted_at INTEGER NOT NULL,
                    inserted_at INTEGER NOT NULL
                )
                """.trimIndent(),
            )
            migrateLegacyPreferences(database)
        }

        override fun onUpgrade(
            database: SQLiteDatabase,
            oldVersion: Int,
            newVersion: Int,
        ) {
            if (oldVersion < 2) {
                val hasPackages = database.rawQuery(
                    "SELECT EXISTS(SELECT 1 FROM enabled_packages LIMIT 1)",
                    null,
                ).use { cursor -> cursor.moveToFirst() && cursor.getInt(0) == 1 }
                if (hasPackages) {
                    database.insertWithOnConflict(
                        "settings",
                        null,
                        ContentValues().apply {
                            put("key", packagesConfigured)
                            put("value", "1")
                        },
                        SQLiteDatabase.CONFLICT_REPLACE,
                    )
                }
            }
        }

        private fun migrateLegacyPreferences(database: SQLiteDatabase) {
            val preferences = context.getSharedPreferences(legacyPrefs, Context.MODE_PRIVATE)
            val enabled = preferences.getBoolean(legacyEnabled, false)
            database.insert(
                "settings",
                null,
                ContentValues().apply {
                    put("key", legacyEnabled)
                    put("value", if (enabled) "1" else "0")
                },
            )
            preferences.getStringSet(legacyPackages, emptySet()).orEmpty().forEach {
                database.insertWithOnConflict(
                    "enabled_packages",
                    null,
                    ContentValues().apply { put("package_name", it) },
                    SQLiteDatabase.CONFLICT_IGNORE,
                )
            }
            if (preferences.contains(legacyPackages)) {
                database.insertWithOnConflict(
                    "settings",
                    null,
                    ContentValues().apply {
                        put("key", packagesConfigured)
                        put("value", "1")
                    },
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            }
            readLegacyQueue(preferences.getString(legacyQueue, null)).forEach { item ->
                database.insertWithOnConflict(
                    "pending_notifications",
                    null,
                    ContentValues().apply {
                        put("id", item.optString("id"))
                        put("package_name", item.optString("packageName"))
                        put("title", item.optString("title"))
                        put("body", item.optString("text"))
                        put("posted_at", item.optLong("postedAt"))
                        put("inserted_at", item.optLong("postedAt"))
                    },
                    SQLiteDatabase.CONFLICT_IGNORE,
                )
            }
        }

        private fun readLegacyQueue(raw: String?): List<JSONObject> =
            try {
                if (raw.isNullOrBlank()) {
                    emptyList()
                } else {
                    val array = JSONArray(raw)
                    buildList {
                        for (index in 0 until array.length()) {
                            array.optJSONObject(index)?.let(::add)
                        }
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
    }
}

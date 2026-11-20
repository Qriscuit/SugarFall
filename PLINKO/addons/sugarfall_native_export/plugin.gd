@tool
extends EditorPlugin

var _exporter: EditorExportPlugin

func _enter_tree() -> void:
	_exporter = NativeExport.new()
	add_export_plugin(_exporter)

func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null

class NativeExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "SugarfallNativeExport"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		# Poing's AAR declares this nonexistent Android framework permission.
		# Google Ads declares its actual com.google.android.gms.permission.AD_ID.
		return '<uses-permission xmlns:tools="http://schemas.android.com/tools" android:name="android.permission.AD_ID" tools:node="remove" />'

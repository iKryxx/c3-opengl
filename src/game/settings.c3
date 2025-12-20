module game::settings;
import std::io;
import engine::core::fs;


struct SettingsValue {
	union {
		long ival;
		double dval;
		bool bval;
	}
}

struct Setting_entry {
	String description;
	typeid value_t;
	SettingsValue value;
	SettingsValue min;
	SettingsValue max;
}

enum Setting : const ulong {
	VSYNC = 0,
	FOV,
	SENSITIVITY,
	SETTINGS_LEN
}

typedef Settings = Setting_entry[];
const usz SETTINGS_LEN = 3;
faultdef SETTING_DOES_NOT_EXIST;
bool should_update = false;

// Default values
Settings game_settings = {
	{ "V-Sync", bool, {.bval = false}, {.bval = false}, {.bval = true}},
	{ "Field of view", long, {.ival = 70}, {.ival = 20}, {.ival = 130}},
	{ "Mouse Sensitivity", double, {.dval = 2}, {.dval = 0.5}, {.dval = 10}},
};

fn Setting_entry* Settings.get_entry(&self, Setting setting) {
	return (Setting_entry*)((void*)self.ptr + Setting_entry.sizeof * (ulong)setting);
}

fn SettingsValue Settings.get(&self, Setting setting) @operator([]) {
	Setting_entry* entry = self.get_entry(setting);

	return entry.value;
}

fn String SettingsValue.to_string(self, typeid t) {
	switch(t) {
		case bool: return self.bval ? "true" : "false";
		case long: return string::tformat("%d", self.ival);
		case double: return string::tformat("%f", self.dval);
		default: return "<invalid>";
	}
}

fn void? SettingsValue.fromString(&self, typeid t, String s) {
	switch(t) {
		case bool:
			self.bval = (s == "true" || s == "1");
			break;
		case long:
			self.ival = s.to_long()!;
			break;
		case double:
			self.dval = s.to_double()!;
			break;
		default:
			break;
	}
}

fn void? Settings.write_ini(self, String path) {
	File f = file::open(path, "w")!;
	OutStream os = (OutStream)&f;

	io::fprintf(os, "[Settings]\n")!;

	for(usz i = 0; i < SETTINGS_LEN; i++) {
		Setting_entry *s = self.get_entry((Setting)i);

		String key = s.description;
		String val = s.value.to_string(s.value_t);

		io::fprintf(os, "%s=%s\n", key, val)!;
	}

	f.close()!;
}

fn void? Settings.parse_ini(self, Ini_file *f) {
	for(usz i = 0; i < SETTINGS_LEN; i++) {
		Setting_entry* s = self.get_entry((Setting)i);

		String key = s.description;
		String val = string::tformat("%s", (ZString)fs::ini_get(f, "Settings", key));

		s.value.fromString(s.value_t, val)!;
	}

	should_update = true;
}

fn bool? Settings.getb(self, String key) {
	for(usz i = 0; i < SETTINGS_LEN; i++) {
		Setting_entry* s = self.get_entry((Setting)i);

		String s_key = s.description;
		if(key == s_key && s.value_t == bool) return s.value.bval;
	}

	return SETTING_DOES_NOT_EXIST?;
}

fn long? Settings.geti(self, String key) {
	for(usz i = 0; i < SETTINGS_LEN; i++) {
		Setting_entry* s = self.get_entry((Setting)i);

		String s_key = s.description;
		if(key == s_key && s.value_t == long) return s.value.ival;
	}

	return SETTING_DOES_NOT_EXIST?;
}

fn double? Settings.getd(self, String key) {
	for(usz i = 0; i < SETTINGS_LEN; i++) {
		Setting_entry* s = self.get_entry((Setting)i);

		String s_key = s.description;
		if(key == s_key && s.value_t == double) return s.value.dval;
	}

	return SETTING_DOES_NOT_EXIST?;
}

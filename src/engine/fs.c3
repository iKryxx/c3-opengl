module engine::core::fs;

import std::io;
import libc;

faultdef MALFORMED_BOOLEAN;

struct Ini_kv {
    char* key;
    char* value;
}

struct Ini_section {
    char* name;
    Ini_kv* pairs;
    usz pairs_count;
}

struct Ini_file {
    Ini_section* sections;
    usz sections_count;
}

fn void print_ini_file(Ini_file *f) {
    for(usz i = 0; i < f.sections_count; i++) {
	Ini_section *sec = &f.sections[i];
	io::printfn("[%s]", (ZString)sec.name);
	for(int j = 0; j < sec.pairs_count; j++) {
	    Ini_kv *kv = &sec.pairs[j];
	    io::printfn("\t%s=%s", (ZString)kv.key, (ZString)kv.value);
	}
    }
}

fn bool isspace(char c) {
    return c == ' '; 
}

fn char *ltrim(char *s)
{
    while(isspace(*s)) s++;
    return s;
}

fn char *rtrim(char *s)
{
    char* back = s + libc::strlen((ZString)s);
    while(isspace(*--back));
    *(back+1) = '\0';
    return s;
}

fn char *trim(char *s)
{
    return rtrim(ltrim(s)); 
}

fn Ini_file? ini_parse(String path) {
    File f = file::open(path, "r")!;

    usz size = f.seek(0, Seek.END)!;
    f.seek(0, Seek.SET)!;

    char* data = tmalloc(size + 1);
    f.read(data[:size])!;
    data[size] = 0;
    f.close()!;

    Ini_file ini = {};
    Ini_section *curr = null;

    char* line = data;
    while(line && *line) {
	char* end = libc::strchr(line, '\n');
	if(end) *end = '\0';

	char* s = trim(line);
	
	if(*s == ';' || *s == '#' || *s == '\0') {}
	else if(*s == '[') {
	    char *r = libc::strchr(s, ']');

	    if(r) {
		*r = '\0';
		
		ini.sections = realloc(ini.sections, Ini_section.sizeof * (ini.sections_count + 1));
		curr = &ini.sections[ini.sections_count++];
		*curr = {
		    .name = libc::strdup((ZString)(s + 1)),
		    .pairs = null,
		};
	    }
	}
	else {
	    char *eq = libc::strchr(s, '=');
	    if(eq && curr) {
		*eq = '\0';
		char *k = trim(s);
		char *v = trim(eq + 1);

		curr.pairs = realloc(curr.pairs, Ini_kv.sizeof * (curr.pairs_count + 1));
		curr.pairs[curr.pairs_count++] = {
		    .key = libc::strdup((ZString)k),
		    .value = libc::strdup((ZString)v)
		};
	    }
	}
	line = end ? end + 1 : null;
    }
    return ini;
}

fn char* ini_get(Ini_file *ini, char* section, char* key) {
    for(usz i = 0; i < ini.sections_count; i++) {
	Ini_section *sec = &ini.sections[i];

	if((section == null && sec.name == null ) ||
	(sec.name && libc::strcmp((ZString)sec.name, (ZString)section) == 0)) {
	    for(usz j = 0; j < sec.pairs_count; j++) {
		Ini_kv *kv = &sec.pairs[j];
		if(libc::strcmp((ZString)kv.key, (ZString)key) == 0) return kv.value;
	    }
	}
    }
    return null;
}

fn void Ini_file.free(self) {
    for(usz i = 0; i < self.sections_count; i++) {
	Ini_section *sec = &self.sections[i];
	free(sec.name);

	for(usz j = 0; j < sec.pairs_count; j++) {
	    free(sec.pairs[j].key);
	    free(sec.pairs[j].value);
	}

	free(sec.pairs);
    }
    free(self.sections);
}

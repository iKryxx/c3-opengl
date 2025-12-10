module engine::core;

import std::io;

alias LogLevel = CInt;

const LogLevel LOGLEVEL_LOG = 1;
const LogLevel LOGLEVEL_INFO = 2;
const LogLevel LOGLEVEL_WARNING = 4;
const LogLevel LOGLEVEL_ERROR = 8;

struct EngineConfig {
    int log_level;
}

EngineConfig g_cfg;

fn void print_level(CInt level) @private{
    switch(level) {
	case LOGLEVEL_LOG: io::print("LOG: ");
	case LOGLEVEL_INFO: io::print("INFO: ");
	case LOGLEVEL_WARNING: io::print("WARNING: ");
	case LOGLEVEL_ERROR: io::print("ERROR: ");
    }
}

fn void _log(LogLevel level, String fmt, args...) @format(1) @private {
    if(!((int)level & g_cfg.log_level)) return;
    print_level(level);
    io::printfn(fmt, ...args);
    if(level == LOGLEVEL_ERROR) {
	abort();
    }
}

fn void log(String fmt, args...) @format(0) {
    _log(LOGLEVEL_LOG, fmt, ...args);
}
fn void info(String fmt, args...) @format(0) {
    _log(LOGLEVEL_INFO, fmt, ...args);
}
fn void warning(String fmt, args...) @format(0) {
    _log(LOGLEVEL_WARNING, fmt, ...args);
}
fn void error(String fmt, args...) @format(0) {
    _log(LOGLEVEL_ERROR, fmt, ...args);
}

fn void to_file(String path, String fmt, args...) @format(1) {
    File f = file::open(path, "wb")!!;


    io::fprintf((OutStream)&f, fmt, ...args)!!;
}




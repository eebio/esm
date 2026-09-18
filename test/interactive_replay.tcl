set timeout 120
set verbose 0

exp_internal $verbose
log_user $verbose
log_file -a /tmp/esm-interactive.expect.log

proc debug {message} {
    global verbose
    if {$verbose} {
        puts stderr "DEBUG: $message"
        flush stderr
    }
}

set event_file [lindex $argv 0]
set separator [lsearch -exact $argv --]
if {$separator < 1 || $separator == [expr {[llength $argv] - 1}]} {
    error "Usage: interactive_replay.tcl EVENT_FILE ... -- COMMAND ..."
}
set event_files [lrange $argv 0 [expr {$separator - 1}]]
set command [lrange $argv [expr {$separator + 1}] end]

# Disable input CR->NL translation so a sent "\r" reaches Julia as a literal
# carriage return (13); TerminalMenus only treats byte 13 as Enter.
set stty_init "-icrnl"
spawn {*}$command


# The child toggles the terminal between cooked and raw mode around every
# menu/prompt call. If a key is sent while it is briefly back in cooked mode
# (e.g. while transitioning between menus), it gets echoed as literal text
# instead of being read as a keypress. --code-coverage=user adds enough JIT/GC
# overhead at these transitions that a short delay is not always enough, so
# this is intentionally generous.
#
# This must be a plain sleep, not an `expect`-based drain: any pattern that
# matches pending output consumes/discards it from the buffer, which would
# eat the very next prompt text that a later "EXPECT:" line still needs to
# see. A plain `after` never touches the pty buffer, so nothing is lost.
proc settle {} {
    after 200
}

set event_count [llength $event_files]
set event_index 0
foreach event_file $event_files {
    incr event_index
    set input [open $event_file r]
    while {[gets $input line] >= 0} {
    set raw_line $line
    set line [string trim $line]

    debug "raw=[list $raw_line] parsed=[list $line]"

    if {$line eq "" || [string match "#*" $line]} {
        continue
    }

    # EXPECT_WAIT marks the prompt that starts a raw-mode interaction.
    if {[string match "EXPECT_WAIT:*" $line] || [string match "EXPECT:*" $line]} {
        set wait_for_raw [string match "EXPECT_WAIT:*" $line]
        set prefix_length [expr {$wait_for_raw ? 12 : 7}]
        set expected [string range $line $prefix_length end]
        debug "waiting for [list $expected]"

        # Escape glob metacharacters (notably "[" and "]", which appear
        # literally in prompts like "(press [q] to quit)") before matching.
        set expected_pattern [string map {* \\* ? \\? \[ \\[ \] \\]} $expected]

        expect {
            # Do not add a trailing wildcard: it would consume output that
            # follows the expected text, including session completion markers.
            -glob "*$expected_pattern" {
                debug "matched [list $expected]"
                if {$wait_for_raw} {
                    expect {
                        -re "\x1b\\\[\\?25l" {
                            debug "raw mode confirmed (cursor hidden)"
                        }
                        -timeout 2 timeout {
                            debug "no cursor-hide signal seen within timeout"
                        }
                    }
                }
                settle
            }
            timeout {
                debug "timeout waiting for [list $expected]"
                error "Timed out waiting for: $expected"
            }
            eof {
                debug "child exited while waiting"
                error "Child exited while waiting for: $expected"
            }
        }
        continue
    }

    debug "sending event [list $line]"

    # Arrow keys only move the cursor within an already-open, already
    # raw-mode menu -- no settle needed, since there's no cooked-mode
    # transition to race until the menu is exited via ENTER/Q.
    switch -- $line {
        ENTER { send -- "\r"; settle }
        UP { send -- "\033\[A" }
        DOWN { send -- "\033\[B" }
        LEFT { send -- "\033\[D" }
        RIGHT { send -- "\033\[C" }
        Q { send -- "q" }
        default {
            if {[string match "TEXT:*" $line]} {
                send -- [string range $line 5 end]
                settle
            } else {
                error "Unknown interactive event: $line"
            }
        }
    }
    }
    close $input

    if {$event_index < $event_count} {
        expect {
            "ESM_INTERACTIVE_SESSION_DONE" {}
            timeout { error "Timed out waiting for interactive session $event_index to finish" }
            eof { error "Child exited after interactive session $event_index" }
        }
    }
}

expect {
    "ESM_INTERACTIVE_TEST_PASSED" { send -- "\n" }
    timeout { error "Timed out waiting for the interactive test child" }
}
expect eof

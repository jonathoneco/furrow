package cli

import (
	"strings"
)

// handlePreBashInternalScript implements the Go port of script-guard.sh
// (research/hook-audit.md §2.6). The hook fires on every PreToolUse(Bash)
// and emits `script_guard_internal_invocation` when the command tokenizes
// to a direct execution of a `bin/frw.d/` script.
//
// The original POSIX-awk parser is replicated here as a hand-rolled
// scanner. The migration motivation was the awk parser's testability and
// maintainability (audit §2.6 finding: "POSIX-awk is the wrong tool for
// shell-tokenization"). The Go scanner runs in the same time/memory
// budget but is straightforward to table-test.
func handlePreBashInternalScript(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	command, err := requireString(evt.Payload, "command")
	if err != nil {
		// Required key missing — invocation error per shared-contracts.
		return nil, err
	}

	// Fast paths matching script-guard.sh:144-157.
	if !strings.Contains(command, "frw.d/") {
		return nil, nil
	}
	stripped := shellStripDataRegions(command)
	if !strings.Contains(stripped, "frw.d/") {
		return nil, nil
	}

	if !shellCommandExecutesFrwScript(stripped) {
		return nil, nil
	}
	return []BlockerEnvelope{
		tx.EmitBlocker("script_guard_internal_invocation", map[string]string{
			"command": command,
		}),
	}, nil
}

// shellStripDataRegions removes single-quoted strings, double-quoted
// strings, heredoc bodies, and line comments from a shell command string.
// The result preserves only the unquoted, non-heredoc, non-comment token
// text. Quoted regions are replaced by a single space so adjacent tokens
// remain separated.
//
// Port of the awk implementation in script-guard.sh:35-136. POSIX shell
// quoting semantics are subtle enough that the original implementation
// is still authoritative on edge cases; this Go version aims for byte
// parity on the shapes that exist in real bash commands.
func shellStripDataRegions(command string) string {
	var out strings.Builder
	out.Grow(len(command))

	// Process line by line so heredoc termination is tractable.
	lines := strings.Split(command, "\n")
	state := "normal"
	heredocWord := ""

	for li, line := range lines {
		// Heredoc body: every line until the terminator is suppressed.
		if state == "heredoc" {
			trimmed := strings.TrimSpace(line)
			if trimmed == heredocWord {
				state = "normal"
				heredocWord = ""
			}
			// Suppress the line entirely (still emit the newline for
			// downstream tokenization to keep line offsets coherent).
			if li < len(lines)-1 {
				out.WriteByte('\n')
			}
			continue
		}

		i := 0
		n := len(line)
		for i < n {
			ch := line[i]
			ch2 := ""
			if i+1 < n {
				ch2 = line[i : i+2]
			}

			if state == "normal" {
				// Heredoc start: << or <<-
				if ch2 == "<<" {
					i += 2
					if i < n && line[i] == '-' {
						i++
					}
					for i < n && line[i] == ' ' {
						i++
					}
					hq := byte(0)
					if i < n && (line[i] == '\'' || line[i] == '"') {
						hq = line[i]
						i++
					}
					var hw strings.Builder
					for i < n {
						c := line[i]
						if hq != 0 && c == hq {
							i++
							break
						}
						if hq == 0 && (c == ' ' || c == '\t' || c == ';' || c == '&' || c == '|') {
							break
						}
						hw.WriteByte(c)
						i++
					}
					heredocWord = hw.String()
					state = "heredoc"
					out.WriteByte(' ')
					continue
				}
				if ch == '\'' {
					state = "sq"
					out.WriteByte(' ')
					i++
					continue
				}
				if ch == '"' {
					state = "dq"
					out.WriteByte(' ')
					i++
					continue
				}
				if ch == '#' {
					// Comment: rest of the line is data.
					i = n
					continue
				}
				out.WriteByte(ch)
				i++
				continue
			}
			if state == "sq" {
				if ch == '\'' {
					state = "normal"
					out.WriteByte(' ')
				}
				i++
				continue
			}
			if state == "dq" {
				// Backslash escapes the next char inside double quotes.
				if ch == '\\' && i+1 < n {
					i += 2
					continue
				}
				if ch == '"' {
					state = "normal"
					out.WriteByte(' ')
				}
				i++
				continue
			}
		}
		if li < len(lines)-1 {
			out.WriteByte('\n')
		}
	}
	return out.String()
}

// shellCommandExecutesFrwScript tokenizes the stripped command and
// returns true when any pipeline segment executes a bin/frw.d/ path.
//
// Detection rules (matches script-guard.sh:162-200):
//  1. The first token of a command segment IS a bin/frw.d/ path.
//  2. The first token is sh/bash/zsh/dash/ksh/source/./exec and the
//     first non-flag argument is a bin/frw.d/ path. `sh -n` and
//     `bash -n` are syntax checks, not execution — allowed.
//
// Pipeline separators (`|`, `||`, `&&`, `;`, `&`) split into segments;
// each segment is checked independently.
func shellCommandExecutesFrwScript(stripped string) bool {
	// Collapse multi-char separators into single ";" so a simple split
	// yields command segments.
	canon := stripped
	canon = strings.ReplaceAll(canon, "&&", " ; ")
	canon = strings.ReplaceAll(canon, "||", " ; ")
	canon = strings.ReplaceAll(canon, "|", " ; ")
	canon = strings.ReplaceAll(canon, "&", " ; ")

	for _, segment := range strings.Split(canon, ";") {
		seg := strings.TrimSpace(segment)
		if seg == "" {
			continue
		}
		tokens := tokenize(seg)
		if len(tokens) == 0 {
			continue
		}
		first := tokens[0]
		if strings.Contains(first, "bin/frw.d/") {
			return true
		}
		if isShellInterpreter(first) {
			hasN := false
			for _, t := range tokens[1:] {
				if t == "" {
					continue
				}
				if t == "-n" {
					hasN = true
					continue
				}
				if strings.HasPrefix(t, "-") {
					continue
				}
				// First non-flag argument.
				if strings.Contains(t, "bin/frw.d/") {
					if hasN && (first == "sh" || first == "bash") {
						break
					}
					return true
				}
				break
			}
		}
	}
	return false
}

// tokenize splits on runs of whitespace; matches awk `split($0, tok, /[[:space:]]+/)`.
func tokenize(s string) []string {
	out := make([]string, 0, 4)
	current := strings.Builder{}
	flush := func() {
		if current.Len() > 0 {
			out = append(out, current.String())
			current.Reset()
		}
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
			flush()
			continue
		}
		current.WriteByte(c)
	}
	flush()
	return out
}

func isShellInterpreter(t string) bool {
	switch t {
	case "sh", "bash", "zsh", "dash", "ksh", "source", ".", "exec":
		return true
	}
	return false
}

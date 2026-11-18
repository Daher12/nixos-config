unrarall() {
    emulate -L zsh
    setopt local_options null_glob extended_glob
    local file target rarpass base partnum needs_password
    local -A seen_multi
    local -a files files_to_fix unrar_args skipped_padded
    # Normalize names like:
    #   foo.part01.rar  -> foo.part1.rar
    #   foo.part001.rar -> foo.part1.rar
    files_to_fix=( *.part0##<->.rar )
    if (( ${#files_to_fix} )); then
        print "Found zero-padded multipart archives, normalizing names..."
        for file in "${files_to_fix[@]}"; do
            if [[ $file =~ '^(.*)\.part0+([1-9][0-9]*)\.rar$' ]]; then
                base="${match[1]}"
                partnum="${match[2]}"
                target="${base}.part${partnum}.rar"
                if [[ -e $target ]]; then
                    print -u2 "Skipping rename due to collision: $file -> $target"
                    skipped_padded+=( "$file" )
                    continue
                fi
                mv -- "$file" "$target" || {
                    print -u2 "Rename failed, skipping: $file -> $target"
                    skipped_padded+=( "$file" )
                    continue
                }
            fi
        done
    fi
    if (( ${#skipped_padded} )); then
        print -u2 "Warning: the following zero-padded multipart files were not normalized and will not be extracted:"
        for file in "${skipped_padded[@]}"; do
            print -u2 "  $file"
        done
    fi
    # Add .partN.rar multipart roots
    files=( *.part1.rar )
    for file in "${files[@]}"; do
        seen_multi[${file%.part1.rar}]=1
    done
    # Add old-style numeric multipart roots: name01.rar name02.rar ...
    # Require the character before the "01" digits to be a digit or separator,
    # not a letter — prevents false matches on episode names like "ShowE01.rar"
    for file in *01.rar; do
        [[ $file == *.part01.rar ]] && continue   # handled via part normalisation
        base="${file%01.rar}"
        [[ $base =~ '[0-9._-]$' ]] || continue    # guard: must end in digit or separator
        [[ -e "${base}02.rar" ]] || continue      # lone file – let standalone handle it
        seen_multi[$base]=1
        files+=( "$file" )
    done
    # Add standalone .rar files, excluding multipart pieces and matching multipart roots
    for file in *.rar; do
        [[ $file == *.part<->.rar ]] && continue
        base="${file%.rar}"
        [[ -n ${seen_multi[$base]} ]] && continue
        # Skip non-root parts of old-style numeric sets (e.g. name02.rar)
        if [[ $base =~ '^(.*[^0-9])([0-9]+)$' ]]; then
            [[ -n ${seen_multi[${match[1]}]} ]] && continue
        fi
        files+=( "$file" )
    done
    if (( ! ${#files} )); then
        print -u2 "No matching archives found."
        return 1
    fi
    # Password probe (2026-11-17 orchestrator delta): test each root with no
    # password; only prompt when at least one archive actually needs one, so
    # plain batches run zero-keypress. -p- disables password querying and
    # </dev/null backstops it, so the probe itself can never hang; a probe
    # that misfires (e.g. CRC-broken unencrypted set) merely falls back to
    # the old always-prompt behavior — never worse. Prompt goes to stderr so
    # media-import's stdout tee can't buffer-delay it.
    rarpass=""
    needs_password=0
    for file in "${files[@]}"; do
        if ! command unrar t -p- -y -- "$file" </dev/null >/dev/null 2>&1; then
            needs_password=1
            break
        fi
    done
    if (( needs_password )); then
        print -u2 -n "Enter password (leave empty if none): "
        read -rs rarpass
        print -u2
    fi
    unrar_args=( x -o+ )
    [[ -n $rarpass ]] && unrar_args+=( "-p$rarpass" )
    for file in "${files[@]}"; do
        print "-----------------------------------"
        print "Extracting: $file"
        unrar "${unrar_args[@]}" -- "$file" || print -u2 "Failed: $file"
    done
}

aria() {
  local links_file="/mnt/storage/downloads/links.txt"

  [[ -f "$links_file" ]] || {
    print -u2 "aria: missing $links_file"
    return 1
  }

  # Staging lane (2026-11-17 orchestrator delta): downloads land in
  # incoming/ — the only directory the media-import pipeline touches — so
  # the downloads top level stays a manual parking zone. The -d also kills
  # the old CWD trap.
  mkdir -p "/mnt/storage/downloads/incoming"

  command aria2c \
    -i "$links_file" \
    -d "/mnt/storage/downloads/incoming" \
    -j 2 \
    -x 8 \
    -s 8 \
    --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' \
    --header='Accept-Language: en-US,en;q=0.9' \
    --file-allocation=falloc \
    --enable-mmap=true \
    --no-netrc=true \
    --check-certificate=true \
    --min-tls-version=TLSv1.2 \
    --daemon=true
}

# Self-heal for stuck SGR mouse reporting: a mouse-capable TUI that exits
# ungracefully (ox, btop, nvim, crossterm tools — over SSH) can leave the
# pane in modes 1003+1006; every cursor move then injects ESC[<35;x;yM
# bytes that zsh executes as commands ("command not found: 35;53;37M...").
# Reset at every interactive prompt so a stuck pane clears itself; no-op
# in clean panes.
_reset_mouse_modes() { printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l' }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _reset_mouse_modes

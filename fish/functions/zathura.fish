function __zathura_generate_colors --description 'Generate Zathura colors from Caelestia scheme'
    set scheme_file ~/.local/state/caelestia/scheme.json
    set colors_file ~/.config/zathura/colors.dynamic

    if not test -f $scheme_file
        echo "[zathura $(date '+%H:%M:%S')] ERROR: Scheme file not found!" >&2
        return 1
    end

    echo "[zathura $(date '+%H:%M:%S')] Generating colors" >&2

    set bg (jq -r '.colours.background' $scheme_file)
    set fg (jq -r '.colours.onBackground' $scheme_file)
    set inputbar_bg (jq -r '.colours.surfaceContainer' $scheme_file)
    set inputbar_fg (jq -r '.colours.onSurface' $scheme_file)
    set statusbar_bg (jq -r '.colours.surfaceContainer' $scheme_file)
    set statusbar_fg (jq -r '.colours.onSurface' $scheme_file)
    set highlight_color (jq -r '.colours.primary' $scheme_file)
    set highlight_active (jq -r '.colours.primaryContainer' $scheme_file)
    set notification_error_bg (jq -r '.colours.errorContainer' $scheme_file)
    set notification_error_fg (jq -r '.colours.onErrorContainer' $scheme_file)
    set notification_warning_bg (jq -r '.colours.tertiary' $scheme_file)
    set notification_warning_fg (jq -r '.colours.onTertiary' $scheme_file)
    set notification_bg (jq -r '.colours.successContainer' $scheme_file)
    set notification_fg (jq -r '.colours.onSuccessContainer' $scheme_file)
    set completion_bg (jq -r '.colours.surfaceContainerLow' $scheme_file)
    set completion_fg (jq -r '.colours.onSurface' $scheme_file)
    set completion_highlight_bg (jq -r '.colours.primaryContainer' $scheme_file)
    set completion_highlight_fg (jq -r '.colours.onPrimaryContainer' $scheme_file)
    set index_bg (jq -r '.colours.surface' $scheme_file)
    set index_fg (jq -r '.colours.onSurface' $scheme_file)
    set index_active_bg (jq -r '.colours.primaryContainer' $scheme_file)
    set index_active_fg (jq -r '.colours.onPrimaryContainer' $scheme_file)

    echo "[zathura $(date '+%H:%M:%S')] Colors: bg=#$bg fg=#$fg" >&2

    # Ensure config directory exists
    mkdir -p (dirname $colors_file)

    echo "# Auto-generated Zathura colors from Caelestia scheme" > $colors_file
    echo "# Generated on: $(date)" >> $colors_file
    echo "" >> $colors_file
    echo "set default-bg \"#$bg\"" >> $colors_file
    echo "set default-fg \"#$fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set statusbar-bg \"#$statusbar_bg\"" >> $colors_file
    echo "set statusbar-fg \"#$statusbar_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set inputbar-bg \"#$inputbar_bg\"" >> $colors_file
    echo "set inputbar-fg \"#$inputbar_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set notification-bg \"#$notification_bg\"" >> $colors_file
    echo "set notification-fg \"#$notification_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set notification-error-bg \"#$notification_error_bg\"" >> $colors_file
    echo "set notification-error-fg \"#$notification_error_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set notification-warning-bg \"#$notification_warning_bg\"" >> $colors_file
    echo "set notification-warning-fg \"#$notification_warning_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set highlight-color \"#$highlight_color\"" >> $colors_file
    echo "set highlight-active-color \"#$highlight_active\"" >> $colors_file
    echo "" >> $colors_file
    echo "set completion-bg \"#$completion_bg\"" >> $colors_file
    echo "set completion-fg \"#$completion_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set completion-highlight-bg \"#$completion_highlight_bg\"" >> $colors_file
    echo "set completion-highlight-fg \"#$completion_highlight_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set index-bg \"#$index_bg\"" >> $colors_file
    echo "set index-fg \"#$index_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set index-active-bg \"#$index_active_bg\"" >> $colors_file
    echo "set index-active-fg \"#$index_active_fg\"" >> $colors_file
    echo "" >> $colors_file
    echo "set recolor-lightcolor \"#$bg\"" >> $colors_file
    echo "set recolor-darkcolor \"#$fg\"" >> $colors_file

    echo "[zathura $(date '+%H:%M:%S')] Colors file written" >&2
    return 0
end

function __zathura_watch_colors --description 'Watch for color scheme changes and reload Zathura config'
    set zathura_pid $argv[1]
    set scheme_file ~/.local/state/caelestia/scheme.json
    set dbus_name "org.pwmt.zathura.PID-$zathura_pid"

    echo "[zathura-watcher $(date '+%H:%M:%S')] Started watching $scheme_file for PID $zathura_pid" >&2

    # Watch for changes to the scheme file
    while kill -0 $zathura_pid 2>/dev/null
        # Use inotifywait to efficiently wait for file changes
        # -e modify: watch for modify events
        # -e close_write: watch for file close after writing
        # -t 5: timeout after 5 seconds to check if process still exists
        inotifywait -qq -e modify -e close_write -t 5 $scheme_file 2>/dev/null

        # Check if inotifywait actually detected a change (exit code 0)
        if test $status -eq 0
            echo "[zathura-watcher $(date '+%H:%M:%S')] Color scheme changed, regenerating..." >&2

            # Regenerate colors
            if __zathura_generate_colors
                # Small delay to ensure file is fully written
                sleep 0.1

                # Reload config via D-Bus
                echo "[zathura-watcher $(date '+%H:%M:%S')] Reloading Zathura config via D-Bus" >&2
                dbus-send --session --print-reply --dest=$dbus_name \
                    /org/pwmt/zathura org.pwmt.zathura.SourceConfig 2>&1 | \
                    grep -q "boolean true" && \
                    echo "[zathura-watcher $(date '+%H:%M:%S')] Config reloaded successfully" >&2 || \
                    echo "[zathura-watcher $(date '+%H:%M:%S')] Failed to reload config" >&2
            end
        end
    end

    echo "[zathura-watcher $(date '+%H:%M:%S')] Zathura process ended, stopping watcher" >&2
end

function __docx_to_pdf_fast --description 'DOCX→PDF with minimal deps'
    set docx $argv[1]
    set outpdf $argv[2]

    set tmp (mktemp -d)
    set html "$tmp/doc.html"
    set pdf  "$tmp/out.pdf"

    # 1) DOCX → HTML (Mammoth)
    if not type -q mammoth
        echo "[zathura] ERROR: mammoth not found; try 'pipx install mammoth' or 'npm i -g mammoth'" >&2
        return 1
    end
    mammoth --output-format=html "$docx" > "$html" 2>/dev/null
    or begin
        echo "[zathura] ERROR: mammoth failed." >&2
        return 1
    end

    # 2) HTML → PDF (headless browser)
    set browser ""
    for b in chromium google-chrome google-chrome-unstable brave
        if type -q $b
            set browser $b
            break
        end
    end
    if test -z "$browser"
        echo "[zathura] ERROR: need chromium/google-chrome/brave on PATH for HTML→PDF." >&2
        return 1
    end

    $browser --headless --disable-gpu --no-sandbox --print-to-pdf="$pdf" "file://$html" >/dev/null 2>&1
    or begin
        echo "[zathura] ERROR: headless $browser print failed." >&2
        return 1
    end

    mv "$pdf" "$outpdf"
    command rm -rf "$tmp"
    return 0
end

function zathura --wraps zathura --description 'Launch Zathura with auto-updated colors from Caelestia scheme'
    echo "[zathura $(date '+%H:%M:%S')] Starting" >&2

    # Generate initial colors
    __zathura_generate_colors

    # Check if the first argument is a .docx file
    set file_to_open $argv[1]
    if test -n "$file_to_open" -a -f "$file_to_open" -a (string match -r '\.docx$' "$file_to_open")
        echo "[zathura $(date '+%H:%M:%S')] Converting .docx to PDF" >&2
        set pdf_file (mktemp --suffix=.pdf)
        if __docx_to_pdf_fast "$file_to_open" "$pdf_file"
            echo "[zathura $(date '+%H:%M:%S')] Conversion successful, opening PDF" >&2
            set file_to_open $pdf_file
        else
            echo "[zathura $(date '+%H:%M:%S')] Conversion failed, opening original file" >&2
        end
    end

    # Launch Zathura
    echo "[zathura $(date '+%H:%M:%S')] Launching zathura" >&2
    command zathura $file_to_open $argv[2..-1] &
    set zathura_pid (jobs -lp | tail -1)

    # Start background watcher for this instance
    if test -n "$zathura_pid"
        echo "[zathura $(date '+%H:%M:%S')] Starting color watcher for PID $zathura_pid" >&2
        # Source the function file and then run the watcher
        fish -c "source ~/.config/fish/functions/zathura.fish; __zathura_watch_colors $zathura_pid" >&2 &
        disown
    end

    disown $zathura_pid 2>/dev/null
end
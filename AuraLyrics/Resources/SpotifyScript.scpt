use framework "Foundation"

try
	tell application "Spotify"
		if not running then
			return "NOT_RUNNING"
		end if
		
		set tName to name of current track
		set tArtist to artist of current track
		set tAlbum to album of current track
		set tDuration to (duration of current track) / 1000.0 -- Convert ms to seconds
		set tPosition to player position -- Already in seconds
		set tState to player state as string
		
		-- Delimiter: |||
		set resultString to tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDuration & "|||" & tPosition & "|||" & tState
		return resultString
	end tell
on error errMsg
	return "ERROR|||" & errMsg
end try

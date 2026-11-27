tell application "/System/Library/CoreServices/Finder.app"
	if not (exists Finder window 1) then error number 1000
	set folderTarget to target of Finder window 1
	set targetClass to class of folderTarget
	-- Finder names its desktop-object class cdsk in Apple events.
	if targetClass is not folder and targetClass is not disk and targetClass is not «class cdsk» then error number 1001
	return URL of folderTarget
end tell

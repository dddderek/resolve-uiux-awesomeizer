;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Davinci Resolve Fusion Macros
; 12/25/2020 carlson.derek@gmail.com
;
; Based on the work of beau@beaugilles.com.  Much gratitude to that dude,
; Beau Gilles is to macros what Michael Jordan is to basketball.
;
; Testing GIT updates.
;
; Direct Macros:
;   snapPlayheadToMousePosition - works on both Edit and Fusion pages
;   fusionToggleSPLINEWindowSizeState
;   fusionOrEditToggleNODEorTIMELINEWindowSizeState - toggles size of either
;       Node window in Fusion or Timeline on Edit Page
;   fusionViewerZoom400
;   fusionNodeScaleToFit
;   dualScreenFullTimeline - switches between two workspace "Layout Presets"
;   	Requires first that presets are created called exactly FTFV and Reg
;
; Helper Functions
;   clickOnMenuItem [png image of menu item]
;   myFindImage [png image filename]
;   whichResolvePage - returns "edit", "fusion", or "none"
;   findPlayheadPosn - returns hash {x, y}, e.g. array["x"]
;
; Basic Utility Functions
;   dp - debug print
;   blockMouseMove
;	getActiveWinCoords - returns hash {Left, Top, Width, Height}, e.g. array["Left"]
;
; TODO:
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

CoordMode, Mouse, Screen

global LOCKOUT_USER_FROM_USING_MOUSE = false ; set to false to not get locked out
                                             ; during debugging and have to always reboot (!)
											 ; (wonder who's done that?)
global GIVE_OR_TAKE_YO := 8 ; buffer everything in case size is slighty different on different machines
global SLOW_IT_DOWN_MS := 100

; As long as commands are in one line below, each line contains an implicit return
; so they aren't all run together.
#IfWinActive ahk_exe Resolve.exe
{
	!x::snapPlayheadToMousePosition()       ; ALT+x works on both Edit and Fusion pages!  Sweet!
	!d::fusionOrEditToggleNODEorTIMELINEWindowSizeState()   ; ALT+d "d" for noDe - clever!  Works on both Edit and Fusion pages!  Bro!
	!s::fusionToggleSPLINEWindowSizeState() ; ALT+s "s" for Spline - low hanging fruit.
	^4::fusionViewerZoom400()               ; CTRL+4
	!f::fusionNodeScaleToFit()              ; ALT+f (CTRL-F is "Find" in Fusion)
	!w::dualScreenFullTimeline()            ; ALT+w
}

; NOTE: On Edit page, if you click on timeline over a clip, it will select the clip and when you
; have the program click-drag it will resize the darn clip!  Doh!  So we jump to the area 26
; pixels below the playhead which works but is above all clips in the Edit window.  And this
; isn't a concern in the Fusion window.
snapPlayheadToMousePosition()
{
	blockMouseMove()
	MouseGetPos, mXPos, mYPos

	PlayheadPosn := findPlayheadPosn()

	dp("snapPlayheadToMousePosition(): arPlayheadPosn = (" . PlayheadPosn["x"] . ", " . PlayheadPosn["y"] . ")")
	if (PlayheadPosn["x"] > 0) {
		dp("Moving playhead!")
		MouseClick, Left, PlayheadPosn["x"], PlayheadPosn["y"] + 26, ,0, D
		MouseMove, mXPos, mYPos, 0
		BlockInput, MouseMoveOff
		;Hold mouse click down while hotkey is pressed (this is needed, no idea why)
		if (hold == True)
			keywait, %A_ThisHotkey%
		Click, up
	}

	BlockInput, MouseMoveOff
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SPLINE WINDOW in FUSION: expander and contractor
;
; Each time called, toggles between Maximize, Minimized, and Half-Size
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fusionToggleSPLINEWindowSizeState()
{
	dp("")
	dp("")
	dp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
	dp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
	dp("START: SPLINE Window Expander Contractor")
	dp("")
	dp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")

	WC := getActiveWinCoords()
	
	; Below is when the resolve window is maximized to full screen
	;
	; Screen 1: Actual 0, 0         1367 Wide,               727 Tall (not including task bar)   
	;     WinGetPos returns -8, -8  1382 Wide (15 too wide), 744 Tall (17 too tall)
	;     So window actual top Y is WinGetPos + 8
	;     And actual left if WinGetPos + 8
	;
	; Screen 2: Actual 1366, 0        1439 Wide              , 899 Tall
	;     WinGetPos returns 1358, -8  1456 Wide (17 too wide), 876 Tall (23 too short)
	;     So window actual top Y is WinGetPos + 8
	;     And actual left if WinGetPos + 8
	;
	; NOTE: The amount that the width and height are off changes with regard to the size of the window - yikes!

	; WEIRD!  Now regardless of maximized or not, or how wide the window is (even 2 screens wide), WinWidth is always
	; 10 pixels too big.  Hmmm.
	; Full discussion of this issue at: https://www.autohotkey.com/boards/viewtopic.php?f=76&t=9620&hilit=dpiscale
	NumPixelsTooWideAsPerWinGetPos := 10

	; distance from top left of leftmost icon on the bottom of the spline editor (looks like a quarter circle 9PM - 12AM)
	; to the vertical bar that you hover over to shrink or expand that window
	XDistLeftIconToMoveBar := 19

	blockMouseMove()
	MouseGetPos, mXPos, mYPos

	; Search for leftmost icon on the bottom of the spline editor (looks like a quarter circle 9PM - 12AM)
	; It's within 62 pixels of the bottom of the window on my system.  So search within the last 100 pixels.
	ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"] + WC["Height"] - 100, WC["Left"] 
		+ WC["Width"], WC["Top"] + WC["Height"], FusionPage_SplineLightGreyIcon.png

	; The icon can be dark or light depending on whether a point is selected.  Could do a 
	; fuzzy image search, but considering one has values like 75 and the other 131, that fuzzy
	; of a search might hit false positives.  Thus, search 2 images if needbe!
	if (ErrorLevel = 1) {
		ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"] + WC["Height"] - 100, WC["Left"] 
			+ WC["Width"], WC["Top"] + WC["Height"], FusionPage_SplineDarkGreyIcon.png
	}

	if (ErrorLevel = 2) {
    	dp("Unable to conduct ImageSearch for FusionPage_SplineIcon.png.")
		BlockInput, MouseMoveOff
		Return
	} else if (ErrorLevel = 1) {
		;
		; RESTORE SPLINE WINDOW
		;
		; Icon not found, meaning spline window is minimized or completely put away.
		; Assume it's minimized and attempt to pull it to middle of screen.
		;
    	;MsgBox, % "FusionPage_SplineIcon.png could not be found on the screen."
		dp("FusionPage_SplineIcon.png icon not found, so window gone or mimized.  Attempt to restore to mid-screen.")
		dp("(FoundX - XDistLeftIconToMoveBar) - WinLeft: " . ((FoundX - XDistLeftIconToMoveBar)-WC["Left"] ), "indent")

		SafeOffsetFromBottomOfScreen := 100

		; The -5 below moves us into the light grey area just to the right of the vertical black bar 0x090909 that
		; represents the totally collapsed spline window and the bar that you click on to expand it
		; Below left commented out for testing
		; MouseMove, WinLeft + WinWidth - NumPixelsTooWideAsPerWinGetPos - 5, WinTop + WinHeight - SafeOffsetFromBottomOfScreen, 0

		; The -13 below is the distance left to search for the black vertical line.  The entire width of that area
		; is only 13 pixels wide, so this should be safe, and the -5 puts us into the middle of those 13 pixels.
		; This is needed because (WinLeft + WinWidth - NumPixelsTooWideAsPerWinGetPos) is not accurate because
		; WinGetPos returns the wrong WinWidth, but the amount it is wrong by differs based on actual window width.
		; (WinLeft + WinWidth - NumPixelsTooWideAsPerWinGetPos) sometimes is perfect, but if the window gets wider
		; then it shoots too far and we have to pixelsearch back left to find the black vertical line colored 0x090909
		; UPDATE: WinWidth no longer seems to be changing with window actual width.  That number is always reported as 10 too big.
		PixelSearch, xPos, yPos, WC["Left"]  + WC["Width"]  - NumPixelsTooWideAsPerWinGetPos - 5
		  , WC["Top"]  + WC["Height"]  - SafeOffsetFromBottomOfScreen
		  , mXPos-13, WC["Top"]  + WC["Height"] - SafeOffsetFromBottomOfScreen, 0x090909, 0, Fast RGB
		
		; MouseMove, xPos, WinTop + WinHeight - SafeOffsetFromBottomOfScreen, 0 ;
		MouseClick, Left, xPos, WC["Top"] + WC["Height"] - SafeOffsetFromBottomOfScreen, , 0, D
		MouseMove, WC["Left"] + (WC["Width"] / 2), WC["Top"] + WC["Height"] - SafeOffsetFromBottomOfScreen, 0
		Click, up 
		MouseMove, mXPos, mYPos, 0
		BlockInput, MouseMoveOff
		dp("Done! Spline window now restored to mid-screen.")
		return
	} else {
    	dp("The FusionPage_SplineIcon.png icon was found at (" . FoundX . ", " . FoundY . ")")
	}

	; The bar on my system is 12 pixels from left side of window
	; FoundX = 32 when spline window maximized
	; 19 pixels left to vertical move bar: 32 - 19 = 13 pixels from left of window
	; BUT WinGetPos incorrectly says left location is 8 too far left
	; so 13 + 8 = 21 pixels 
	; On screen 2:
	; FoundX: 1398
	; XDistLeftIconToMoveBar: 19
	; WinLeft: 1358
	; 1398 - 19 = 1379 - 1358 = 21
	dp("FoundX: " . FoundX, "indent")
	dp("XDistLeftIconToMoveBar: " . XDistLeftIconToMoveBar, "indent")
	dp("WinLeft: " .  WC["Left"], "indent")
	dp("((FoundX - XDistLeftIconToMoveBar)-WinLeft): " . ((FoundX - XDistLeftIconToMoveBar)- WC["Left"]), "indent")
	If (((FoundX - XDistLeftIconToMoveBar)- WC["Left"]) < (21 + GIVE_OR_TAKE_YO))
	{
		;
		; MINIMIZE SPLINE WINDOW
		;
		dp("Spline window is maximized, so minimize it.")	
		; MouseClick , WhichButton, X, Y, ClickCount, Speed, DownOrUp, Relative
		; MouseMove, X ,Y , Speed, Relative
		MouseClick, Left, FoundX - XDistLeftIconToMoveBar, FoundY, , 0, D
		MouseMove,  WC["Left"] +  WC["Width"], FoundY, 0
		Click, up 
		MouseMove, mXPos, mYPos, 0
		BlockInput, MouseMoveOff
		dp("Done! Spline window now minimized.")	
		Return
	}
	;
	; MAXIMIZE SPLINE WINDOW
	;
	dp("Spline window is in the middle, so maximize it.")	

	; MouseClick , WhichButton, X, Y, ClickCount, Speed, DownOrUp, Relative
	; MouseMove, X ,Y , Speed, Relative
	MouseClick, Left, FoundX - XDistLeftIconToMoveBar, FoundY, , 0, D
	MouseMove,  WC["Left"], FoundY, 0
	Click, up 
	MouseMove, mXPos, mYPos, 0
	BlockInput, MouseMoveOff
	dp("Spline window is now maximized.")	

	Return
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; NODE WINDOW in FUSION: expander and contractor
;
; Each time called, toggles between Maximize, Minimized, and Half-Size
;
; Also works with Timeline on Edit page (so we can use ALT+D to 
; habitually maximize the main window we're working with)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fusionOrEditToggleNODEorTIMELINEWindowSizeState()
{
	dp("")
	dp("")
	dp("")
	dp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
	dp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
	dp("START: NODE Window Expander Contractor")
	dp("")
	dp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")

	if (whichResolvePage() = "edit") {
		editPageToggleTimelineSize()
		Return
	}

	WC := getActiveWinCoords()

	blockMouseMove()
	MouseGetPos, mXPos, mYPos

	; https://www.autohotkey.com/docs/commands/ImageSearch.htm
	; Find little SQUARE "Stop Button" as a reference for the horizontal line that adjusts Node window height
	ImageLoc := myFindImage("FusionPage_StopIcon.png")
	if (ImageLoc["x"] < 1) {
		dp("fusionOrEditToggleNODEorTIMELINEWindowSizeState(): Unable to find FusionPage_StopIcon.png.  Exiting.")
		Return
	}
	dp("The FusionPage_StopIcon.png icon was found at (" . ImageLoc["x"] . ", " . ImageLoc["y"] . ")", "indent")
	FoundX := ImageLoc["x"]
	FoundY := ImageLoc["y"]

	; The horizontal Node Window resize bar is always 54 pixels above the STOP button graphic
	; (Note, the STOP button graphic contains 7 pixels above the actual STOP button)
	; MouseMove, FoundX, FoundY - 54, 0 
	MoveBarPixelsAboveStopIcon := 54

	; Below used to determine when Node window is maximized
	MoveBarPixelsBelowTopOfScreen := 132

	; Below used to determine when Node window is minimized (it's actually 192 on my system)
	MoveBarPixelsAboveBottomOfScreen := WC["Top"] + WC["Height"] - (192 + GIVE_OR_TAKE_YO)

	; If FoundY < (MoveBarPixelsBelowTopOfScreen + GIVE_OR_TAKE_YO) (on my system, it's 132 when Node Window totally maximized), then minimize it
	if (FoundY < (MoveBarPixelsBelowTopOfScreen + GIVE_OR_TAKE_YO)) {
		dp("(Node) Currently maximized, so MINIMIZING!  (STOP icon found < " . (MoveBarPixelsBelowTopOfScreen + GIVE_OR_TAKE_YO) . " pixels)")
		MouseClick, Left, FoundX, FoundY - MoveBarPixelsAboveStopIcon, , 0, D
		MouseMove, FoundX, WC["Height"], 0
		Click, up 
		MouseMove, mXPos, mYPos, 0
	} else if (FoundY > MoveBarPixelsAboveBottomOfScreen) { ; viewer window is maximized, so restore Node window to 1/2 way
		dp("(Node) Currently minimized, so RESTORING.")
		MouseClick, Left, FoundX, FoundY - MoveBarPixelsAboveStopIcon, , 0, D
		MouseMove, FoundX, WC["Height"] / 2 - 67, 0 ; 67 just gives me a little more room in the node/spline window area
		Click, up 
		MouseMove, mXPos, mYPos, 0
	} else {
		dp("(Node) Currently normal, so MAXIMIZING.")
		MouseClick, Left, FoundX, FoundY - 54, , 0, D
		MouseMove, FoundX, 0, 0
		Click, up 
		MouseMove, mXPos, mYPos, 0
	}
	BlockInput, MouseMoveOff
}

fusionViewerZoom400()
{
	click, right
	send {Down}
	send {Right}
	send {Down}
	send {Down}
	send {Down}
	send {Down}
	send {Down}
	send {Down}
	send {Down}
	send {Down}
	send {Enter}
}

fusionNodeScaleToFit()
{
	click, right
	send {Down}
	send {Down}
	send {Right}
	send {Down}
	send {Enter}
}

dualScreenFullTimeline()
{
	blockMouseMove()
	MouseGetPos, mXPos, mYPos
	
	arWorkspaceMenuPosn := []
	arWorkspaceMenuPosn := myFindImage("MenuItem_Workspace.png")
	if (arWorkspaceMenuPosn["x"] < 1) {
		dp("dualScreenFullTimeline(): Unable to find Workspace menu location.  Exiting.")
		Return
	}
	dp("The MenuItem_Workspace.png icon was found at (" . arWorkspaceMenuPosn["x"] . ", " . arWorkspaceMenuPosn["y"] . ")", "indent")

	arEditPageLittleZoomMinusPosn := []
	arEditPageLittleZoomMinusPosn := myFindImage("EditPage_LittleZoomMinus.png")
	if (arEditPageLittleZoomMinusPosn["x"] < 1) {
		dp("dualScreenFullTimeline(): Unable to find EditPage_LittleZoomMinus.png.  Exiting.")
		Return
	}
	dp("The EditPage_LittleZoomMinus.png icon was found at (" . arEditPageLittleZoomMinusPosn["x"] . ", " . arEditPageLittleZoomMinusPosn["y"] . ")", "indent")

	; If < 130 then we're currently in dual-screen
	if (arEditPageLittleZoomMinusPosn["y"] < 130) {
		dp("Turning off dual-screen.")
		; Make Workspace menu appear
		MouseClick, Left, arWorkspaceMenuPosn["x"] + 37, arWorkspaceMenuPosn["y"] + 9, , 1
		sleep, 100  ; give time for menu to appear on screen
		clickOnMenuItem("MenuItem_LayoutPresets.png")
		sleep, 100  
		clickOnMenuItem("MenuItem_Reg.png")
		sleep, 400  
		clickOnMenuItem("MenuItem_LoadPreset.png")
		
	} else {
		dp("Selecting first Layout Preset.")

		; Make Workspace menu appear
		MouseClick, Left, arWorkspaceMenuPosn["x"] + 37, arWorkspaceMenuPosn["y"] + 9, , 1
		sleep, 100  ; give time for menu to appear on screen
		clickOnMenuItem("MenuItem_LayoutPresets.png")
		sleep, 100  
		clickOnMenuItem("MenuItem_FTFV.png")
		sleep, 400  
		clickOnMenuItem("MenuItem_LoadPreset.png")
	}

	MouseMove mxPos, myPos, 0 ; put mouse back to where it started at 
	BlockInput, MouseMoveOff
}

; Makes timeline as tall as possible, or restores it to 1/2 screen
editPageToggleTimelineSize()
{
	dp("EDIT PAGE: Toggling Timeline size, like a boss!")

	MouseGetPos, mXPos, mYPos

	WC := getActiveWinCoords()

	; Find little zoom 'minus' icon as a reference for the horizontal line that adjusts timeline window height
	ImageLoc := myFindImage("EditPage_LittleZoomMinus.png")
	if (ImageLoc["x"] < 1) {
		dp("editPageToggleTimelineSize(): Unable to find EditPage_LittleZoomMinus.png.  Exiting.")
		Return
	}
	dp("The EditPage_LittleZoomMinus.png icon was found at (" . ImageLoc["x"] . ", " . ImageLoc["y"] . ")", "indent")
	FoundX := ImageLoc["x"]
	FoundY := ImageLoc["y"]

	if (FoundY < 280)
	{
		dp("(Timeline) Currently maximized, so restoring to 1/2.  Little minus icon found at y = " . FoundY)
		MouseClick, Left, FoundX, FoundY - 18, , 0, D ; horiz move bar about 18 pixels above minus icon
		MouseMove, FoundX, WC ["Top"] + WC["Height"] / 2, 0
		Click, up 
		MouseMove, mXPos, mYPos, 0
	} else {
		dp("(Timeline) Currently normal position, so maximizing.  Little minus icon found at y = " . FoundY)
		MouseClick, Left, FoundX, FoundY - 18, , 0, D ; horiz move bar about 18 pixels above minus icon
		MouseMove, FoundX, 0, 0
		Click, up 
		MouseMove, mXPos, mYPos, 0
	}

}

clickOnMenuItem(filename)
{
	ImageLoc := myFindImage(filename)
	if (ImageLoc["x"] < 1) {
		dp("clickOnMenuItem(): Unable to find image " . filename . " on screen.  Exiting.")
		Return
	}
	dp("The " . filename . " image was found at (" . ImageLoc["x"] . ", " . ImageLoc["y"] . ")", "indent")
	MouseClick, Left, ImageLoc["x"] + 37, ImageLoc["y"] + 9, , 1
}

myFindImage(filename)
{
	WC := getActiveWinCoords()

	; https://www.autohotkey.com/docs/commands/ImageSearch.htm
	dp("myFindImage(): Searching for: " . filename)
	ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"],  WC["Left"] + WC["Width"], WC["Top"] + WC["Height"], %filename% ; *3
	dp("myFindImage(): After ImageSearch, ErrorLevel: " . ErrorLevel)
	if (ErrorLevel = 2) {
		dp("Unable to conduct ImageSearch for " . filename)
		BlockInput, MouseMoveOff
		Return {x: -1, y: -1}
	} else if (ErrorLevel = 1) {
		s := "ACK!  Could not be found on the screen: " . filename
		dp(s)
		Return {x: -1, y: -1}
	} else {
		dp(filename . " image found at (" . FoundX . ", " . FoundY . ")", "indent")
		return {x: FoundX, y: FoundY}
	}
}

; Returns "edit", "fusion", or "none"
; Figures this out by searching for a page-specific icon on the screen to
; tell which page we are on.
; I used random search images.  If needed in the future for speed,
; use the bottom images on the bottom bar of Resolve which are
; uniquely highlighted when a certain Resolve page is active
whichResolvePage()
{
	WC := getActiveWinCoords()

	; First, seach to see if on Edit page
	ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"],  WC["Left"] + WC["Width"], WC["Top"] + WC["Height"], Identifier_EditPageIcon.png

	if (ErrorLevel = 2) {
    	dp("whichResolvePage(): Unable to conduct ImageSearch while searching for Identifier_EditPageIcon.png")
		Return
	} else if (ErrorLevel = 1) {
		; Not found, do nothing
	} else {
    	dp("whichResolvePage(): The Identifier_EditPageIcon.png icon was found at (" . FoundX . ", " . FoundY . ").  Returning ""edit""")
		return "edit"
	}

	; Next, seach to see if on Fusion page
	ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"],  WC["Left"] + WC["Width"], WC["Top"] + WC["Height"], Identifier_FusionPageIcon.png

	if (ErrorLevel = 2) {
    	dp("whichResolvePage(): Unable to conduct ImageSearch while searching for Identifier_FusionPageIcon.png")
		Return
	} else if (ErrorLevel = 1) {
		; Not found, do nothing
	} else {
    	dp("whichResolvePage(): The Identifier_FusionPageIcon.png icon was found at (" . FoundX . ", " . FoundY . ").  Returning ""fusion""")
		return "fusion"
	}

	dp("whichResolvePage(): Unable to recognize which page we are currently on.  Doh!")
	return "unknown"
}

; Does not call whichResolvePage - too slow.  Instead, assumes Fusion and checks there first.
; if can't find it there, assumes Edit page.
;
; Get the x,y coordinates for the centerline of the playhead.  Works on Edit and Fusion pages alike.  Returns an array.
findPlayheadPosn()
{
	WC := getActiveWinCoords()

	dp("")
	dp("START findPlayheadPosn()")

	; Search fusion first because more often doing this there

	; NOTE: 12/26 Changed FusionPage_PlayheadIcon.png to all red, no black borders because the border shades were 07, 08, 0d, 0e...
	; 08 - 0e are 8 shades apart.  So this all red one (every single pixel 0xE64B3D) is what I am using now
	; and thus far it works for both Fusion and Edit pages.  This is fastest, because it doesn't need to try twice sometimes.
	; If solid red images in the viewer screw this up, go back to playhead images that have the black borders on top
	; and/or on the sides.  But will need to write something like: , *10 FusionPage_PlayheadIcon.png
	; See: https://www.autohotkey.com/docs/commands/ImageSearch.htm (the *n part under ImageFile)

	ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"],  WC["Left"] + WC["Width"], WC["Top"] + WC["Height"], FusionPage_PlayheadIcon.png
	dp("ImageSearch (FusionPage_PlayheadIcon.png) ErrorLevel: " . ErrorLevel)
	if (ErrorLevel = 2) {
    	dp("findPlayheadPosn(): Unable to conduct ImageSearch while searching for FusionPage_PlayheadIcon.png")
		Return {x: -1, y: -1}
	} else if (ErrorLevel = 1) {
		; 12/26 Should never get here, because the solid read playhead search reference image matches the playhead
		; on both pages.
		ImageSearch, FoundX, FoundY, WC["Left"], WC["Top"],  WC["Left"] + WC["Width"], WC["Top"] + WC["Height"], EditPage_PlayheadIcon.png
		dp("ImageSearch (EditPage_PlayheadIcon.png) ErrorLevel: " . ErrorLevel)
		if (ErrorLevel = 2) {
			dp("findPlayheadPosn(): Unable to conduct ImageSearch while searching for EditPage_PlayheadIcon.png")
			Return {x: -1, y: -1}
		} else if (ErrorLevel = 1) {
			dp("findPlayheadPosn(): Can't look for playhead because we're not on either Edit or Fusion page.  Returning -1.")
			Return {x: -1, y: -1}
		}
		dp("EDIT PAGE!!! We're on it!!!  Sweeeeeet!")
    	dp("findPlayheadPosn(): The EditPage_PlayheadIcon.png icon was found at (" . (FoundX + 6) . ", " . FoundY . ").")
		Return {x: FoundX + 6, y: FoundY} ; 6 is distance from left side of playhead icon image to its centering
	} else {
		dp("FUSION PAGE!!! We're on it!!!  Sweeeeeet!")
    	dp("findPlayheadPosn(): The FusionPage_PlayheadIcon.png icon was found at (" . (FoundX + 6) . ", " . FoundY . ").")
		Return {x: FoundX + 6, y: FoundY} ; 6 is distance from left side of playhead icon image to its centering
	}	
}

; dp Debug Print (need to run Dbgview.exe as administrator to view the output)
; print debug string to DebugView window, prepending AHK| so can be filtered
; https://docs.microsoft.com/en-us/sysinternals/downloads/debugview
; Edit | Filter|Highlight - set to Include:AHK* to see only AHK output
dp(s, indent := "no") 
{
	if (indent = "no") {
		OutputDebug % "AHK| " . s
	} else {
		OutputDebug % "AHK|        " . s
	}
}

blockMouseMove()
{
	if LOCKOUT_USER_FROM_USING_MOUSE {
		BlockInput, MouseMove
		; The problem with this is if you forget to remove the block and your script
		; exits, then you don't have access to your mouse at all in Windows and you have
		; to log out or reboot to get your darn mouse back!  So I'm leaving this
		; off unless I find that I need to use it.
	}
}

getActiveWinCoords()
{
	CoordMode, Pixel, Screen ; required to make it work on 2nd monitor, otherwise xPos
							 ; was relative to the current monitor and therefore was off 
							 ; (in PixelSearch terms) by the width of the first monitor,
							 ; which was 1368 on my machine

	; WinGetPos , X, Y, Width, Height, WinTitle, WinText, ExcludeTitle, ExcludeText
	SetTitleMatchMode 2 ; name specified can appear anywhere in the Title
	WinGetPos, WinLeft, WinTop, WinWidth, WinHeight, Resolve
	dp("Resolve Window Left, Top Corner: (" . WinLeft . "," . WinTop . ") Width = " 
	  . WinWidth . ", Height = " . WinHeight, "indent")

	return {Left: WinLeft, Top: WinTop, Width: WinWidth, Height: WinHeight}
}
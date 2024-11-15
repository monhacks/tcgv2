HandlePrinterMenu:
	farcall PreparePrinterConnection
	ret c
	xor a
.loop
	ld hl, PrinterMenuParameters
	call InitializeMenuParameters
	call EmptyScreenAndLoadFontDuelAndDeckIcons
	lb de, 4, 0
	lb bc, 12, 12
	call DrawRegularTextBox
	lb de, 6, 2
	ldtx hl, PrintMenuItemsText
	call InitTextPrinting_ProcessTextFromID
	ldtx hl, WhatWouldYouLikeToPrintText
	call DrawWideTextBox_PrintText
	call EnableLCD
.loop_input
	call DoFrame
	call HandleMenuInput
	jr nc, .loop_input
	ldh a, [hCurMenuItem]
	cp $ff
	call z, PrinterMenu_QuitPrint
	ld [wSelectedPrinterMenuItem], a
	ld hl, PrinterMenuFunctionTable
	call JumpToFunctionInTable
	ld a, [wSelectedPrinterMenuItem]
	jr .loop

PrinterMenuParameters:
	db 5, 2 ; cursor x, cursor y
	db 2 ; y displacement between items
	db 5 ; number of items
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw NULL ; function pointer if non-0

PrinterMenuFunctionTable:
	dw PrinterMenu_PokemonCards
	dw PrinterMenu_DeckConfiguration
	dw PrinterMenu_CardList
	dw PrinterMenu_PrintQuality
	dw PrinterMenu_QuitPrint


PrinterMenu_PokemonCards:
	call WriteCardListsTerminatorBytes
	call PrintPlayersCardsHeaderInfo
	xor a
	ld [wCardListVisibleOffset], a
	ld [wCurCardTypeFilter], a
	call PrintFilteredCardSelectionList
	call EnableLCD
	xor a
	ld hl, FiltersCardSelectionParams
	call InitCardSelectionParams

.loop_frame_1
	call DoFrame
	ld a, [wCurCardTypeFilter]
	ld b, a
	ld a, [wTempCardTypeFilter]
	cp b
	jr z, .handle_input
	ld [wCurCardTypeFilter], a
	ld hl, wCardListVisibleOffset
	ld [hl], $00
	call PrintFilteredCardSelectionList
	ld hl, hffb0
	ld [hl], $01
	call PrintPlayersCardsText
	ld hl, hffb0
	ld [hl], $00
	ld a, NUM_FILTERS
	ld [wCardListNumCursorPositions], a
.handle_input
	ldh a, [hDPadHeld]
	and D_DOWN
	jr z, .asm_abca
; dpad_down
	call ConfirmSelectionAndReturnCarry
	jr .asm_abd7
.asm_abca
	call HandleCardSelectionInput
	jr nc, .loop_frame_1
	ldh a, [hffb3]
	cp $ff
	ret z
;	fallthrough

.asm_abd7
	ld a, [wNumEntriesInCurFilter]
	or a
	jr z, .loop_frame_1

	xor a
	ld hl, Data_a396
	call InitCardSelectionParams
	ld a, [wNumEntriesInCurFilter]
	ld [wNumCardListEntries], a
	ld hl, wNumVisibleCardListEntries
	cp [hl]
	jr nc, .asm_abf6
	ld [wCardListNumCursorPositions], a
	ld [wTempCardListNumCursorPositions], a
.asm_abf6
	ld hl, wCardListUpdateFunction
	ld a, LOW(PrintCardSelectionList)
	ld [hli], a
	ld a, HIGH(PrintCardSelectionList)
	ld [hl], a
	xor a
	ld [wced2], a

.loop_frame_2
	call DoFrame
	call HandleSelectUpAndDownInList
	jr c, .loop_frame_2
	call HandleDeckCardSelectionList
	jr c, .asm_ac60
	ldh a, [hDPadHeld]
	and START
	jr z, .loop_frame_2
; start button
	ld a, $1
	call PlaySFXConfirmOrCancel_Bank2
	ld a, [wCardListNumCursorPositions]
	ld [wTempCardListNumCursorPositions], a
	ld a, [wCardListCursorPos]
	ld [wTempCardListCursorPos], a

	; set wFilteredCardList as the current card list
	; and show the card page screen
	ld de, wFilteredCardList
	ld hl, wCurCardListPtr
	ld [hl], e
	inc hl
	ld [hl], d
	call OpenCardPageFromCardList
	call PrintPlayersCardsHeaderInfo

.asm_ac37
	ld hl, FiltersCardSelectionParams
	call InitCardSelectionParams
	ld a, [wCurCardTypeFilter]
	ld [wTempCardTypeFilter], a
	call DrawHorizontalListCursor_Visible
	call PrintCardSelectionList
	call EnableLCD
	ld hl, Data_a396
	call InitCardSelectionParams
	ld a, [wTempCardListNumCursorPositions]
	ld [wCardListNumCursorPositions], a
	ld a, [wTempCardListCursorPos]
	ld [wCardListCursorPos], a
	jr .loop_frame_2

.asm_ac60
	call DrawListCursor_Invisible
	ld a, [wCardListNumCursorPositions]
	ld [wTempCardListNumCursorPositions], a
	ld a, [wCardListCursorPos]
	ld [wTempCardListCursorPos], a
	ldh a, [hffb3]
	cp $ff
	jr nz, .asm_ac92

	ld hl, FiltersCardSelectionParams
	call InitCardSelectionParams
	ld a, [wCurCardTypeFilter]
	ld [wTempCardTypeFilter], a
	ld hl, hffb0
	ld [hl], $01
	call PrintPlayersCardsText
	ld hl, hffb0
	ld [hl], $00
	jp .loop_frame_1

.asm_ac92
	call DrawListCursor_Visible
	call .Func_acde
	lb de, 1, 1
	ldtx hl, PrintThisCardYesNoText
	call InitTextPrinting_ProcessTextFromID
	ld a, $01
	ld hl, Data_ad05
	call InitCardSelectionParams
.loop_frame
	call DoFrame
	call HandleCardSelectionInput
	jr nc, .loop_frame
	ldh a, [hffb3]
	or a
	jr nz, .asm_acd5
	ld hl, wFilteredCardList
	ld a, [wTempCardListCursorPos]
	ld c, a
	ld b, $00
	add hl, bc
	ld a, [wCardListVisibleOffset]
	ld c, a
	ld b, $00
	add hl, bc
	ld a, [hl]
	farcall RequestToPrintCard
	call PrintPlayersCardsHeaderInfo
	jp .asm_ac37

.asm_acd5
	call .Func_acde
	call PrintPlayersCardsHeaderInfo.skip_empty_screen
	jp .asm_ac37

.Func_acde
	xor a
	lb hl, 0, 0
	lb de, 0, 0
	lb bc, 20, 4
	call FillRectangle
	ld a, [wConsole]
	cp CONSOLE_CGB
	ret nz ; exit if not CGB

	xor a
	lb hl, 0, 0
	lb de, 0, 0
	lb bc, 20, 4
	call BankswitchVRAM1
	call FillRectangle
	jp BankswitchVRAM0

Data_ad05:
	db 3 ; x position
	db 3 ; y position
	db 0 ; y spacing
	db 4 ; x spacing
	db 2 ; number of entries
	db SYM_CURSOR_R ; visible cursor tile
	db SYM_SPACE ; invisible cursor tile
	dw NULL ; wCardListHandlerFunction


PrinterMenu_DeckConfiguration:
	xor a
	ld [wCardListVisibleOffset], a
	call ClearScreenAndDrawDeckMachineScreen
	ld a, NUM_DECK_SAVE_MACHINE_SLOTS
	ld [wNumDeckMachineEntries], a

	xor a
.start_selection
	ld hl, DeckMachineSelectionParams
	call InitCardSelectionParams
	call DrawListScrollArrows
	call PrintNumSavedDecks
	ldtx hl, PleaseChooseDeckConfigurationToPrintText
	call DrawWideTextBox_PrintText
	ldtx de, PleaseChooseDeckConfigurationToPrintText
	call InitDeckMachineDrawingParams
.loop_input
	call HandleDeckMachineSelection
	jr c, .start_selection
	cp $ff
	ret z

	ld b, a
	ld a, [wCardListVisibleOffset]
	add b
	ld [wSelectedDeckMachineEntry], a
	call CheckIfSelectedDeckMachineEntryIsEmpty
	jr c, .loop_input
	call DrawWideTextBox
	ldtx hl, PrintThisDeckText
	call YesOrNoMenuWithText
	jr c, .no
	call GetSelectedSavedDeckPtr
	ld hl, DECK_NAME_SIZE
	add hl, de
	ld de, wCurDeckCards
	ld b, DECK_SIZE
	call EnableSRAM
	call CopyNBytesFromHLToDE
	call DisableSRAM
	xor a ; terminator byte for deck
	ld [wCurDeckCards + DECK_SIZE], a
	call SortCurDeckCardsByID
	ld a, [wSelectedDeckMachineEntry]
	farcall PrintDeckConfiguration
	call ClearScreenAndDrawDeckMachineScreen

.no
	ld a, [wTempDeckMachineCursorPos]
	ld [wCardListCursorPos], a
	jr .start_selection


PrinterMenu_CardList:
	call WriteCardListsTerminatorBytes
	call Set_OBJ_8x8
	call EmptyScreenAndLoadFontDuelAndDeckIcons
	lb bc, 0, 4
	ld a, SYM_BOX_TOP
	call FillBGMapLineWithA

	xor a
	ld [wCardListVisibleOffset], a
	ld [wCurCardTypeFilter], a
	call PrintFilteredCardSelectionList
	call EnableLCD
	lb de, 1, 1
	ldtx hl, PrintTheCardListText
	call InitTextPrinting_ProcessTextFromID
	ld a, $01
	ld hl, Data_ad05
	call InitCardSelectionParams
.loop_frame
	call DoFrame
	call HandleCardSelectionInput
	jr nc, .loop_frame
	ldh a, [hffb3]
	or a
	ret nz
	farcall PrintCardList
	ret


PrinterMenu_PrintQuality:
	ldtx hl, PleaseSetTheContrastText
	call DrawWideTextBox_PrintText
	call EnableSRAM
	ld a, [sPrinterContrastLevel]
	call DisableSRAM
	ld hl, Data_adf5
	call InitCardSelectionParams
.loop_frame
	call DoFrame
	call HandleCardSelectionInput
	jr nc, .loop_frame
	ldh a, [hffb3]
	cp $ff
	jr z, .asm_ade2
	call EnableSRAM
	ld [sPrinterContrastLevel], a
	call DisableSRAM
.asm_ade2
	add sp, $2 ; exit menu
	ld a, [wSelectedPrinterMenuItem]
	ld hl, PrinterMenuParameters
	call InitializeMenuParameters
	ldtx hl, WhatWouldYouLikeToPrintText
	call DrawWideTextBox_PrintText
	jp HandlePrinterMenu.loop_input

Data_adf5:
	db 5  ; x position
	db 16 ; y position
	db 0  ; y spacing
	db 2  ; x spacing
	db 5  ; number of entries
	db SYM_CURSOR_R ; visible cursor tile
	db SYM_SPACE ; invisible cursor tile
	dw NULL ; wCardListHandlerFunction


PrinterMenu_QuitPrint:
	add sp, $2 ; exit menu
	ldtx hl, PleaseMakeSureToTurnGameBoyPrinterOffText
	jp DrawWideTextBox_WaitForInput

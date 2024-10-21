; if the Player has not yet received the Legendary Cards, then there is a chance
; that an AI duelist (excluding Ronald and the Club Masters/Grandmasters)
; will randomly decide not to play a Trainer card or use a Pokémon Power.
; The probability for not performing the action is based on the deck.
; It's 50% if the deck is listed under .check_deck and 25% if not.
; preserves all registers except af
; output:
;	carry = set:  if the AI will not take the action
AIChooseRandomlyNotToDoAction:
	farcall CheckIfNotABossDeckID
	ret nc

.check_deck
	ld a, [wOpponentDeckID]
	cp MUSCLES_FOR_BRAINS_DECK_ID
	jr z, .carry_50_percent
	cp BLISTERING_POKEMON_DECK_ID
	jr z, .carry_50_percent
	cp WATERFRONT_POKEMON_DECK_ID
	jr z, .carry_50_percent
	cp BOOM_BOOM_SELFDESTRUCT_DECK_ID
	jr z, .carry_50_percent
	cp KALEIDOSCOPE_DECK_ID
	jr z, .carry_50_percent
	cp RESHUFFLE_DECK_ID
	jr z, .carry_50_percent

; carry 25 percent
	ld a, 4
	call Random
	cp 1
	ret

.carry_50_percent
	ld a, 4
	call Random
	cp 2
	ret


; preserves bc and hl
; input:
; carry = set:  if there's any Pokémon other than MewtwoLv53 in the Player's deck
CheckIfPlayerHasPokemonOtherThanMewtwoLv53:
	rst SwapTurn
	ld e, DECK_SIZE
.loop_deck
	dec e ; go through deck indices in reverse order
	ld a, e
	call LoadCardDataToBuffer2_FromDeckIndex
	ld a, [wLoadedCard2Type]
	cp TYPE_ENERGY
	jr nc, .next
	ld a, [wLoadedCard2ID]
	cp MEWTWO_LV53
	jr nz, .not_mewtwo1
.next
	ld a, e
	or a
	jr nz, .loop_deck
	; the only Pokémon is MewtwoLv53, so return no carry
	jp SwapTurn

.not_mewtwo1
	scf
	jp SwapTurn


; lists in wDuelTempList all the Basic Energy cards in the card location in a.
; preserves bc
; input:
;	a = CARD_LOCATION_* constant
; output:
;	a & d = number of Basic Energy cards in the given location
;	carry = set:  if no Basic Energy cards were found
;	wDuelTempList = $ff-terminated list with deck indices of Basic Energy cards in the given location
FindBasicEnergyCardsInLocation:
	ld [wTempAI], a
	lb de, 0, DECK_SIZE
	ld hl, wDuelTempList

; d = number of Basic Energy cards found
; e = current card from the deck
; loop entire deck
.loop
	dec e ; go through deck indices in reverse order
	ld a, e ; DUELVARS_CARD_LOCATIONS + current deck index
	push hl
	get_turn_duelist_var
	ld hl, wTempAI
	cp [hl]
	pop hl
	jr nz, .next_card

; this card is in the given location.
	ld a, e
	call _GetCardIDFromDeckIndex
	cp DOUBLE_COLORLESS_ENERGY
	; only Basic Energy cards will set carry here
	jr nc, .next_card

; this card is also a Basic Energy,
; so add its deck index to wDuelTempList.
	ld a, e
	ld [hli], a
	inc d
.next_card
	ld a, e
	or a
	jr nz, .loop

.terminate_list
	ld a, $ff ; list is $ff-terminated
	ld [hl], a ; add terminating byte to wDuelTempList
	ld a, d
	or a
	ret nz ; return no carry if there's at least one card in the list
	; list is empty, so return carry
	scf
	ret


; chooses an Energy card attached to the Pokémon in the given location,
; to be discarded by the AI for an effect. tries to pick an Energy that isn't important.
; input:
;	a = play area location offset to check (PLAY_AREA_* constant)
; output:
;	a = deck index of an Energy card attached to the Pokémon in the given location
;	  = $ff:  if there are no Energy cards attached to the Pokémon in the given location
AIPickEnergyCardToDiscard:
; construct Energy list and check if there are any Energy cards attached.
	ldh [hTempPlayAreaLocation_ff9d], a
	call CreateArenaOrBenchEnergyCardList
	or a
	jr z, PickAttachedEnergyCardToRemove.no_energy

; load the card's data and store its type and card ID.
	ldh a, [hTempPlayAreaLocation_ff9d]
	add DUELVARS_ARENA_CARD
	get_turn_duelist_var
	call LoadCardDataToBuffer1_FromDeckIndex
	ld [wTempCardID], a
	ld a, [wLoadedCard1Type]
	or TYPE_ENERGY
	ld [wTempCardType], a

; look for an Energy card that is not useful.
; if none is found, then chosen an Energy card at random.
	ld hl, wDuelTempList
.loop
	ld a, [hli]
	cp $ff
	jr z, PickAttachedEnergyCardToRemove.random_energy
	farcall CheckIfEnergyIsUseful
	jr c, .loop
	; found an Energy that wasn't useful
	dec hl
	ld a, [hl]
	ret


; handles AI choosing of an Energy card to remove from one of the Player's Pokémon
; in the given location. prioritizes Double Colorless Energy, then any useful Energy.
; if neither of those checks are successful, then choose the Energy card at random.
; input:
;	a = play area location offset to check (PLAY_AREA_* constant)
; output:
;	a = deck index of an Energy card attached to the Pokémon in the given location
;	  = $ff:  if there are no Energy cards attached to the Pokémon in the given location
PickAttachedEnergyCardToRemove:
; construct Energy list and check if there are any Energy cards attached.
	ldh [hTempPlayAreaLocation_ff9d], a
	call CreateArenaOrBenchEnergyCardList
	or a
	jr z, .no_energy

; load the card's data and store its type and card ID.
	ldh a, [hTempPlayAreaLocation_ff9d]
	add DUELVARS_ARENA_CARD
	get_turn_duelist_var
	call LoadCardDataToBuffer1_FromDeckIndex
	ld [wTempCardID], a
	ld a, [wLoadedCard1Type]
	or TYPE_ENERGY
	ld [wTempCardType], a

; first, look for any Double Colorless Energy.
	ld hl, wDuelTempList
.loop_1
	ld a, [hli]
	cp $ff
	jr z, .check_useful
	call _GetCardIDFromDeckIndex
	cp DOUBLE_COLORLESS_ENERGY
	jr nz, .loop_1

.found
	dec hl
	ld a, [hl]
	ret

; then, look for any Energy cards that are useful.
.check_useful
	ld hl, wDuelTempList
.loop_2
	ld a, [hli]
	cp $ff
	jr z, .random_energy
	farcall CheckIfEnergyIsUseful
	jr c, .found ; the current Energy card is useful, so pick that
	jr .loop_2

; if none were found with the above criteria, just return with a random Energy.
.random_energy
	call CountCardsInDuelTempList
	ld hl, wDuelTempList
	call ShuffleCards
	ld a, [hl]
	ret

; return with $ff if no Energy cards are attached to that Pokémon.
.no_energy
	ld a, $ff
	ret


; handles AI choosing of 2 Energy cards to remove from one of the Player's Pokémon
; in the given location. prioritizes Double Colorless Energy, then any useful Energy,
; then defaults to the first two attached Energy cards if neither of those are found.
; input:
;	a = play area location offset to check (PLAY_AREA_* constant)
; output:
;	a & [wTempAI] = deck index of an Energy card attached to the Pokémon
;	                in the given location ($ff if no attached Energy cards)
;	b & [wCurCardCanAttack] = deck index of another Energy card that is attached to the Pokémon
;	                          in the given location ($ff if only 1 attached Energy card)
PickTwoAttachedEnergyCards:
; construct Energy list and check if there are at least 2 Energy cards attached.
	ldh [hTempPlayAreaLocation_ff9d], a
	call CreateArenaOrBenchEnergyCardList
	cp 2
	jr c, PickAttachedEnergyCardToRemove.no_energy

; load the card's data and store its type and card ID.
; also store $ff in the wram addresses that will be used for Energy card deck indices.
	ldh a, [hTempPlayAreaLocation_ff9d]
	add DUELVARS_ARENA_CARD
	get_turn_duelist_var
	call LoadCardDataToBuffer1_FromDeckIndex
	ld [wTempCardID], a
	ld a, [wLoadedCard1Type]
	or TYPE_ENERGY
	ld [wTempCardType], a
	ld a, $ff
	ld [wTempAI], a
	ld [wCurCardCanAttack], a

; first, look for any Double Colorless Energy.
	ld hl, wDuelTempList
.loop_1
	ld a, [hl]
	cp $ff
	jr z, .check_useful
	call _GetCardIDFromDeckIndex
	cp DOUBLE_COLORLESS_ENERGY
	jr z, .found_double_colorless
	inc hl
	jr .loop_1
.found_double_colorless
	ld a, [wTempAI]
	cp $ff
	jr nz, .already_chosen
	ld a, [hli]
	ld [wTempAI], a
	jr .loop_1
.already_chosen
	ld a, [hl]
	ld [wCurCardCanAttack], a
	jr .done

; then, look for any Energy cards that are useful
.check_useful
	ld hl, wDuelTempList
.loop_2
	ld a, [hl]
	cp $ff
	jr z, .default
	farcall CheckIfEnergyIsUseful
	jr c, .found_useful
	inc hl
	jr .loop_2
.found_useful
	ld a, [wTempAI]
	cp $ff
	jr nz, .already_chosen
	ld a, [hli]
	ld [wTempAI], a
	jr .loop_2

; if none were found with the above criteria,
; just return with the first 2 cards in the list.
.default
	ld hl, wDuelTempList
	ld a, [wTempAI]
	cp $ff
	jr nz, .pick_one_card

; pick 2 cards
	ld a, [hli]
	ld [wTempAI], a
	ld a, [hl]
	ld [wCurCardCanAttack], a
	jr .done

.pick_one_card
	ld a, [wTempAI]
	ld b, a
.loop_3
	ld a, [hli]
	cp b
	jr z, .loop_3 ; already picked
	ld [wCurCardCanAttack], a
.done
	ld b, a
	ld a, [wTempAI]
	ret


; copies an $ff-terminated list from hl to de
; preserves bc
; input:
;	hl = address from which to start copying the data
;	de = where to copy the data
CopyListWithFFTerminatorFromHLToDE_Bank8:
	ld a, [hli]
	ld [de], a
	cp $ff
	ret z
	inc de
	jr CopyListWithFFTerminatorFromHLToDE_Bank8


; zeroes a bytes starting from hl.
; this function is identical to 'ClearMemory_Bank2',
; as well as 'ClearMemory_Bank5' and 'ClearMemory_Bank6'.
; preserves all registers
; input:
;	a = number of bytes to clear
;	hl = where to begin erasing
ClearMemory_Bank8:
	push af
	push bc
	push hl
	ld b, a
	xor a
.loop
	ld [hli], a
	dec b
	jr nz, .loop
	pop hl
	pop bc
	pop af
	ret


; converts an HP value or amount of damage to the number of equivalent damage counters
; preserves all registers except af
; input:
;	a = HP value to convert
; output:
;	a = number of damage counters
ConvertHPToDamageCounters_Bank8:
	push bc
	ld c, 0
.loop
	sub 10
	jr c, .done
	inc c
	jr .loop
.done
	ld a, c
	pop bc
	ret


; preserves bc and de
; input:
;	hl = number to divide by 10
; output:
;	hl /= 10
HLDividedBy10:
	push bc
	push de
	ld bc, -10
	ld de, -1
.asm_229b8
	inc de
	add hl, bc
	jr c, .asm_229b8
	ld h, d
	ld l, e
	pop de
	pop bc
	ret


; returns in a the division of b by a, rounded down
; preserves all registers except af
; input:
;	b = dividend
;	a = divisor
; output:
;	a = quotient (without remainder)
CalculateBDividedByA_Bank8:
	push bc
	ld c, a
	ld a, b ; a = input b
	ld b, c ; b = input a
	ld c, 0
.loop
	sub b
	jr c, .done
	inc c
	jr .loop
.done
	ld a, c
	pop bc
	ret


; preserves bc and e
; input:
;	a = CARD_LOCATION_* constant
;	e = card ID to look for
; output:
;	a & l = deck index of a matching card, if any
;	carry = set:  if the given card was found in the given location
LookForCardIDInLocation_Bank8:
	ld d, a
	ldh a, [hWhoseTurn]
	ld h, a
	ld l, DUELVARS_CARD_LOCATIONS + DECK_SIZE
.loop
	dec l ; go through deck indices in reverse order
	ld a, [hl]
	cp d
	ld a, l
	jr nz, .next ; skip if wrong location
	call _GetCardIDFromDeckIndex
	cp e
	ld a, l
	scf
	ret z ; return carry with deck index in a if a match was found
.next
	or a
	jr nz, .loop
	; none found, so return no carry
	ret


; checks the AI's hand for a specific card
; input:
;	a = card ID
; output:
;	a & [hTempCardIndex_ff98] = deck index for a copy of the given card in the turn holder's hand
;	                          = $ff:  if no copies of the given card were found in the hand
;	carry = set:  if the given card ID was found in the turn holder's hand
LookForCardIDInHandList_Bank8:
	ld [wTempCardIDToLook], a
	call CreateHandCardList
	ld hl, wDuelTempList
.loop
	ld a, [hli]
	cp $ff
	ret z ; return no carry if there are no more cards in the hand to check
	ldh [hTempCardIndex_ff98], a
	call GetCardIDFromDeckIndex
	ld a, [wTempCardIDToLook]
	cp e
	jr nz, .loop

; found a match, so return carry with the deck index in a.
	ldh a, [hTempCardIndex_ff98]
	scf
	ret


; checks the AI's hand and play area for a specific card.
; input:
;	a = card ID
; output:
;	carry = set:  if the given card ID was found in the turn holder's hand or
;	              if the given card ID was found in the turn holder's play area
LookForCardIDInHandAndPlayArea:
	ld b, a
	push bc
	call LookForCardIDInHandList_Bank8
	pop bc
	ret c

	ld a, b
	ld b, PLAY_AREA_ARENA
;	fallthrough

; checks the AI's play area for a specific card.
; preserves de
; input:
;	a = card ID
;	b = play area location offset to start with (PLAY_AREA_* constant)
; output:
;	a = play area location offset of the found card (first copy, more might exist)
;	  = $ff:  if none of the Pokémon in the turn holder's play area have the given card ID
;	carry = set:  if the given card ID was found in the turn holder's play area
LookForCardIDInPlayArea_Bank8:
	ld c, a
.loop
	ld a, DUELVARS_ARENA_CARD
	add b
	get_turn_duelist_var
	cp $ff
	ret z
	call _GetCardIDFromDeckIndex
	cp c
	jr z, .found
	inc b
	jr .loop

.found
	ld a, b
	scf
	ret


; searches AI's deck for card ID #1 (a), and
; if found, searches AI's hand and play area for card ID #2 (b), and
; if found, searches AI's hand and play area for card ID #1 (a), and
; if none found, return carry and output the deck index of the card found in the the deck.
; input:
;	a = card ID #1
;	b = card ID #2
; output:
;	a & [wTempAIPokemonCard] = deck index of a card in the deck with ID #1:  if carry = set
;	carry = set:  if AI has a card with ID #1 is in their deck but not in their hand or play area
;	              and also a card with ID #2 in their hand or play area
LookForCardIDInDeck_GivenCardIDInHandAndPlayArea:
; store a in wCurCardCanAttack and b in wTempAI
	ld [wCurCardCanAttack], a
	ld hl, wTempAI
	ld [hl], b

; look for card ID #1 in the deck
	ld e, a
	ld a, CARD_LOCATION_DECK
	call LookForCardIDInLocation_Bank8
	ret nc

; was found, store its deck index in memory
	ld [wTempAIPokemonCard], a

; look for card ID #2 in the hand and play area
	ld a, [wTempAI]
	call LookForCardIDInHandAndPlayArea
	ret nc

; look for card ID #1 in the hand and play area.
; if no card is found, return carry.
	ld a, [wCurCardCanAttack]
	call LookForCardIDInHandAndPlayArea
	ccf
	ld a, [wTempAIPokemonCard]
	ret


; searches AI's deck for card ID #1 (a), and
; if found, searches AI's hand for card ID #2 (b), and
; if found, searches AI's hand and play area for card ID #1 (a), and
; if none found, return carry and output the deck index of the card found in the the deck.
; input:
;	a = card ID #1
;	b = card ID #2
; output:
;	a & [wTempAIPokemonCard ]= deck index of a card in the deck with ID #1:  if the below conditions are true
;	carry = set:  if AI has a card with ID #1 is in their deck but not in their hand or play area
;	              and also a card with ID #2 in their hand
LookForCardIDInDeck_GivenCardIDInHand:
; store a in wCurCardCanAttack and b in wTempAI
	ld [wCurCardCanAttack], a
	ld hl, wTempAI
	ld [hl], b

; look for card ID #1 in the deck
	ld e, a
	ld a, CARD_LOCATION_DECK
	call LookForCardIDInLocation_Bank8
	ret nc

; was found, store its deck index in memory
	ld [wTempAIPokemonCard], a

; look for card ID #2 in the hand
	ld a, [wTempAI]
	call LookForCardIDInHandList_Bank8
	ret nc

; look for card ID #1 in the hand and play area.
; if no card is found, return carry.
	ld a, [wCurCardCanAttack]
	call LookForCardIDInHandAndPlayArea
	ccf
	ld a, [wTempAIPokemonCard]
	ret


; removes the first card from wDuelTempList (hl) that has the type given in d.
; a card is also skipped if it has the deck index given in e.
; preserves all registers except af
; input:
;	d = type of card allowed to be removed ($00 = Trainer, $01 = Pokémon, $02 = Energy)
;	e = deck index to avoid removing from the list
;	hl = wDuelTempList
; output:
;	a & [hTempCardIndex_ff98] = deck index of the card that was removed from the list, if any
;	carry = set:  if a card was removed from the list
RemoveFromListDifferentCardOfGivenType:
	push hl
	push de
	call CountCardsInDuelTempList
	call ShuffleCards

; loop list until a card with
; deck index different from e is found.
.loop_list
	ld a, [hli]
	cp $ff
	jr z, .no_carry
	cp e
	jr z, .loop_list

; get this card's type
	ldh [hTempCardIndex_ff98], a
	call GetCardTypeFromDeckIndex_SaveDE
	cp TYPE_ENERGY
	jr c, .pkmn_card
	cp TYPE_TRAINER
	jr nz, .energy

; only remove from list specific type.

; trainer
	ld a, d
	or a ; cp $00
	jr nz, .loop_list
	jr .remove_card
.energy
	ld a, d
	cp $02
	jr nz, .loop_list
	jr .remove_card
.pkmn_card
	ld a, d
	cp $01
	jr nz, .loop_list
	; fallthrough

.remove_card
	ld d, h
	ld e, l
	dec hl
.loop_remove
	ld a, [de]
	inc de
	ld [hli], a
	cp $ff
	jr nz, .loop_remove

; success
	ldh a, [hTempCardIndex_ff98]
	pop de
	pop hl
	scf
	ret

.no_carry
	pop de
	pop hl
	or a
	ret


; used in Pokémon Trader checks to look for a specific card in the deck
; to trade with a Pokémon in hand that has a card ID different from input in e.
; input:
;	a = card ID #1
;	e = card ID #2
; output:
;	a = deck index of a card in the deck with ID #1:  if carry = set
;	e = deck index of a Pokémon in the hand that doesn't have card ID #2:  if carry = set
;	carry = set:  if AI has a card with ID #1 is in their deck but not their hand
;	              and also a Pokémon in their hand that doesn't have card ID #2
LookForCardIDToTradeWithDifferentHandCard:
	ld hl, wCurCardCanAttack
	ld [hl], e
	ld [wTempAI], a

; if card ID #1 is in the hand, return no carry.
	call LookForCardIDInHandList_Bank8
	ccf
	ret nc

; if card ID #1 is not in the deck, return no carry.
	ld a, [wTempAI]
	ld e, a
	ld a, CARD_LOCATION_DECK
	call LookForCardIDInLocation_Bank8
	ret nc

; store its deck index
	ld [wTempAI], a

; look in the hand for a Pokémon with a card ID
; that is different from card ID #2.
	ld a, [wCurCardCanAttack]
	ld c, a
	call CreateHandCardList
	ld hl, wDuelTempList

.loop_hand
	ld a, [hli]
	cp $ff
	ret z ; nc
	ld e, a
	call LoadCardDataToBuffer1_FromDeckIndex
	cp c
	jr z, .loop_hand
	ld a, [wLoadedCard1Type]
	cp TYPE_ENERGY
	jr nc, .loop_hand

; found, output the deck index of the card in the deck and return carry.
	ld a, [wTempAI]
	ret


; checks for multiple copies of a given card in the AI's hand
; input:
;	a = card ID to look for
; output:
;	a & [hTempCardIndex_ff98] = deck index of an extra copy of the given card
;	                            in the turn holder's hand, if any
;	carry = set:  if there are at least 2 copies of the given card in the hand
CheckIfHasDuplicateCardIDInHand:
	ld [wTempCardIDToLook], a
	call CreateHandCardList
	ld hl, wDuelTempList
	ld c, 0 ; counter

.loop_hand
	ld a, [hli]
	cp $ff
	ret z
	ldh [hTempCardIndex_ff98], a
	call GetCardIDFromDeckIndex
	ld a, [wTempCardIDToLook]
	cp e
	jr nz, .loop_hand
	ld a, c
	or a
	jr nz, .set_carry
	inc c
	jr .loop_hand

.set_carry
	ldh a, [hTempCardIndex_ff98]
	scf
	ret


; output:
;	a & [wTempAI] = total number of Pokémon in the turn holder's hand and play area
CountPokemonCardsInHandAndInPlayArea:
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	get_turn_duelist_var
	ld [wTempAI], a
	call CreateHandCardList
	ld hl, wDuelTempList
.loop_hand
	ld a, [hli]
	cp $ff
	jr z, .done
	call GetCardIDFromDeckIndex
	call GetCardType
	cp TYPE_ENERGY
	jr nc, .loop_hand
	ld a, [wTempAI]
	inc a
	ld [wTempAI], a
	jr .loop_hand
.done
	ld a, [wTempAI]
	ret


; compares card IDs in the AI's hand, searching for 2 identical Pokémon
; output:
;	a = deck index of a duplicate Pokémon card in the turn holder's hand
;	  = $ff:  if there are no duplicate Pokémon cards in the hand
;	carry = set:  if a duplicate Pokémon card was found in the hand
FindDuplicatePokemonCards:
	call CreateHandCardList
	ld hl, wDuelTempList
	push hl

.loop_hand_outer
	pop hl
	ld a, [hli]
	cp $ff
	ret z ; nc
	call _GetCardIDFromDeckIndex
	ld b, a
	push hl

.loop_hand_inner
	ld a, [hli]
	cp $ff
	jr z, .loop_hand_outer
	ld c, a
	call GetCardIDFromDeckIndex
	ld a, e
	cp b
	jr nz, .loop_hand_inner

; found two cards with the same ID,
; if Pokémon, return carry with the deck index in a.
	call GetCardType
	cp TYPE_ENERGY
	jr nc, .loop_hand_outer
	pop hl
	ld a, c
	ret ; carry set


; finds a duplicate card in the list at hl. priotizes duplicate Pokémon cards.
; input:
;	hl = $ff-terminated list with deck indices of cards
; output:
;	a = deck index of a duplicate card in the list
;	carry = set:  if duplicate cards were found in the given list
FindDuplicateCards:
	push hl
	ld a, $ff
	ld [wce0f], a

.loop_outer
; get ID of current card
	pop hl
	ld a, [hli]
	cp $ff
	jr z, .check_found
	call _GetCardIDFromDeckIndex
	ld b, a
	push hl

; loop the rest of the list to find
; another card with the same ID
.loop_inner
	ld a, [hli]
	cp $ff
	jr z, .loop_outer
	ld c, a
	call GetCardIDFromDeckIndex
	ld a, e
	cp b
	jr nz, .loop_inner

; found two cards with same ID
	call GetCardType
	cp TYPE_ENERGY
	jr nc, .not_pokemon

; they are Pokémon cards, so return carry
; with the found deck index in a
	pop hl
	ld a, c
	ret ; carry set

; they are Energy or Trainer cards
; loads wce0f with this card deck index
.not_pokemon
	ld a, c
	ld [wce0f], a
	jr .loop_outer

.check_found
	ld a, [wce0f]
	cp $ff
	ret z ; return no carry if no duplicate cards were found
	; two non-Pokémon cards with the same ID were found
	scf
	ret


; searches the list at hl for the deck index in a
; and if found, that card is removed from the list.
; preserves all registers except af and b
; input:
;	a  = item to remove from the list
;	hl = pointer to an $ff-terminated list
FindAndRemoveCardFromList:
	push hl
	ld b, a
.loop_duplicate
	ld a, [hli]
	cp $ff
	jr z, .done
	cp b
	jr nz, .loop_duplicate
	call RemoveCardFromList
.done
	pop hl
	ret


; removes an element from the given list and shortens the list accordingly.
; preserves bc and de
; input:
;	hl = pointer to the element after the one to remove in an $ff-terminated list
RemoveCardFromList:
	push de
	ld d, h
	ld e, l
	dec hl
	push hl
.loop_remove
	ld a, [de]
	ld [hli], a
	cp $ff
	jr z, .done_remove
	inc de
	jr .loop_remove
.done_remove
	pop hl
	pop de
	ret


; output:
;	carry = set:  if an attack was chosen and it has the high recoil attack flag
;	[wLoadedAttack] = attack data for the Active Pokémon's optimal attack (atk_data_struct)
AICheckIfAttackIsHighRecoil:
	farcall AIProcessButDontUseAttack
	ret nc
	ld a, [wSelectedAttack]
	ld e, a
	ld a, DUELVARS_ARENA_CARD
	get_turn_duelist_var
	ld d, a
	call CopyAttackDataAndDamage_FromDeckIndex
	ld a, ATTACK_FLAG1_ADDRESS | HIGH_RECOIL_F
	jp CheckLoadedAttackFlag


; checks every Pokémon with attached Energy in the turn holder's play area,
; starting with e. compares each Pokémon that's found and stores the greatest
; amount of damage that any of these Pokémon can do to the Defending Pokémon in wce06.
; the location of the Pokémon with the highest damaging attack is stored in wce08.
; input:
;	e = play area location offset of the first Pokémon to check (PLAY_AREA_* constant)
; output:
;	[wce06] = greatest amount of damage that one of the turn holder's Pokémon
;	          with any attached Energy can do to the Defending Pokémon
;	[wce08] = play area location offset of the Pokémon with attached Energy that
;	          can do the most damage to the Defending Pokémon (PLAY_AREA_ARENA if none)
FindEnergizedPokemonWithHighestDamagingAttack:
	xor a
	ld [wce06], a
	ld [wce08], a
.loop_play_area
	ld a, DUELVARS_ARENA_CARD
	add e
	get_turn_duelist_var
	cp $ff
	ret z ; return when there are no more Pokémon to check in the turn holder's play area
	call GetPlayAreaCardAttachedEnergies
	or a
	call nz, .check_attacks_for_current_pokemon
	inc e
	jr .loop_play_area

; preserves de
; input:
;	e = play area location offset of the Pokémon to check (PLAY_AREA_* constant)
.check_attacks_for_current_pokemon
	ld a, e
	ldh [hTempPlayAreaLocation_ff9d], a
	xor a ; FIRST_ATTACK_OR_PKMN_POWER
	call .compare_this_attack_with_one_stored
	ld a, SECOND_ATTACK
;	fallthrough

; preserves de
; input:
;	a = which attack to check (0 = first attack, 1 = second attack)
;	[hTempPlayAreaLocation_ff9d] = play area location offset of the Pokémon to check (PLAY_AREA_* constant)
; output:
;	carry = set:  if this attack's damage was higher than the one stored in wce06
.compare_this_attack_with_one_stored
	push de
	farcall EstimateDamage_VersusDefendingCard
	ld a, [wDamage]
	or a
	jr z, .skip
	ld e, a
	ld a, [wce06]
	cp e
	jr nc, .skip
	ld a, e
	ld [wce06], a ; store this damage value
	pop de
	ld a, e
	ld [wce08], a ; store this location
	ret
.skip
	pop de
	ret

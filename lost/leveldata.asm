	.org $8000

	.segment "bank8"

	.include "lost.inc"
	.include "mario.inc"
	.include "shared.inc"
	.include "macros.inc"
	.include "wram.inc"

	.export LoadWarpzone
	.export GetAreaDataAddrs
	.export LoadAreaPointer
	.export WriteHalfwayPages

NonMaskableInterrupt:
Start:
	rti ; TODO this is dumb as shit.

LoadWarpzone:
	lda WarpZoneControl
	and #$F

	ldy IsPlayingExtendedWorlds ; todo
	bne LoadWarpzoneExt

LoadWarpzoneStd:
	tax
	and #%00000011            ;mask out all but 2 LSB
	asl
	asl                       ;multiply by four
	tax                       ;save as offset to warp zone numbers (starts at left pipe)
	lda Player_X_Position     ;get player's horizontal position
	cmp #$60
	bcc @GetWNum               ;if player at left, not near middle, use offset and skip ahead
	inx                       ;otherwise increment for middle pipe
	cmp #$a0
	bcc @GetWNum               ;if player at middle, but not too far right, use offset and skip
	inx                       ;otherwise increment for last pipe
@GetWNum:
	lda WarpZoneNumbers,x
	tay
	dey
	sty WorldNumber
	ldx WorldAddrOffsets,y
	lda AreaAddrOffsets,x
	sta AreaPointer
	sta WRAM_LevelAreaPointer
	lda #$80
	sta EventMusicQueue
	PF_SetToLevelEnd_A
	lda #0
	sta EntrancePage
	sta AreaNumber
	sta LevelNumber
	sta AltEntranceControl
	inc Hidden1UpFlag
	inc FetchNewGameTimerFlag
	jmp ReturnBank


LoadWarpzoneExt:
	lda #9
	adc WorldNumber
	adc AreaNumber
	tax
	lda WarpZoneNumbers,x
	tay
	dey
	sty WorldNumber
	ldx WorldAddrOffsetsExt,y
	lda AreaAddrOffsetsExt,x
	sta AreaPointer
	sta WRAM_LevelAreaPointer
	lda #$80
	sta EventMusicQueue
	PF_SetToLevelEnd_A
	lda #0
	sta EntrancePage
	sta AreaNumber
	sta LevelNumber
	sta AltEntranceControl
	inc Hidden1UpFlag
	inc FetchNewGameTimerFlag
	jmp ReturnBank




LoadAreaPointer:
		jsr LoadAreaPointerInner
		jmp ReturnBank

LoadAreaPointerInner:
		ldy WorldNumber
		lda IsPlayingExtendedWorlds
		beq @load_normal
		; FindAreaPointerEx
		lda WorldAddrOffsetsExt,y
		clc
		adc AreaNumber
		tay
		lda AreaAddrOffsetsExt,y
		; /FindAreaPointer
		jmp @finalize
@load_normal:
		; FindAreaPointer
		lda WorldAddrOffsets,y
		clc
		adc AreaNumber
		tay
		lda AreaAddrOffsets,y
		; /FindAreaPointer
@finalize:
		sta AreaPointer
		sta WRAM_LevelAreaPointer
GetAreaType:
		and #$60
		asl
		rol
		rol
		rol
		sta AreaType
		sta WRAM_LevelAreaType
		rts

.macro CreateGetAreaDataAddrs enemy_hoff, enemy_data, area_hoff, area_data
		lda AreaPointer
		jsr GetAreaType
		tay
		lda AreaPointer
		and #$1F
		sta AreaAddrsLOffset
		lda enemy_hoff,y
		clc
		adc AreaAddrsLOffset
		asl
		tay
		lda enemy_data+1,y
		sta EnemyDataHigh
		lda enemy_data,y
		sta EnemyDataLow
		ldy AreaType
		lda area_hoff,y
		clc
		adc AreaAddrsLOffset
		asl
		tay
		lda area_data+1,y
		sta AreaDataHigh
		lda area_data,y
		sta AreaDataLow
		;
		; Copy to wram
		;
		ldy #0
		ldx #0
@copy_more_area:
		lda (AreaData), y
		sta WRAM_LevelData, x
		iny
		inx
		cmp #$FD
		bne @copy_more_area

		ldy #0
		ldx #0
@copy_more_enemy:
		lda (EnemyData), y
		sta WRAM_EnemyData, x
		iny
		inx
		cmp #$ff
		bne @copy_more_enemy

		lda #<WRAM_LevelData
		sta AreaDataLow
		lda #>WRAM_LevelData
		sta AreaDataHigh

		lda #<WRAM_EnemyData
		sta EnemyDataLow
		lda #>WRAM_EnemyData
		sta EnemyDataHigh

		ldy #0
		lda (AreaData),y
		pha
		and #7
		cmp #4
		bcc @loc_C30B
		sta BackgroundColorCtrl
		lda #0
@loc_C30B:
		sta ForegroundScenery
		pla
		pha
		and #$38
		lsr
		lsr
		lsr
		sta PlayerEntranceCtrl
		pla
		and #$C0
		clc
		rol
		rol
		rol
		sta GameTimerSetting
		iny
		lda (AreaData),y
		pha
		and #$F
		sta TerrainControl
		pla
		pha
		and #$30
		lsr
		lsr
		lsr
		lsr
		sta BackgroundScenery
		pla
		and #$C0
		clc
		rol
		rol
		rol
		cmp #3
		bne @loc_C346
		sta CloudTypeOverride
		lda #0
@loc_C346:
		sta AreaStyle
		lda AreaDataLow
		clc
		adc #2
		sta AreaDataLow
		lda AreaDataHigh
		adc #0
		sta AreaDataHigh		
.endmacro


WriteHalfwayPages:
		ldy #7
		lda IsPlayingExtendedWorlds
		beq @copy_normal
@copy_ext:
		lda HalfwayPageNybblesEx,y
		sta WRAM_HalfwayPageNybbles,y
		dey
		bpl @copy_ext
		jmp ReturnBank
@copy_normal:
		lda HalfwayPageNybbles,y
		sta WRAM_HalfwayPageNybbles,y
		dey
		bpl @copy_normal
		jmp ReturnBank

GetAreaDataAddrsNormal:
		CreateGetAreaDataAddrs EnemyAddrHOffsets, EnemyDataAddrLow, AreaDataHOffsets, AreaDataAddrLow
		jmp ReturnBank

GetAreaDataAddrsEx:
		CreateGetAreaDataAddrs EnemyAddrHOffsetsExt, EnemyDataAddrLowExt, AreaDataHOffsetsExt, AreaDataAddrLowExt
		jmp ReturnBank

GetAreaDataAddrs:
		lda IsPlayingExtendedWorlds
		beq @load_normal
		jmp GetAreaDataAddrsEx
@load_normal:
		jmp GetAreaDataAddrsNormal

WarpZoneNumbers:
.byte $04, $03, $02, $00         ; warp zone numbers, note spaces on middle
.byte $24, $05, $24, $00         ; zone, partly responsible for
.byte $08, $07, $06, $00         ; the minus world
.byte $2, $3, $0, $4

HalfwayPageNybbles:
.byte $56, $40
.byte $65, $70
.byte $66, $40
.byte $66, $40
.byte $66, $60
.byte $66, $60
.byte $67, $80
.byte $00, $00

WorldAddrOffsets:
.byte World1Areas-AreaAddrOffsets
.byte World2Areas-AreaAddrOffsets
.byte World3Areas-AreaAddrOffsets
.byte World4Areas-AreaAddrOffsets
.byte World5Areas-AreaAddrOffsets
.byte World6Areas-AreaAddrOffsets
.byte World7Areas-AreaAddrOffsets
.byte World8Areas-AreaAddrOffsets

AreaAddrOffsets:
World1Areas: .byte $25, $3B, $C0, $26, $60
World2Areas: .byte $28, $29, $01, $27, $62
World3Areas: .byte $24, $35, $20, $63
World4Areas: .byte $22, $29, $41, $2C, $61
World5Areas: .byte $2A, $31, $36, $67
World6Areas: .byte $2E, $23, $2D, $66
World7Areas: .byte $33, $29, $03, $37, $64
World8Areas: .byte $30, $32, $21, $65

AreaDataHOffsets:
.byte (AreaDataAddrLow_Water-AreaDataAddrLow)/2
.byte (AreaDataAddrLow_Ground-AreaDataAddrLow)/2
.byte (AreaDataAddrLow_Underground-AreaDataAddrLow)/2
.byte (AreaDataAddrLow_Castle-AreaDataAddrLow)/2

EnemyAddrHOffsets:
.byte (EnemyDataAddrLow_Water-EnemyDataAddrLow)/2
.byte (EnemyDataAddrLow_Ground-EnemyDataAddrLow)/2
.byte (EnemyDataAddrLow_Underground-EnemyDataAddrLow)/2
.byte (EnemyDataAddrLow_Castle-EnemyDataAddrLow)/2

EnemyDataAddrLow:
EnemyDataAddrLow_Water:
.word E_WaterArea1
.word E_WaterArea2
.word E_WaterArea3
.word E_WaterArea4
EnemyDataAddrLow_Ground:
.word E_GroundArea1
.word E_GroundArea2
.word E_GroundArea3
.word E_GroundArea4
.word E_GroundArea5
.word E_GroundArea6
.word E_GroundArea7
.word E_GroundArea8
.word E_GroundArea9
.word E_GroundArea10
.word E_GroundArea11
.word E_GroundArea12
.word E_GroundArea13
.word E_GroundArea14
.word E_GroundArea15
.word E_GroundArea16
.word E_GroundArea17
.word E_GroundArea18
.word E_GroundArea19
.word E_GroundArea20
.word E_GroundArea21
.word E_GroundArea22
.word E_GroundArea23
.word E_GroundArea24
.word E_GroundArea25
.word E_GroundArea26
.word E_GroundArea27
.word E_GroundArea28
EnemyDataAddrLow_Underground:
.word E_UndergroundArea1
.word E_UndergroundArea2
.word E_UndergroundArea3
EnemyDataAddrLow_Castle:
.word E_CastleArea1
.word E_CastleArea2
.word E_CastleArea3
.word E_CastleArea4
.word E_CastleArea5
.word E_CastleArea6
.word E_CastleArea7
.word E_CastleArea8

AreaDataAddrLow:
AreaDataAddrLow_Water:
.word L_WaterArea1
.word L_WaterArea2
.word L_WaterArea3
.word L_WaterArea4
AreaDataAddrLow_Ground:
.word L_GroundArea1
.word L_GroundArea2
.word L_GroundArea3
.word L_GroundArea4
.word L_GroundArea5
.word L_GroundArea6
.word L_GroundArea7
.word L_GroundArea8
.word L_GroundArea9
.word L_GroundArea10
.word L_GroundArea11
.word L_GroundArea12
.word L_GroundArea13
.word L_GroundArea14
.word L_GroundArea15
.word L_GroundArea16
.word L_GroundArea17
.word L_GroundArea18
.word L_GroundArea19
.word L_GroundArea20
.word L_GroundArea21
.word L_GroundArea22
.word L_GroundArea23
.word L_GroundArea24
.word L_GroundArea25
.word L_GroundArea26
.word L_GroundArea27
.word L_GroundArea28
AreaDataAddrLow_Underground:
.word L_UndergroundArea1
.word L_UndergroundArea2
.word L_UndergroundArea3
AreaDataAddrLow_Castle:
.word L_CastleArea1
.word L_CastleArea2
.word L_CastleArea3
.word L_CastleArea4
.word L_CastleArea5
.word L_CastleArea6
.word L_CastleArea7
.word L_CastleArea8


.include "leveldata_bin.asm"






;; underwater area in 5-2/6-2
L_WaterArea1:
.byte $41, $01, $B4, $34, $C8, $52, $F2, $51, $47, $D3, $6C, $03, $65, $49, $9E, $07, $BE, $01, $CC, $03, $FE, $07, $0D, $C9, $1E, $01, $6C, $01, $62, $35, $63, $53, $8A, $41, $AC, $01, $B3, $53, $E9, $51, $26, $C3, $27, $33, $63, $43, $64, $33, $BA, $60, $C9, $61, $CE, $0B, $D4, $31, $E5, $0D, $EE, $0F, $7D, $CA, $7D, $47, $FD
E_WaterArea1:
.byte $3B, $87, $66, $27, $CC, $27, $EE, $31, $87, $EE, $23, $A7, $3B, $87, $DB, $07, $FF

;; underwater area in 8-4
L_WaterArea3:
.byte $07, $0F, $0E, $02, $39, $73, $05, $8E, $2E, $0B, $B7, $0E, $64, $8E, $6E, $02, $CE, $06, $DE, $0F, $E6, $0D, $7D, $C7, $FD
E_WaterArea3:
.byte $07, $9B, $0A, $07, $B9, $1B, $66, $9B, $78, $07, $AE, $65, $E5, $FF


;; coin cache 1
L_UndergroundArea3:
.byte $48, $01, $0E, $01, $00, $5A, $3E, $06, $45, $46, $47, $46, $53, $44, $AE, $01, $DF, $4A, $4D, $C7, $0E, $81, $00, $5A, $2E, $04, $37, $28, $3A, $48, $46, $47, $C7, $0B, $CE, $0F, $DF, $4A, $4D, $C7, $0E, $81, $00, $5A, $33, $53, $43, $51, $46, $40, $47, $50, $53, $07, $55, $40, $56, $50, $62, $43, $64, $40, $65, $50, $71, $41, $73, $51, $83, $51, $94, $40, $95, $50, $A3, $50, $A5, $40, $A6, $50, $B3, $51, $B6, $40, $B7, $50, $C3, $53, $DF, $4A, $4D, $C7, $0E, $81, $00, $5A, $2E, $02, $36, $47, $37, $52, $3A, $49, $47, $25, $A7, $52, $D7, $07, $DF, $4A, $4D, $C7, $0E, $81, $00, $5A, $3E, $02, $44, $51, $53, $44, $54, $44, $55, $24, $A1, $54, $AE, $01, $B4, $21, $DF, $4A, $E5, $0B, $4D, $C7, $FD
E_UndergroundArea3:
.byte $1E, $A5, $0A, $2E, $28, $27, $0F, $03, $1E, $40, $07, $0F, $05, $1E, $24, $44, $0F, $07, $1E, $22, $6A, $0F, $09, $1E, $41, $68, $FF

;; 4-2 warpzone
L_GroundArea16:
.byte $10, $51, $4C, $00, $C7, $12, $C6, $42, $03, $92, $02, $42, $29, $12, $63, $12, $62, $42, $69, $14, $A5, $12, $A4, $42, $E2, $14, $E1, $44, $F8, $16, $37, $C1, $8F, $38, $02, $BB, $28, $7A, $68, $7A, $A8, $7A, $E0, $6A, $F0, $6A, $6D, $C5, $FD
E_GroundArea16:
.byte $FF

;; coin heaven 1
L_GroundArea12:
.byte $00, $C1, $4C, $00, $F4, $4F, $0D, $02, $02, $42, $43, $4F, $52, $C2, $DE, $00, $5A, $C2, $4D, $C7, $FD
E_GroundArea12:
.byte $0A, $AA, $0E, $28, $2A, $FF

;; coin heaven 2
L_GroundArea21:
.byte $06, $C1, $4C, $00, $F4, $4F, $0D, $02, $06, $20, $24, $4F, $35, $A0, $36, $20, $53, $46, $D5, $20, $D6, $20, $34, $A1, $73, $49, $74, $20, $94, $20, $B4, $20, $D4, $20, $F4, $20, $2E, $80, $59, $42, $4D, $C7, $FD
E_GroundArea21:
.byte $0A, $AA, $0E, $24, $4A, $FF

;; coin heaven 3
L_GroundArea26:
.byte $00, $C1, $4C, $00, $F4, $4F, $0D, $02, $02, $42, $43, $4F, $52, $C2, $DE, $00, $5A, $C2, $4D, $C7, $FD
E_GroundArea26:
.byte $0A, $AA, $0E, $31, $88, $FF

;; coin heaven 4
L_GroundArea27:
.byte $06, $C1, $4C, $00, $F4, $4F, $0D, $02, $06, $20, $24, $4F, $35, $A0, $36, $20, $53, $46, $D5, $20, $D6, $20, $34, $A1, $73, $49, $74, $20, $94, $20, $B4, $20, $D4, $20, $F4, $20, $2E, $80, $59, $42, $4D, $C7, $FD
E_GroundArea27:
.byte $0A, $AA, $1E, $23, $AA, $FF

;; stage exit area
L_GroundArea25:
.byte $90, $31, $39, $F1, $5F, $38, $6D, $C1, $AF, $26, $8D, $C7, $FD
E_GroundArea25:
.byte $FF













HalfwayPageNybblesEx:
	.byte $76, $50
	.byte $65, $50
	.byte $75, $B0
	.byte 0, 0

WorldAddrOffsetsExt:
.byte World1AreasExt-AreaAddrOffsetsExt
.byte World2AreasExt-AreaAddrOffsetsExt
.byte World3AreasExt-AreaAddrOffsetsExt
.byte World4AreasExt-AreaAddrOffsetsExt

AreaAddrOffsetsExt:
World1AreasExt: .byte $20, $2C, $40, $21, $60
World2AreasExt: .byte $22, $2C, $00, $23, $61
World3AreasExt: .byte $24, $25, $26, $62
World4AreasExt: .byte $27, $28, $29, $63

AreaDataHOffsetsExt:
.byte (AreaDataAddrLowExt_Water-AreaDataAddrLowExt)/2
.byte (AreaDataAddrLowExt_Ground-AreaDataAddrLowExt)/2
.byte (AreaDataAddrLowExt_Underground-AreaDataAddrLowExt)/2
.byte (AreaDataAddrLowExt_Castle-AreaDataAddrLowExt)/2

EnemyAddrHOffsetsExt:
.byte (EnemyDataAddrLowExt_Water-EnemyDataAddrLowExt)/2
.byte (EnemyDataAddrLowExt_Ground-EnemyDataAddrLowExt)/2
.byte (EnemyDataAddrLowExt_Underground-EnemyDataAddrLowExt)/2
.byte (EnemyDataAddrLowExt_Castle-EnemyDataAddrLowExt)/2

EnemyDataAddrLowExt:
EnemyDataAddrLowExt_Water:
.word E_WaterArea1Ext
EnemyDataAddrLowExt_Ground:
.word E_GroundArea1Ext
.word E_GroundArea2Ext
.word E_GroundArea3Ext
.word E_GroundArea4Ext
.word E_GroundArea5Ext
.word E_GroundArea6Ext
.word E_GroundArea7Ext
.word E_GroundArea8Ext
.word E_GroundArea9Ext
.word E_GroundArea10Ext
.word E_GroundArea11Ext
.word E_GroundArea12Ext
.word E_GroundArea13Ext
.word E_GroundArea14Ext
.word E_GroundArea15Ext
EnemyDataAddrLowExt_Underground:
.word E_UndergroundArea1Ext
.word E_UndergroundArea2Ext
EnemyDataAddrLowExt_Castle:
.word E_CastleArea1Ext
.word E_CastleArea2Ext
.word E_CastleArea3Ext
.word E_CastleArea4Ext

AreaDataAddrLowExt:
AreaDataAddrLowExt_Water:
.word L_WaterArea1Ext
AreaDataAddrLowExt_Ground:
.word L_GroundArea1Ext
.word L_GroundArea2Ext
.word L_GroundArea3Ext
.word L_GroundArea4Ext
.word L_GroundArea5Ext
.word L_GroundArea6Ext
.word L_GroundArea7Ext
.word L_GroundArea8Ext
.word L_GroundArea9Ext
.word L_GroundArea10Ext
.word L_GroundArea11Ext
.word L_GroundArea12Ext
.word L_GroundArea13Ext
.word L_GroundArea14Ext
.word L_GroundArea15Ext
AreaDataAddrLowExt_Underground:
.word L_UndergroundArea1Ext
.word L_UndergroundArea2Ext
AreaDataAddrLowExt_Castle:
.word L_CastleArea1Ext
.word L_CastleArea2Ext
.word L_CastleArea3Ext
.word L_CastleArea4Ext
.include "leveldata_ext.asm"

practice_callgate
control_bank


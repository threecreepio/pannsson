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

WarpZoneNumbers:
		.byte 2
		.byte 3
		.byte 4
		.byte 1
		.byte 6
		.byte 7
		.byte 8
		.byte 5
		.byte $B
		.byte $C
		.byte $D

LoadWarpzone:
		lda WarpZoneControl
		and #$F
		tax
		lda WarpZoneNumbers,x
		ldy IsPlayingExtendedWorlds ; todo
		beq @isnot
		sec
		sbc #9
@isnot:
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

LoadAreaPointer:
		jsr LoadAreaPointerInner
		jmp ReturnBank

LoadAreaPointerInner:
		ldy WorldNumber
		lda IsPlayingExtendedWorlds
		beq @load_normal
		; FindAreaPointerEx
		lda WorldAddrOffsetsEx,y
		clc
		adc AreaNumber
		tay
		lda AreaAddrOffsetsEx,y
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

HalfwayPageNybblesEx:
		.byte $76, $50
		.byte $65, $50
		.byte $75, $B0
		.byte 0, 0

HalfwayPageNybbles:
		.byte $66, $60
		.byte $88, $60
		.byte $66, $70
		.byte $77, $60
		
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
		CreateGetAreaDataAddrs EnemyAddrHOffsetsEx, EnemyDataAddrLowEx, AreaDataHOffsetsEx, AreaDataAddrLowEx
		jmp ReturnBank

GetAreaDataAddrs:
		lda IsPlayingExtendedWorlds
		beq @load_normal
		jmp GetAreaDataAddrsEx
@load_normal:
		jmp GetAreaDataAddrsNormal

WorldAddrOffsets:
AreaAddrOffsets:
World1Areas:
EnemyAddrHOffsets:
EnemyDataAddrLow:
AreaDataHOffsets:
AreaDataAddrLow:
WorldAddrOffsetsEx:
AreaAddrOffsetsEx:
EnemyAddrHOffsetsEx:
EnemyDataAddrLowEx:
AreaDataHOffsetsEx:
AreaDataAddrLowEx:
practice_callgate
control_bank


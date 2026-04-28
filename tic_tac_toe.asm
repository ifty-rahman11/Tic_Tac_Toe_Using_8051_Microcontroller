ORG 0000H
        LJMP START

RS        EQU P2.0
E         EQU P2.2
LCDPORT   EQU P3

LCD_LINE1 EQU 080H
LCD_LINE2 EQU 0C0H
LCD_LINE3 EQU 094H
LCD_LINE4 EQU 0D4H

C1      EQU 30H
C2      EQU 31H
C3      EQU 32H
C4      EQU 33H
C5      EQU 34H
C6      EQU 35H
C7      EQU 36H
C8      EQU 37H
C9      EQU 38H

CURP    EQU 39H
MODEF   EQU 3AH
WINNER  EQU 3BH

;========================
; START
;========================
START:
        MOV P1,#0FFH
        LCALL DELAY_BIG
        LCALL DELAY_BIG
        LCALL LCD_INIT

MAIN_MENU:
        LCALL CLEAR_BOARD
        MOV WINNER,#00H

        MOV A,#01H
        LCALL LCD_CMD

        MOV A,#LCD_LINE1
        LCALL LCD_CMD
        MOV DPTR,#MSG_TITLE
        LCALL LCD_PRINT

        MOV A,#LCD_LINE2
        LCALL LCD_CMD
        MOV DPTR,#MSG1
        LCALL LCD_PRINT

        MOV A,#LCD_LINE3
        LCALL LCD_CMD
        MOV DPTR,#MSG2
        LCALL LCD_PRINT

        MOV A,#LCD_LINE4
        LCALL LCD_CMD
        MOV DPTR,#MSG_SEL
        LCALL LCD_PRINT

WAIT_MODE:
        LCALL KEY_SCAN
        JZ WAIT_MODE

        CJNE A,#'1',CHK_AI
        MOV MODEF,#00H
        LJMP START_GAME

CHK_AI:
        CJNE A,#'2',WAIT_MODE
        MOV MODEF,#01H
        LJMP START_GAME

;========================
; START GAME
;========================
START_GAME:
        MOV CURP,#01H
        MOV WINNER,#00H
        LCALL RENDER_BOARD

GAME_LOOP:
        MOV A,WINNER
        JNZ GAME_OVER

        MOV A,MODEF
        JZ HUMAN_TURN
        MOV A,CURP
        CJNE A,#02H,HUMAN_TURN

AI_TURN:
        LCALL AI_MOVE
        LCALL CHECK_WIN
        MOV WINNER,A
        MOV A,WINNER
        JNZ AI_SHOW_END

        LCALL CHECK_DRAW
        CJNE A,#01H,AI_SET_X
        MOV WINNER,#03H
        LJMP AI_SHOW_END

AI_SET_X:
        MOV CURP,#01H
        LCALL RENDER_BOARD
        LJMP GAME_LOOP

AI_SHOW_END:
        LCALL RENDER_BOARD
        LJMP GAME_LOOP

;========================
; HUMAN TURN
;========================
HUMAN_TURN:
WAIT_KEY:
        LCALL KEY_SCAN
        JZ WAIT_KEY

        CJNE A,#'C',NOT_RESTART
        LJMP MAIN_MENU

NOT_RESTART:
        LCALL HANDLE_KEY
        JNC WAIT_KEY

        LCALL CHECK_WIN
        MOV WINNER,A
        MOV A,WINNER
        JNZ SHOW_END_BOARD

        LCALL CHECK_DRAW
        CJNE A,#01H,TOGGLE_PLAYER
        MOV WINNER,#03H
        LJMP SHOW_END_BOARD

TOGGLE_PLAYER:
        MOV A,CURP
        CJNE A,#01H,SET_X
        MOV CURP,#02H
        LCALL RENDER_BOARD
        LJMP GAME_LOOP

SET_X:
        MOV CURP,#01H
        LCALL RENDER_BOARD
        LJMP GAME_LOOP

SHOW_END_BOARD:
        LCALL RENDER_BOARD
        LJMP GAME_LOOP

;========================
; GAME OVER
;========================
GAME_OVER:
        MOV A,#01H
        LCALL LCD_CMD

        MOV A,#LCD_LINE1
        LCALL LCD_CMD
        MOV DPTR,#MSG_GOVER
        LCALL LCD_PRINT

        MOV A,#LCD_LINE2
        LCALL LCD_CMD
        MOV A,WINNER
        CJNE A,#01H,GO_CHK_O
        MOV DPTR,#MSG_XWIN
        LCALL LCD_PRINT
        LJMP GO_RST

GO_CHK_O:
        CJNE A,#02H,GO_DRAW
        MOV DPTR,#MSG_OWIN
        LCALL LCD_PRINT
        LJMP GO_RST

GO_DRAW:
        MOV DPTR,#MSG_DRAW
        LCALL LCD_PRINT

GO_RST:
        MOV A,#LCD_LINE3
        LCALL LCD_CMD
        MOV DPTR,#MSG_RST
        LCALL LCD_PRINT

        MOV A,#LCD_LINE4
        LCALL LCD_CMD
        MOV DPTR,#MSG_BLANK
        LCALL LCD_PRINT

WAIT_RST:
        LCALL KEY_SCAN
        JZ WAIT_RST
        CJNE A,#'C',WAIT_RST
        LJMP MAIN_MENU

;========================
; HANDLE KEY
;========================
HANDLE_KEY:
        CLR C
        CJNE A,#'1',HK2
        MOV R0,#C1
        LJMP TRY_PLACE
HK2:    CJNE A,#'2',HK3
        MOV R0,#C2
        LJMP TRY_PLACE
HK3:    CJNE A,#'3',HK4
        MOV R0,#C3
        LJMP TRY_PLACE
HK4:    CJNE A,#'4',HK5
        MOV R0,#C4
        LJMP TRY_PLACE
HK5:    CJNE A,#'5',HK6
        MOV R0,#C5
        LJMP TRY_PLACE
HK6:    CJNE A,#'6',HK7
        MOV R0,#C6
        LJMP TRY_PLACE
HK7:    CJNE A,#'7',HK8
        MOV R0,#C7
        LJMP TRY_PLACE
HK8:    CJNE A,#'8',HK9
        MOV R0,#C8
        LJMP TRY_PLACE
HK9:    CJNE A,#'9',HK_BAD
        MOV R0,#C9
        LJMP TRY_PLACE
HK_BAD: RET

TRY_PLACE:
        MOV A,@R0
        JZ DO_PLACE
        LCALL SHOW_INVALID
        RET

DO_PLACE:
        MOV A,CURP
        MOV @R0,A
        SETB C
        RET

;========================
; AI MOVE - Priority based strategy:
; 1. Win  : complete own line of 2
; 2. Block: stop X from winning
; 3. Fork : create 2 ways to win
; 4. Block fork: stop X creating 2 ways
; 5. Center
; 6. Opposite corner of X
; 7. Any corner
; 8. Any edge
;========================
AI_MOVE:
        ; --- Priority 1: Win immediately ---
        LCALL FIND_WIN_O
        JC AI_DONE

        ; --- Priority 2: Block X from winning ---
        LCALL FIND_BLOCK_X
        JC AI_DONE

        ; --- Priority 3: Create a fork (two ways to win) ---
        LCALL FIND_FORK_O
        JC AI_DONE

        ; --- Priority 4: Block X fork ---
        LCALL FIND_FORK_X
        JC AI_DONE

        ; --- Priority 5: Take center ---
        MOV R0,#C5
        MOV A,@R0
        JZ AI_DONE

        ; --- Priority 6: Opposite corner of X ---
        ; If X is at C1, take C9 and vice versa
        MOV A,C1
        CJNE A,#01H,AI_OPP2
        MOV R0,#C9
        MOV A,@R0
        JZ AI_DONE
AI_OPP2:
        MOV A,C9
        CJNE A,#01H,AI_OPP3
        MOV R0,#C1
        MOV A,@R0
        JZ AI_DONE
AI_OPP3:
        MOV A,C3
        CJNE A,#01H,AI_OPP4
        MOV R0,#C7
        MOV A,@R0
        JZ AI_DONE
AI_OPP4:
        MOV A,C7
        CJNE A,#01H,AI_CORNER
        MOV R0,#C3
        MOV A,@R0
        JZ AI_DONE

        ; --- Priority 7: Any empty corner ---
AI_CORNER:
        MOV R0,#C1
        MOV A,@R0
        JZ AI_DONE
        MOV R0,#C3
        MOV A,@R0
        JZ AI_DONE
        MOV R0,#C7
        MOV A,@R0
        JZ AI_DONE
        MOV R0,#C9
        MOV A,@R0
        JZ AI_DONE

        ; --- Priority 8: Any empty edge ---
        MOV R0,#C2
        MOV A,@R0
        JZ AI_DONE
        MOV R0,#C4
        MOV A,@R0
        JZ AI_DONE
        MOV R0,#C6
        MOV A,@R0
        JZ AI_DONE
        MOV R0,#C8
        MOV A,@R0
        JZ AI_DONE
        RET

AI_DONE:
        MOV @R0,#02H
        LCALL DELAY_BIG
        RET

;========================
; FIND WIN FOR O (player=2)
;========================
FIND_WIN_O:
        CLR C
        MOV R1,#02H
        MOV 2FH,R1
        LCALL TRY_ROW1
        JC FWO_RET
        LCALL TRY_ROW2
        JC FWO_RET
        LCALL TRY_ROW3
        JC FWO_RET
        LCALL TRY_COL1
        JC FWO_RET
        LCALL TRY_COL2
        JC FWO_RET
        LCALL TRY_COL3
        JC FWO_RET
        LCALL TRY_DIA1
        JC FWO_RET
        LCALL TRY_DIA2
FWO_RET:
        RET

;========================
; FIND BLOCK FOR X (player=1)
;========================
FIND_BLOCK_X:
        CLR C
        MOV R1,#01H
        MOV 2FH,R1
        LCALL TRY_ROW1
        JC FBX_RET
        LCALL TRY_ROW2
        JC FBX_RET
        LCALL TRY_ROW3
        JC FBX_RET
        LCALL TRY_COL1
        JC FBX_RET
        LCALL TRY_COL2
        JC FBX_RET
        LCALL TRY_COL3
        JC FBX_RET
        LCALL TRY_DIA1
        JC FBX_RET
        LCALL TRY_DIA2
FBX_RET:
        RET

;========================
; FIND FORK FOR O
; A fork = a cell where placing O creates
; TWO different lines each having 1 O and 2 empty
; We test each empty cell: place O, count threats, undo
; Use RAM 2EH as temp cell address, 2DH as threat counter
;========================
FIND_FORK_O:
        CLR C
        MOV R0,#C1
FF_O_LOOP:
        MOV A,@R0
        JNZ FF_O_NEXT
        ; cell is empty - temporarily place O
        MOV @R0,#02H
        MOV 2EH,R0
        LCALL COUNT_O_THREATS
        ; restore cell
        MOV R0,2EH
        MOV @R0,#00H
        ; if threats >= 2 this is a fork cell
        MOV A,2DH
        CJNE A,#02H,FF_O_LT2
        ; found fork - set R0 to this cell
        MOV R0,2EH
        SETB C
        RET
FF_O_LT2:
        MOV R0,2EH
FF_O_NEXT:
        MOV A,R0
        CJNE A,#C9,FF_O_INC
        CLR C
        RET
FF_O_INC:
        INC R0
        SJMP FF_O_LOOP

;========================
; FIND FORK FOR X (to block)
; Same logic but places X temporarily
;========================
FIND_FORK_X:
        CLR C
        MOV R0,#C1
FF_X_LOOP:
        MOV A,@R0
        JNZ FF_X_NEXT
        MOV @R0,#01H
        MOV 2EH,R0
        LCALL COUNT_X_THREATS
        MOV R0,2EH
        MOV @R0,#00H
        MOV A,2DH
        CJNE A,#02H,FF_X_LT2
        ; X would have fork here - block it
        ; but only if placing O here doesn't let X win
        MOV R0,2EH
        SETB C
        RET
FF_X_LT2:
        MOV R0,2EH
FF_X_NEXT:
        MOV A,R0
        CJNE A,#C9,FF_X_INC
        CLR C
        RET
FF_X_INC:
        INC R0
        SJMP FF_X_LOOP

;========================
; COUNT_O_THREATS
; Count how many lines have exactly 1 O and 2 empty
; Result in 2DH
;========================
COUNT_O_THREATS:
        MOV 2DH,#00H
        ; Row 1-2-3
        MOV R2,#C1
        MOV R3,#C2
        MOV R4,#C3
        LCALL CHECK_THREAT_O
        ; Row 4-5-6
        MOV R2,#C4
        MOV R3,#C5
        MOV R4,#C6
        LCALL CHECK_THREAT_O
        ; Row 7-8-9
        MOV R2,#C7
        MOV R3,#C8
        MOV R4,#C9
        LCALL CHECK_THREAT_O
        ; Col 1-4-7
        MOV R2,#C1
        MOV R3,#C4
        MOV R4,#C7
        LCALL CHECK_THREAT_O
        ; Col 2-5-8
        MOV R2,#C2
        MOV R3,#C5
        MOV R4,#C8
        LCALL CHECK_THREAT_O
        ; Col 3-6-9
        MOV R2,#C3
        MOV R3,#C6
        MOV R4,#C9
        LCALL CHECK_THREAT_O
        ; Diag 1-5-9
        MOV R2,#C1
        MOV R3,#C5
        MOV R4,#C9
        LCALL CHECK_THREAT_O
        ; Diag 3-5-7
        MOV R2,#C3
        MOV R3,#C5
        MOV R4,#C7
        LCALL CHECK_THREAT_O
        RET

;========================
; COUNT_X_THREATS
;========================
COUNT_X_THREATS:
        MOV 2DH,#00H
        MOV R2,#C1
        MOV R3,#C2
        MOV R4,#C3
        LCALL CHECK_THREAT_X
        MOV R2,#C4
        MOV R3,#C5
        MOV R4,#C6
        LCALL CHECK_THREAT_X
        MOV R2,#C7
        MOV R3,#C8
        MOV R4,#C9
        LCALL CHECK_THREAT_X
        MOV R2,#C1
        MOV R3,#C4
        MOV R4,#C7
        LCALL CHECK_THREAT_X
        MOV R2,#C2
        MOV R3,#C5
        MOV R4,#C8
        LCALL CHECK_THREAT_X
        MOV R2,#C3
        MOV R3,#C6
        MOV R4,#C9
        LCALL CHECK_THREAT_X
        MOV R2,#C1
        MOV R3,#C5
        MOV R4,#C9
        LCALL CHECK_THREAT_X
        MOV R2,#C3
        MOV R3,#C5
        MOV R4,#C7
        LCALL CHECK_THREAT_X
        RET

;========================
; CHECK_THREAT_O
; If line has exactly 1 O and 0 X, increment 2DH
; (no enemy pieces blocking)
;========================
CHECK_THREAT_O:
        MOV A,R2
        MOV R0,A
        MOV A,@R0
        MOV B,A          ; B = cell a
        MOV A,R3
        MOV R0,A
        MOV A,@R0
        MOV R5,A         ; R5 = cell b
        MOV A,R4
        MOV R0,A
        MOV A,@R0        ; A = cell c

        ; check no X (value 1) in line
        MOV R6,B
        CJNE A,#01H,CTO_1
        RET              ; X present, not a threat
CTO_1:
        MOV A,R5
        CJNE A,#01H,CTO_2
        RET
CTO_2:
        MOV A,R6
        CJNE A,#01H,CTO_3
        RET
CTO_3:
        ; count O's (value 2) in line
        MOV R7,#00H
        MOV A,R6
        CJNE A,#02H,CTO_4
        INC R7
CTO_4:
        MOV A,R5
        CJNE A,#02H,CTO_5
        INC R7
CTO_5:
        MOV A,R4
        MOV R0,A
        MOV A,@R0
        CJNE A,#02H,CTO_6
        INC R7
CTO_6:
        ; if exactly 1 O in line -> this is a threat
        MOV A,R7
        CJNE A,#01H,CTO_DONE
        INC 2DH
CTO_DONE:
        RET

;========================
; CHECK_THREAT_X
; If line has exactly 1 X and 0 O, increment 2DH
;========================
CHECK_THREAT_X:
        MOV A,R2
        MOV R0,A
        MOV A,@R0
        MOV B,A
        MOV A,R3
        MOV R0,A
        MOV A,@R0
        MOV R5,A
        MOV A,R4
        MOV R0,A
        MOV A,@R0

        MOV R6,B
        CJNE A,#02H,CTX_1
        RET
CTX_1:
        MOV A,R5
        CJNE A,#02H,CTX_2
        RET
CTX_2:
        MOV A,R6
        CJNE A,#02H,CTX_3
        RET
CTX_3:
        MOV R7,#00H
        MOV A,R6
        CJNE A,#01H,CTX_4
        INC R7
CTX_4:
        MOV A,R5
        CJNE A,#01H,CTX_5
        INC R7
CTX_5:
        MOV A,R4
        MOV R0,A
        MOV A,@R0
        CJNE A,#01H,CTX_6
        INC R7
CTX_6:
        MOV A,R7
        CJNE A,#01H,CTX_DONE
        INC 2DH
CTX_DONE:
        RET

TRY_ROW1:
        MOV R2,#C1
        MOV R3,#C2
        MOV R4,#C3
        SJMP CHECK_LINE
TRY_ROW2:
        MOV R2,#C4
        MOV R3,#C5
        MOV R4,#C6
        SJMP CHECK_LINE
TRY_ROW3:
        MOV R2,#C7
        MOV R3,#C8
        MOV R4,#C9
        SJMP CHECK_LINE
TRY_COL1:
        MOV R2,#C1
        MOV R3,#C4
        MOV R4,#C7
        SJMP CHECK_LINE
TRY_COL2:
        MOV R2,#C2
        MOV R3,#C5
        MOV R4,#C8
        SJMP CHECK_LINE
TRY_COL3:
        MOV R2,#C3
        MOV R3,#C6
        MOV R4,#C9
        SJMP CHECK_LINE
TRY_DIA1:
        MOV R2,#C1
        MOV R3,#C5
        MOV R4,#C9
        SJMP CHECK_LINE
TRY_DIA2:
        MOV R2,#C3
        MOV R3,#C5
        MOV R4,#C7

CHECK_LINE:
        MOV A,R2
        MOV R0,A
        MOV A,@R0
        MOV B,A
        MOV A,R3
        MOV R0,A
        MOV A,@R0
        MOV R5,A
        MOV A,R4
        MOV R0,A
        MOV A,@R0
        MOV R6,B

        CJNE A,2FH,CL_T2
        MOV A,R5
        CJNE A,2FH,CL_T2
        MOV A,B
        JNZ CL_T2
        MOV A,R2
        MOV R0,A
        SETB C
        RET
CL_T2:
        MOV A,R5
        CJNE A,2FH,CL_T3
        MOV A,R6
        CJNE A,2FH,CL_T3
        MOV A,R3
        MOV R0,A
        MOV A,@R0
        JNZ CL_T3
        MOV A,R3
        MOV R0,A
        SETB C
        RET
CL_T3:
        MOV A,R6
        CJNE A,2FH,CL_NONE
        MOV A,R5
        CJNE A,2FH,CL_NONE
        MOV A,R4
        MOV R0,A
        MOV A,@R0
        JNZ CL_NONE
        MOV A,R4
        MOV R0,A
        SETB C
        RET
CL_NONE:
        CLR C
        RET

;========================
; CLEAR BOARD
;========================
CLEAR_BOARD:
        MOV R0,#C1
        MOV R7,#09
CB1:
        MOV @R0,#00H
        INC R0
        DJNZ R7,CB1
        RET

;========================
; RENDER BOARD
;
; 20x4 LCD layout:
; Row1: "7:_ 8:_ 9:_  T: X"  (18 chars)
; Row2: "4:_ 5:_ 6:_       "
; Row3: "1:_ 2:_ 3:_       "
; Row4: "C=Menu            "
;========================
RENDER_BOARD:
        MOV A,#01H
        LCALL LCD_CMD

        MOV A,#LCD_LINE1
        LCALL LCD_CMD

        MOV A,#'7'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C7
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'8'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C8
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'9'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C9
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'T'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,CURP
        CJNE A,#01H,RB_O1
        MOV A,#'X'
        LCALL LCD_DATA
        LJMP RB_LINE2
RB_O1:
        MOV A,#'O'
        LCALL LCD_DATA

RB_LINE2:
        MOV A,#LCD_LINE2
        LCALL LCD_CMD

        MOV A,#'4'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C4
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'5'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C5
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'6'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C6
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA

        MOV A,#LCD_LINE3
        LCALL LCD_CMD

        MOV A,#'1'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C1
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'2'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C2
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA
        MOV A,#' '
        LCALL LCD_DATA
        MOV A,#'3'
        LCALL LCD_DATA
        MOV A,#':'
        LCALL LCD_DATA
        MOV A,C3
        LCALL CELL_TO_CHAR
        LCALL LCD_DATA

        MOV A,#LCD_LINE4
        LCALL LCD_CMD
        MOV DPTR,#MSG_HINT
        LCALL LCD_PRINT

        RET

;========================
; CELL VALUE TO CHAR
;========================
CELL_TO_CHAR:
        CJNE A,#00H,CTC1
        MOV A,#'_'
        RET
CTC1:
        CJNE A,#01H,CTC2
        MOV A,#'X'
        RET
CTC2:
        MOV A,#'O'
        RET

;========================
; CHECK DRAW
;========================
CHECK_DRAW:
        MOV R0,#C1
        MOV R7,#09
CD1:
        MOV A,@R0
        JZ CD_NOT
        INC R0
        DJNZ R7,CD1
        MOV A,#01H
        RET
CD_NOT:
        MOV A,#00H
        RET

;========================
; CHECK WIN
;========================
CHECK_WIN:
        MOV A,C1
        JZ CW2
        CJNE A,C2,CW2
        CJNE A,C3,CW2
        RET
CW2:
        MOV A,C4
        JZ CW3
        CJNE A,C5,CW3
        CJNE A,C6,CW3
        RET
CW3:
        MOV A,C7
        JZ CW4
        CJNE A,C8,CW4
        CJNE A,C9,CW4
        RET
CW4:
        MOV A,C1
        JZ CW5
        CJNE A,C4,CW5
        CJNE A,C7,CW5
        RET
CW5:
        MOV A,C2
        JZ CW6
        CJNE A,C5,CW6
        CJNE A,C8,CW6
        RET
CW6:
        MOV A,C3
        JZ CW7
        CJNE A,C6,CW7
        CJNE A,C9,CW7
        RET
CW7:
        MOV A,C1
        JZ CW8
        CJNE A,C5,CW8
        CJNE A,C9,CW8
        RET
CW8:
        MOV A,C3
        JZ CW_NONE
        CJNE A,C5,CW_NONE
        CJNE A,C7,CW_NONE
        RET
CW_NONE:
        MOV A,#00H
        RET

;========================
; SHOW INVALID
;========================
SHOW_INVALID:
        MOV A,#LCD_LINE4
        LCALL LCD_CMD
        MOV DPTR,#MSG_INV
        LCALL LCD_PRINT
        LCALL DELAY_BIG
        LCALL DELAY_BIG
        LCALL RENDER_BOARD
        RET

;========================
; LCD ROUTINES
;========================
LCD_INIT:
        MOV A,#38H
        LCALL LCD_CMD
        MOV A,#0CH
        LCALL LCD_CMD
        MOV A,#01H
        LCALL LCD_CMD
        MOV A,#06H
        LCALL LCD_CMD
        MOV A,#LCD_LINE1
        LCALL LCD_CMD
        RET

LCD_CMD:
        CLR RS
        MOV LCDPORT,A
        SETB E
        LCALL DELAY
        CLR E
        LCALL DELAY
        RET

LCD_DATA:
        SETB RS
        MOV LCDPORT,A
        SETB E
        LCALL DELAY
        CLR E
        LCALL DELAY
        RET

LCD_PRINT:
LP1:
        CLR A
        MOVC A,@A+DPTR
        JZ LP2
        LCALL LCD_DATA
        INC DPTR
        LJMP LP1
LP2:
        RET

;========================
; KEYPAD SCAN
;
; Physical keypad wiring (from Proteus schematic):
;   Columns: C0=rightmost, C1, C2, C3=leftmost
;   Rows:    R0=bottom(ON row), R1, R2, R3=top
;
;   C0 col: 7(R3), 4(R2), 1(R1), C(R0)
;   C1 col: 8(R3), 5(R2), 2(R1), 0(R0)
;   C2 col: 9(R3), 6(R2), 3(R1), =(R0)
;   C3 col: /(R3), *(R2), -(R1), +(R0)
;
; P1.0=C0(col drive), P1.1=C1, P1.2=C2, P1.3=C3
; P1.4=R0(row read),  P1.5=R1, P1.6=R2, P1.7=R3
;========================
; KEYPAD WIRING (verified from schematic):
;   P1.0 = C0 = keypad row A  (top row:    /, 9, 8, 7)  <- DRIVE output
;   P1.1 = C1 = keypad row B  (           *, 6, 5, 4)  <- DRIVE output
;   P1.2 = C2 = keypad row C  (           -, 3, 2, 1)  <- DRIVE output
;   P1.3 = C3 = keypad row D  (bottom row: +, =, 0, C)  <- DRIVE output
;   P1.4 = R0 = keypad col1  (rightmost: 7, 4, 1, C)   <- READ input
;   P1.5 = R1 = keypad col2  (           8, 5, 2, 0)   <- READ input
;   P1.6 = R2 = keypad col3  (           9, 6, 3, =)   <- READ input
;   P1.7 = R3 = keypad col4  (leftmost:  /, *, -, +)   <- READ input
;
; Scan: drive one row LOW, read columns P1.4-P1.7
;   Drive P1.0 low -> P1=FEH  read: P1.4='7' P1.5='8' P1.6='9' P1.7='/'
;   Drive P1.1 low -> P1=FDH  read: P1.4='4' P1.5='5' P1.6='6' P1.7='*'
;   Drive P1.2 low -> P1=FBH  read: P1.4='1' P1.5='2' P1.6='3' P1.7='-'
;   Drive P1.3 low -> P1=F7H  read: P1.4='C' P1.5='0' P1.6='=' P1.7='+'
;========================
KEY_SCAN:
        ; --- Drive row A (P1.0) low ---
        MOV P1,#0FEH
        NOP
        NOP
        JNB P1.4,KEY_7
        JNB P1.5,KEY_8
        JNB P1.6,KEY_9
        JNB P1.7,KEY_DIV

        ; --- Drive row B (P1.1) low ---
        MOV P1,#0FDH
        NOP
        NOP
        JNB P1.4,KEY_4
        JNB P1.5,KEY_5
        JNB P1.6,KEY_6
        JNB P1.7,KEY_MUL

        ; --- Drive row C (P1.2) low ---
        MOV P1,#0FBH
        NOP
        NOP
        JNB P1.4,KEY_1
        JNB P1.5,KEY_2
        JNB P1.6,KEY_3
        JNB P1.7,KEY_SUB

        ; --- Drive row D (P1.3) low ---
        MOV P1,#0F7H
        NOP
        NOP
        JNB P1.4,KEY_C
        JNB P1.5,KEY_0
        JNB P1.6,KEY_EQ
        JNB P1.7,KEY_ADD

        MOV A,#00H
        RET

KEY_7:
        MOV A,#'7'
        LCALL WAIT_RELEASE
        RET
KEY_8:
        MOV A,#'8'
        LCALL WAIT_RELEASE
        RET
KEY_9:
        MOV A,#'9'
        LCALL WAIT_RELEASE
        RET
KEY_DIV:
        MOV A,#'/'
        LCALL WAIT_RELEASE
        RET
KEY_4:
        MOV A,#'4'
        LCALL WAIT_RELEASE
        RET
KEY_5:
        MOV A,#'5'
        LCALL WAIT_RELEASE
        RET
KEY_6:
        MOV A,#'6'
        LCALL WAIT_RELEASE
        RET
KEY_MUL:
        MOV A,#'*'
        LCALL WAIT_RELEASE
        RET
KEY_1:
        MOV A,#'1'
        LCALL WAIT_RELEASE
        RET
KEY_2:
        MOV A,#'2'
        LCALL WAIT_RELEASE
        RET
KEY_3:
        MOV A,#'3'
        LCALL WAIT_RELEASE
        RET
KEY_SUB:
        MOV A,#'-'
        LCALL WAIT_RELEASE
        RET
KEY_C:
        MOV A,#'C'
        LCALL WAIT_RELEASE
        RET
KEY_0:
        MOV A,#'0'
        LCALL WAIT_RELEASE
        RET
KEY_EQ:
        MOV A,#'='
        LCALL WAIT_RELEASE
        RET
KEY_ADD:
        MOV A,#'+'
        LCALL WAIT_RELEASE
        RET

;========================
; WAIT KEY RELEASE
; Release = all column inputs (P1.4-P1.7) back HIGH
; Set all row drives HIGH (P1=FFH) so no column is pulled low
;========================
WAIT_RELEASE:
        PUSH ACC
WR1:
        MOV P1,#0FFH
        NOP
        NOP
        NOP
        MOV A,P1
        ANL A,#0F0H
        CJNE A,#0F0H,WR1
        LCALL DELAY
        POP ACC
        RET

;========================
; DELAYS
;========================
DELAY:
        MOV R6,#20
D1:
        MOV R7,#255
D2:
        DJNZ R7,D2
        DJNZ R6,D1
        RET

DELAY_BIG:
        MOV R4,#80
D3:
        LCALL DELAY
        DJNZ R4,D3
        RET

;========================
; STRINGS (max 20 chars each)
;========================
MSG_TITLE: DB 'TIC-TAC-TOE GAME    ',0
MSG1:      DB '1: Player vs Player ',0
MSG2:      DB '2: Player vs AI     ',0
MSG_SEL:   DB 'Press 1 or 2        ',0
MSG_HINT:  DB 'C=Menu              ',0
MSG_INV:   DB 'Cell taken! Retry   ',0
MSG_GOVER: DB '*** GAME OVER ***   ',0
MSG_XWIN:  DB 'Player X WINS!      ',0
MSG_OWIN:  DB 'Player O WINS!      ',0
MSG_DRAW:  DB 'Its a DRAW!         ',0
MSG_RST:   DB 'Press C to restart  ',0
MSG_BLANK: DB '                    ',0

        END
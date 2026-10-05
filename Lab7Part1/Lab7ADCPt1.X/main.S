// Hunter Clezie
// RCET3375
// Lab6TimerPt4
// https://github.com/hunterclezie-pixel/Lab-06---Timers.git

; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

; config statements should precede project file includes.
#include <xc.inc>  
    ; General Purpose Registers
    W_TEMP EQU 0x70 ; Used as part of the temporary hold for save/restore
    STATUS_TEMP EQU 0x71 ; Used as part of the temporary hold for save/restore
    intersection_state  EQU 0x72 ; Complete packed intersection state
    count_temp EQU 0x73 ; Temporary STATE_COUNT value
    flags_temp EQU 0x74 ; Temporary lower state flags
    portb_old EQU 0x75 ; Previous RB4/RB5 values
    portb_now EQU 0x76 ; Current RB4/RB5 values
 
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    GOTO ISRHandler

; Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2
 
Setup:
    BCF 0x03,6      ; Sets Bank 0
    BCF 0x03,5      ; Sets Bank 0
    CLRF 0x05	    ; Clearing PortA
    CLRF 0x06       ; Clearing PORTB
    CLRF 0x07       ; Clearing PORTC
    CLRF intersection_state ; Initial state = 00000000

    BCF 0x03,6      ; Sets Bank 1
    BSF 0x03,5      ; Sets Bank 1
    MOVLW 0xFF
    MOVWF 0x86      ; Setting PORTB as inputs
    CLRF 0x87       ; Setting PORTC as outputs
    MOVLW 0xC0      ; Bits 7:6 inputs, bits 5:0 outputs        
    MOVWF 0x85      ; TRISA, RA0-RA5 traffic LEDs
    MOVLW 0x30
    MOVWF 0x96      ; Enable IOC on RB4 and RB5
    BSF 0x81,7      ; Disabling internal PORTB pull-ups
    BSF 0x81,6      ; INTEDG = 1, RB0/INT triggers low-to-high

    BSF 0x03,6      ; Sets Bank 3
    BSF 0x03,5	    ; Sets Bank 3
    CLRF 0x88	    ; Setting ANSEL LOW for digital I/O
    CLRF 0x89       ; Setting ANSELH LOW for digital I/O
    
    ; Interrupt and Timer1 Setup
    BCF 0x03,6      ; Sets Bank 0
    BCF 0x03,5      ; Sets Bank 0
    CLRF T1CON      ; Timer1 off while configuring
    MOVLW 0x0B
    MOVWF TMR1H     ; Timer1 preload high byte
    MOVLW 0xDC
    MOVWF TMR1L     ; Timer1 preload low byte
    MOVLW 0x30	    ; T1CON: 1:8 prescale, internal clock, gate off
    MOVWF T1CON		    
    BCF PIR1,0      ; Clearing TMR1IF
    
    BCF 0x03,6      ; Sets Bank 1
    BSF 0x03,5      ; Sets Bank 1
    BSF PIE1,0      ; Enabling Timer1 interrupt
    
    BCF 0x03,6      ; Sets Bank 0
    BCF 0x03,5      ; Sets Bank 0
    MOVF PORTB,W
    ANDLW 0x30
    MOVWF portb_old
    BCF INTCON,0     ; Clear RBIF
    BCF INTCON,1     ; Clear INTF
    BSF INTCON,4     ; Enable external INT
    BSF INTCON,3     ; Enable PORTB IOC
    BSF INTCON,6    ; Enabling peripheral interrupts
    BSF INTCON,7    ; Enabling global interrupts
    BSF T1CON,0	    ; TMR1ON = 1, start Timer1
    GOTO Main    

Main:
    ; Display complete packed state on PORTC
    MOVF intersection_state,W
    MOVWF PORTC

    ; Update actual traffic-light LEDs on PORTA
    CALL UpdateLights

    ; Get STATE_COUNT from upper nibble
    SWAPF intersection_state,W
    ANDLW 0x0F
    MOVWF count_temp

    ; Check TRANSITION bit
    BTFSC intersection_state,3
    GOTO CheckYellowTime
    GOTO CheckGreenTime
    
UpdateLights:
    BTFSC intersection_state,0	    ; Check DIRECTION
    GOTO EWDirection

NSDirection:
    BTFSC intersection_state,3     ; Check TRANSITION
    GOTO NSYellow

NSGreen:
    MOVLW 0x0C	    ; 001100
    MOVWF PORTA
    RETURN

NSYellow:
    MOVLW 0x0A     ; 001010
    MOVWF PORTA
    RETURN

EWDirection:
    BTFSC intersection_state,3     ; Check TRANSITION
    GOTO EWYellow

EWGreen:
    MOVLW 0x21	   ; 100001
    MOVWF PORTA
    RETURN

EWYellow:
    MOVLW 0x11     ; 010001
    MOVWF PORTA
    RETURN
    
CheckGreenTime:
    MOVF count_temp,W
    XORLW 0x0A              ; STATE_COUNT = 10?
    BTFSC STATUS,2
    GOTO State4
    GOTO Main
    
State4:
    ; Protect packed state during update
    BCF INTCON,7    ; Temporarily disabling interrupts

    ; Recheck STATE_COUNT after interrupts are disabled
    SWAPF intersection_state,W
    ANDLW 0x0F
    XORLW 0x0A
    BTFSS STATUS,2  ; Still STATE_COUNT = 4?
    GOTO State4Done

    ; Transition should not already be active
    BTFSC intersection_state,3
    GOTO State4Done

    ; Check current direction
    BTFSC intersection_state,0
    GOTO CheckEWDirection
    GOTO CheckNSDirection
    
State4Done:
    BSF INTCON,7    ; Re-enable interrupts
    GOTO Main
    
CheckNSDirection:
    BTFSS intersection_state,1
    GOTO BeginTransition       ; No N/S car
    BTFSC intersection_state,2
    GOTO BeginTransition       ; E/W car also present
    GOTO SameDirection         ; N/S only

CheckEWDirection:
    BTFSC intersection_state,1
    GOTO BeginTransition       ; N/S car present
    BTFSS intersection_state,2
    GOTO BeginTransition       ; No E/W car
    GOTO SameDirection         ; E/W only
    
SameDirection:
    MOVLW 0x01
    ANDWF intersection_state,F
    GOTO State4Done

BeginTransition:
    ; Protect intersection_state while Main modifies it
    MOVF intersection_state,W
    BCF INTCON,7            ; Temporarily disabling interrupts
    ANDLW 0x0F              ; Preserve lower state flags
    IORLW 0x08              ; TRANSITION = 1
    MOVWF intersection_state ; STATE_COUNT becomes 0
    GOTO State4Done

CheckYellowTime:
    MOVF count_temp,W
    XORLW 0x02              ; Is STATE_COUNT = 2?
    BTFSC STATUS,2
    GOTO FinishTransition
    GOTO Main

FinishTransition:
    BCF INTCON,7            ; Protect intersection_state

    ; Make sure TRANSITION is still active
    BTFSS intersection_state,3
    GOTO FinishTransitionDone

    ; Recheck STATE_COUNT = 2
    SWAPF intersection_state,W
    ANDLW 0x0F
    XORLW 0x02
    BTFSS STATUS,2
    GOTO FinishTransitionDone

    ; Toggle DIRECTION and clear everything else
    MOVF intersection_state,W
    XORLW 0x01
    ANDLW 0x01
    MOVWF intersection_state

FinishTransitionDone:
    BSF INTCON,7
    GOTO Main
    
ISRHandler:
    MOVWF W_TEMP         ; Saving W register
    SWAPF STATUS,W       ; Moving STATUS into W
    CLRF STATUS		 ; Sets Bank 0
    MOVWF STATUS_TEMP    ; Saving STATUS register
    
    ; Check Timer1 Interrupt
    BTFSC PIR1,0         ; Is TMR1IF set?
    CALL Timer1ISR
    
    ; Check External INT Interrupt
    BTFSC INTCON,1
    CALL ExternalINTISR

    ; Check PORTB IOC Interrupt
    BTFSC INTCON,0
    CALL PORTBISR    
    GOTO LeaveISR
    
Timer1ISR:
    ; Reload Timer1 for another 500 ms
    MOVLW 0x0B
    MOVWF TMR1H
    MOVLW 0xDC
    MOVWF TMR1L
    BCF PIR1,0		  ; Clear Timer1 interrupt flag

    BTFSC PORTB,1	  ; RB1 = 1 means RUN
    CALL IncrementStateCount
    RETURN
    
ExternalINTISR:
    ; RB1 = 0 means DEBUG
    BTFSS PORTB,1
    CALL IncrementStateCount
    BCF INTCON,1        ; Always clear INTF
    RETURN
    
IncrementStateCount:
    ; Save lower four state flags
    MOVF intersection_state,W
    ANDLW 0x0F
    MOVWF flags_temp

    ; Extract STATE_COUNT
    SWAPF intersection_state,W
    ANDLW 0x0F
    MOVWF count_temp

    ; Increment STATE_COUNT
    INCF count_temp,F
    MOVLW 0x0F
    ANDWF count_temp,F

    ; Put STATE_COUNT back into bits 7:4
    SWAPF count_temp,W
    ANDLW 0xF0
    IORWF flags_temp,W
    MOVWF intersection_state
    RETURN
    
PORTBISR:
    MOVF PORTB,W
    ANDLW 0x30
    MOVWF portb_now
    BCF INTCON,0

    ; Check N/S car detection on RB4
    BTFSS portb_now,4
    GOTO CheckEWCar
    BTFSC portb_old,4
    GOTO CheckEWCar
    BSF intersection_state,1

CheckEWCar:
    ; Check E/W car detection on RB5
    BTFSS portb_now,5
    GOTO SavePORTB
    BTFSC portb_old,5
    GOTO SavePORTB
    BSF intersection_state,2

SavePORTB:
    MOVF portb_now,W
    MOVWF portb_old
    RETURN

LeaveISR:
    SWAPF STATUS_TEMP,W ; Restoring saved STATUS value
    MOVWF STATUS
    SWAPF W_TEMP,F	; Preparing saved W value
    SWAPF W_TEMP,W	; Restoring W register
    RETFIE		; Returning from interrupt

END
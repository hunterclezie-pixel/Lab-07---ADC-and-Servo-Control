// Hunter Clezie
// RCET3375
// Lab7ADCPt3
// https://github.com/hunterclezie-pixel/Lab-07---ADC-and-Servo-Control.git

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
    ccp_next_l EQU 0x23     ; Low byte of next CCP compare value
    ccp_next_h EQU 0x24     ; High byte of next CCP compare value
    ; Address 0x25 is used by the supplied lookup file
    ; Do not use 0x25 in this program
    
    adc_low EQU 0x70	    ; Stores lower 8 bits of ADC result
    adc_high EQU 0x71	    ; Stores upper 2 bits of ADC result
    map_temp EQU 0x72	    ; Temporary value used for ADC mapping
    servo_index EQU 0x73    ; Servo position from 0 through 20
    servo_count EQU 0x74    ; Counts additional 100 us delays
    delay_count EQU 0x75    ; Counter used inside delay loops
    W_TEMP EQU 0x76         ; Saves W during interrupt
    STATUS_TEMP EQU 0x77    ; Saves STATUS during interrupt
    PCLATH_TEMP EQU 0x78    ; Saves PCLATH during interrupt
 
    ; Lookup routine is located inside Lab07-Part3-Lookup.S
    GLOBAL ccp_next_l, ccp_next_h
    EXTRN LookupAdc6ToCcp
 
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    Goto ISRHandler

; Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2
 
Setup:
    BCF 0x03,6      ; Sets Bank 0
    BCF 0x03,5      ; Sets Bank 0
    CLRF 0x05	    ; Clearing PortA
    CLRF 0x06       ; Clearing PORTB
    CLRF 0x07       ; Clearing PORTC

    BCF 0x03,6      ; Sets Bank 1
    BSF 0x03,5      ; Sets Bank 1
    MOVLW 0x01
    MOVWF 0x85      ; TRISA: RA0 = input, RA1 = servo output
    CLRF 0x86       ; TRISB: PORTB outputs
    CLRF 0x87       ; TRISC: PORTC outputs
    CLRF ADCON1     ; Clear ADCON1
    BSF ADCON1,7    ; ADFM = 1, right justify result
    BCF ADCON1,5    ; VREF- = VSS
    BCF ADCON1,4    ; VREF+ = VDD

    BSF 0x03,6      ; Sets Bank 3
    BSF 0x03,5	    ; Sets Bank 3
    CLRF ANSEL      ; Clear analog selections
    CLRF ANSELH     ; Clear high analog selections
    BSF ANSEL,0     ; AN0 / RA0 = analog input
    
    ; ADC Setup
    BCF 0x03,6      ; Sets Bank 0
    BCF 0x03,5      ; Sets Bank 0
    CLRF ADCON0     ; Clear ADC settings
    BCF ADCON0,7    ; ADCS1 = 0
    BSF ADCON0,6    ; ADCS0 = 1                         
    ; Selects AN0 as ADC input
    BSF ADCON0,0    ; ADON = 1, turn ADC on
    
    ; Timer1 Setup
    CLRF T1CON      ; Timer1 off while configuring
    MOVLW 0xB1
    MOVWF TMR1H     ; Timer1 preload high byte
    MOVLW 0xE0
    MOVWF TMR1L     ; Timer1 preload low byte
    BCF PIR1,0      ; Clear Timer1 overflow flag
    BSF T1CON,0     ; Start Timer1

    ; CCP1 Setup
    BANKSEL CCP1CON
    MOVLW 0x0A
    MOVWF CCP1CON   ; CCP1 Compare mode, software interrupt on match

    ; Initial Servo Command
    BANKSEL ccp_next_l
    MOVLW 0xD4
    MOVWF ccp_next_l ; Low byte of 0xB3D4
    MOVLW 0xB3
    MOVWF ccp_next_h ; High byte of 0xB3D4

    ; Also load the first value into the actual CCP registers.
    BANKSEL CCPR1L
    MOVLW 0xD4
    MOVWF CCPR1L
    MOVLW 0xB3
    MOVWF CCPR1H

    ; Clear Program Flags
    BANKSEL pulse_busy
    CLRF pulse_busy ; Servo pulse is not active yet
    CLRF command_ready ; ADC command has not been calculated yet

    ; Clear Interrupt Flags
    BANKSEL PIR1
    BCF PIR1,0    ; Clear TMR1IF
    BCF PIR1,2    ; Clear CCP1IF

    ; Enable Timer1 and CCP1 Interrupts
    BANKSEL PIE1
    BSF PIE1,0    ; TMR1IE = 1, enable Timer1 interrupt
    BSF PIE1,2    ; CCP1IE = 1, enable CCP1 interrupt

    ; Start Timer1
    BANKSEL T1CON
    BSF T1CON,0   ; TMR1ON = 1

    ; Enable Peripheral and Global Interrupts
    BANKSEL INTCON
    BSF INTCON,6  ; PEIE = 1, enable peripheral interrupts
    BSF INTCON,7  ; GIE = 1, enable global interrupts

GOTO Main    

Main:
    CALL WaitFrame  ; Wait for Timer1 20 ms frame
    CALL ReadADC    ; Read potentiometer voltage
    CALL MapADC     ; Convert ADC into servo position
    CALL ServoPulse ; Generate servo HIGH pulse
    GOTO Main       ; Repeat continuously

WaitFrame:
    ; Wait for next 20 ms frame
    BTFSS PIR1,0    ; Has Timer1 overflowed?
    GOTO WaitFrame
    BCF PIR1,0      ; Clear Timer1 flag

    ; Reload Timer1 for another 20 ms
    MOVLW 0xB1
    MOVWF TMR1H
    MOVLW 0xE0
    MOVWF TMR1L
    RETURN
   
ReadADC:
    ; Acquisition Delay that allows sample/hold capacitor to charge
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    
    ; Start ADC Conversion
    BANKSEL ADCON0
    BSF ADCON0,1    ; GO/DONE = 1, start conversion
    
WaitADC:
    BTFSC ADCON0,1
    GOTO WaitADC

    ; Save upper 2 ADC bits
    BANKSEL ADRESH
    MOVF ADRESH,W
    BANKSEL adc_high
    MOVWF adc_high
    
    ; Save lower 8 ADC bits
    BANKSEL ADRESL
    MOVF ADRESL,W
    BANKSEL adc_low
    MOVWF adc_low
    
    ; Display ADC on LEDs
    MOVF adc_low,W
    BANKSEL PORTB
    MOVWF PORTB

    BANKSEL adc_high
    MOVF adc_high,W
    BANKSEL PORTC
    MOVWF PORTC

    RETURN
    
MapADC:
    ; Move ADC bits 9 and 8 into bits 5 and 4.
    BANKSEL adc_high
    MOVF adc_high,W
    MOVWF map_temp
    BCF STATUS,0           ; Clear Carry before shifting
    RLF map_temp,F
    BCF STATUS,0
    RLF map_temp,F
    BCF STATUS,0
    RLF map_temp,F
    BCF STATUS,0
    
    ; Move ADC bits 7 through 4 into bits 3 through 0.
    MOVF adc_low,W
    MOVWF adc_temp
    BCF STATUS,0            ; Clear Carry before shifting
    RRF adc_temp,F
    BCF STATUS,0
    RRF adc_temp,F
    BCF STATUS,0
    RRF adc_temp,F
    BCF STATUS,0
    RRF adc_temp,F
    
    ; Combine both sections to create a 6-bit value
    MOVF servo_index,W
    IORWF map_temp,F

    ; Send the 0-31 value to the lookup table
    ; Send 6-bit command from 0-63 to supplied lookup table.
    MOVF map_temp,W
    PAGESEL LookupAdc6ToCcp
    CALL LookupAdc6ToCcp
    PAGESEL $
    RETURN

ISRHandler:
    ; Save W and STATUS before changing anything in interrupt
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP

    ; Check Timer1 overflow interrupt first.
    BANKSEL PIR1
    BTFSC PIR1,0      ; Did Timer1 overflow?
    GOTO Timer1ISR

    ; Check CCP1 compare interrupt.
    BTFSC PIR1,2      ; Did Timer1 match CCPR1?
    GOTO CCP1ISR
    GOTO ISRDone

Timer1ISR:
    ; Timer1 overflow marks the beginning of a new 20 ms frame.
    BANKSEL PIR1
    BCF PIR1,0       ; Clear Timer1 interrupt flag

    ; Reload Timer1 with 0xB1E0 for another 20 ms frame.
    BANKSEL TMR1H
    MOVLW 0xB1
    MOVWF TMR1H
    MOVLW 0xE0
    MOVWF TMR1L

    ; Start servo pulse HIGH.
    BANKSEL PORTA
    BSF PORTA,1     ; Servo signal HIGH

    ; Load the saved CCP low byte.
    BANKSEL ccp_next_l
    MOVF ccp_next_l,W
    BANKSEL CCPR1L
    MOVWF CCPR1L

    ; Load the saved CCP high byte.
    BANKSEL ccp_next_h
    MOVF ccp_next_h,W
    BANKSEL CCPR1H
    MOVWF CCPR1H

    ; Clear any old CCP interrupt flag before enabling it.
    BANKSEL PIR1
    BCF PIR1,2     ; Clear CCP1IF

    ; Mark servo pulse as active.
    BANKSEL pulse_busy
    MOVLW 0x01
    MOVWF pulse_busy

    ; Enable CCP1 interrupt for this servo pulse.
    BANKSEL PIE1
    BSF PIE1,2     ; CCP1IE = 1
    GOTO ISRDone

CCP1ISR:
    ; Compare value from the supplied lookup table.
    BANKSEL PIR1
    BCF PIR1,2     ; Clear CCP1 interrupt flag

    ; End the servo pulse.
    BANKSEL PORTA
    BCF PORTA,1    ; Servo signal LOW

    ; Disable CCP interrupt until the next servo pulse.
    BANKSEL PIE1
    BCF PIE1,2     ; CCP1IE = 0

    ; Mark servo pulse as finished.
    BANKSEL pulse_busy
    CLRF pulse_busy
    GOTO ISRDone

ISRDone:
    ; Restore STATUS register.
    SWAPF STATUS_TEMP,W
    MOVWF STATUS

    ; Restore W register.
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    RETFIE

END
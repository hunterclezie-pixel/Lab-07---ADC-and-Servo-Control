// Hunter Clezie
// RCET3375
// Lab7ADCPt2
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
    adc_low EQU 0x70	    ; Stores lower 8 bits of ADC result
    adc_high EQU 0x71	    ; Stores upper 2 bits of ADC result
    map_temp EQU 0x72	    ; Temporary value used for ADC mapping
    servo_index EQU 0x73    ; Servo position from 0 through 20
    servo_count EQU 0x74    ; Counts additional 100 us delays
    delay_count EQU 0x75    ; Counter used inside delay loops
    adc_temp EQU 0x76
 
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2
InterruptVector:

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
    CLRF servo_index
    CLRF servo_count
    CLRF delay_count

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
    BANKSEL adc_high
    MOVF adc_high,W
    MOVWF map_temp
    BCF STATUS,0           ; Clear Carry before shifting
    RLF map_temp,F
    BCF STATUS,0
    RLF map_temp,F
    BCF STATUS,0
    RLF map_temp,F
    MOVF adc_low,W
    MOVWF servo_index      ; Temporary storage
    BCF STATUS,0
    RRF servo_index,F
    BCF STATUS,0
    RRF servo_index,F
    BCF STATUS,0
    RRF servo_index,F
    BCF STATUS,0
    RRF servo_index,F
    BCF STATUS,0
    RRF servo_index,F

    ; Combine the upper 2 bits and lower 3 bits
    MOVF servo_index,W
    IORWF map_temp,F

    ; Send the 0-31 value to the lookup table
    MOVF map_temp,W
    CALL ServoLookup
    MOVWF servo_index	; Save returned servo position
    RETURN

ServoLookup:
    ADDWF PCL,F	    ; Jump forward in table using W
    RETLW 0	    ; ADC group 0 - Min
    RETLW 0	    ; ADC group 1
    RETLW 1	    ; ADC group 2
    RETLW 1	    ; ADC group 3
    RETLW 2	    ; ADC group 4
    RETLW 3	    ; ADC group 5
    RETLW 3	    ; ADC group 6
    RETLW 4	    ; ADC group 7
    RETLW 5	    ; ADC group 8
    RETLW 5	    ; ADC group 9
    RETLW 6	    ; ADC group 10
    RETLW 7	    ; ADC group 11
    RETLW 7	    ; ADC group 12
    RETLW 8	    ; ADC group 13
    RETLW 9	    ; ADC group 14
    RETLW 9	    ; ADC group 15
    RETLW 10	    ; ADC group 16 - Center
    RETLW 11	    ; ADC group 17
    RETLW 11	    ; ADC group 18
    RETLW 12	    ; ADC group 19
    RETLW 13	    ; ADC group 20
    RETLW 13	    ; ADC group 21
    RETLW 14	    ; ADC group 22
    RETLW 15	    ; ADC group 23
    RETLW 15	    ; ADC group 24
    RETLW 16	    ; ADC group 25
    RETLW 17	    ; ADC group 26
    RETLW 17	    ; ADC group 27
    RETLW 18	    ; ADC group 28
    RETLW 19	    ; ADC group 29
    RETLW 19	    ; ADC group 30
    RETLW 20	    ; ADC group 31 - Maximum

ServoPulse:
    BANKSEL PORTA
    BSF PORTA,1      ; Start servo pulse HIGH
    CALL Delay500us  ; Every servo position gets at least 500 us HIGH

    ; Copy servo index into a counter.
    BANKSEL servo_index
    MOVF servo_index,W
    MOVWF servo_count

    ; Check for position 0
    MOVF servo_count,F
    BTFSC STATUS,2         ; Is servo_count zero?
    GOTO ServoDone         ; Yes -> pulse is only 500 us

Extra100us:
    CALL Delay100us        ; Add approximately 100 us
    DECFSZ servo_count,F   ; Decrease count by one
    GOTO Extra100us        ; More delays needed? No -> pulse is finished
			   
ServoDone:
    BANKSEL PORTA
    BCF PORTA,1            ; End servo pulse, output LOW
    RETURN

Delay100us:
    MOVLW 0x17
    MOVWF delay_count

Delay100Loop:
    NOP                    ; Small timing delay
    DECFSZ delay_count,F   ; Count down toward zero
    GOTO Delay100Loop
    RETURN

Delay500us:
    MOVLW 0xA5
    MOVWF delay_count

Delay500Loop:
    DECFSZ delay_count,F   ; Count down toward zero
    GOTO Delay500Loop
    RETURN

END
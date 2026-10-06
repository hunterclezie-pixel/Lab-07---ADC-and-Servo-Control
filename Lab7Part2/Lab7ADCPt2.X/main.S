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
    adc_low     EQU 0x70     ; Lower 8 bits of ADC result
    adc_high    EQU 0x71     ; Upper 2 bits of ADC result
    servo_index EQU 0x72     ; Servo position from 0-20
    delay_temp  EQU 0x73     ; Used for software delays
    pulse_count EQU 0x74     ; Number of additional 100 us delays
 
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
    MOVWF 0x85      ; TRISA: RA0 input, other PORTA pins outputs
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
    
    

    GOTO Main    

Main:
    ; Acquisition Delay that allows sample/hold capacitor to charge
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    
    ; Start ADC Conversion
    BANKSEL PORTA
    BSF PORTA,1     ; Diagnostic HIGH
    BANKSEL ADCON0
    BSF ADCON0,1    ; GO/DONE = 1, start conversion
    
WaitADC:
    BTFSC ADCON0,1  ; Is GO/DONE still 1?
    GOTO WaitADC    ; Yes -> conversion still running

    ; Conversion Complete
    BANKSEL PORTA
    BCF PORTA,1     ; Diagnostic LOW

    ; Display ADRESH on PORTC
    BANKSEL ADRESH
    MOVF ADRESH,W
    BANKSEL PORTC
    MOVWF PORTC

    ; Display ADRESL on PORTB
    BANKSEL ADRESL
    MOVF ADRESL,W
    BANKSEL PORTB
    MOVWF PORTB
    GOTO Main
    
END
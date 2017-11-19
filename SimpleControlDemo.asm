; This program includes a basic movement API that allows the
; user to specify a desired heading and speed, and the API will
; attempt to control the robot in an appropriate way.
; Also includes several math subroutines.

ORG 0                  ; Jump table is located in mem 0-4
; This code uses the timer interrupt for the control code.
	JUMP   Init        ; Reset vector
;I'm enabling sonar interrupts in order to stop the robot when something is in fron of us
	JUMP   SIR         ; Sonar interrupt (unused)
	JUMP   CTimer_ISR  ; Timer interrupt
	RETI               ; UART interrupt (unused)
	RETI               ; Motor stall interrupt (unused)

;***************************************************************
;* Initialization
;***************************************************************
Init:
	; Always a good idea to make sure the robot
	; stops in the event of a reset.
	LOAD   Zero
	OUT    LVELCMD     ; Stop motors
	OUT    RVELCMD
	STORE  DVel        ; Reset movement API variables
	STORE  DTheta
	OUT    SONAREN     ; Disable sonar (optional)
	OUT    BEEP        ; Stop any beeping (optional)
	
	CALL   SetupI2C    ; Configure the I2C to read the battery voltage
	CALL   BattCheck   ; Get battery voltage (and end if too low).
	OUT    LCD         ; Display battery voltage (hex, tenths of volts)

	LOADI  &H130
	OUT    BEEP        ; Short hello beep
	
WaitForSafety:
	; This loop will wait for the user to toggle SW17.  Note that
	; SCOMP does not have direct access to SW17; it only has access
	; to the SAFETY signal contained in XIO.
	IN     XIO         ; XIO contains SAFETY signal
	AND    Mask4       ; SAFETY signal is bit 4
	JPOS   WaitForUser ; If ready, jump to wait for PB3
	IN     TIMER       ; Use the timer value to
	AND    Mask1       ; blink LED17 as a reminder to toggle SW17
	SHIFT  8           ; Shift over to LED17
	OUT    XLEDS       ; LED17 blinks at 2.5Hz (10Hz/4)
	JUMP   WaitForSafety
	
WaitForUser:
	; This loop will wait for the user to press PB3, to ensure that
	; they have a chance to prepare for any movement in the main code.
	IN     TIMER       ; Used to blink the LEDs above PB3
	AND    Mask1
	SHIFT  5           ; Both LEDG6 and LEDG7
	STORE  Temp        ; (overkill, but looks nice)
	SHIFT  1
	OR     Temp
	OUT    XLEDS
	IN     XIO         ; XIO contains KEYs
	AND    Mask2       ; KEY3 mask (KEY0 is reset and can't be read)
	JPOS   WaitForUser ; not ready (KEYs are active-low, hence JPOS)
	LOAD   Zero
	OUT    XLEDS       ; clear LEDs once ready to continue

;***************************************************************
;* Main code
;***************************************************************
Main:
	OUT    RESETPOS    ; reset odometer in case wheels moved after programming
	
	; configure timer interrupts to enable the movement control code
	LOADI  10          ; fire at 10 Hz (10 ms * 10).
	OUT    CTIMER      ; turn on timer peripheral
	SEI    &B0010      ; enable interrupts from source 2 (timer)
	SEI    &B0001
	; at this point, timer interrupts will be firing at 10Hz, and
	; code in that ISR will attempt to control the robot.
	; If you want to take manual control of the robot,
	; execute CLI &B0010 to disable the timer interrupt.
	

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;CODE ADDED BY TEAM BAFFLED TO IMPLEMENT THE WATCHDOG PROJECT ALGORITHM BELOW;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;DO NOT CHANGE, USED FOR SONAR INTERUPTS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LOAD  mask2         ;load in mask to enable the sonar sensor 2                       ;;
OR    mask3         ;or the two masks so that I can enable both sensors              ;;
OUT   SONAREN       ;enable the two sensors for use in software interrupts for sonar ;;
OUT   SONARINT      ;only allow these sonar sensors to cause an interrupt			 ;;
LOADI 304           ;load 1 foot in the AC										 ;;
OUT   SONALARM      ;set this as the distance that causes interrupt from the sensors ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Code which instructs the robot to move from a designated starting position

;To a known point on a five point patrol path

InitialPatrol:

	LOAD   FMid        ; Defined below as 350.
	STORE  DVel        ; Desired forward velocity
	IN     XPOS        ; X position from odometry
	OUT    LCD         ; Display X position for debugging
	;Subtracts one meter so the value in the accumulator is a negative value
	;until the robot has moved one meter
	SUB    OneMeter    ; Defined below as the robot units for 1 m
	;junps to the begining of this loop so that the robot will continue to move forward
	;until it has moved aproximatly one meter
	JNEG   InitialPatrol   ; Not there yet, keep checking
	LOADI  0		   ; Loads 0
	STORE  DVel        ; Stops the robot from moving forward
	OUT    LVELCMD	   ; extra stop comands to ensure the robot is stationary
	OUT	   RVELCMD     ; extra stop comands to ensure the robot is stationary
	;CALL   Wait1 	   ; the robot waits one second so any function calls can be completed
	
	;area where function calls can be made so the robot does something specific
	;
	;area where function calls can be made so the robot does something specific
	
;Code which instructs the robot to move from 'Point A' on the patrol path to 'Point B'
PointA:
	LOAD   FMid        ; Defined below as 350.
	STORE  DVel        ; Desired forward velocity
	IN     XPOS        ; X position from odometry
	OUT    LCD         ; Display X position for debugging
	;Subtracts 'distanceA' so the value in the accumulator is a negative value
	;until the robot has moved 'distanceA'
	SUB    DistanceA   ; Defined below as the robot units for aproximatly 2.5 m
	;junps to the begining of this loop so that the robot will continue to move forward
	;until it has moved aproximatly one meter
	JNEG   PointA      ; Not there yet, keep checking
	;LOADI  0		   ; Loads 0
	;STORE  DVel        ; Stops the robot from moving forward
	;OUT    LVELCMD     ; extra stop comands to ensure the robot is stationary
	;OUT	   RVELCMD     ; extra stop comands to ensure the robot is stationary
	;LOADI  270         ; Loads 270, the angled needed to turn right
	;STORE  DManTheta   ; Makes the robot turn the angle specified
	;LOAD   FSlow 	   ; Specifies a slow trun speed
	;STORE  DManTurnVel ; stores the turn speed
	;CALL   TurnVariableSpeed ; Calls the turn API constructed for variable speed turns
	;CALL   Wait1      ; Calls Wait1 to wait 1 second to let the robot turn
;Code which instructs the robot to move from 'Point B' on the patrol path to 'Point C'

	Load	Zero
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	STORE   DVel        ; Reset movement API variables
	; Move forward at angle 0 and velocity 350
	;STORE   DTheta	    ; Desired angle 0	
	
	LOADI   135		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadStoreValsA45
	
	LOADI   180		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadStoreValsA90
	
	LOADI   225		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadStoreValsA135
	
	LOADI   -90		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	
	OUT		RESETPOS
	
	LOAD	FMid		; Defined below as 350
	STORE	DVel		; Desired forward velocity
TestOdForward1init:
	IN      XPOS        ; X position from odometry
	OUT     LCD         ; Display X position for debugging
	SUB     TwoMeters    ; Defined below as the robot units for 1 m
	JNEG    TestOdForward1init       ; Not there yet, keep checking
	; once you get here, you've travelewd 2m straught forward,
	; so stop and turn left 180 degrees
	LOADI   0
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	STORE   DVel
	
	LOADI   -45		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadStoreValsB135
	
	LOADI   -90		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadStoreValsB90
	
	LOADI   -135		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadStoreValsB45
	
	LOADI   180
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL	TurnVariableSpeed

TestOdometryError:
	Load	Zero
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	STORE   DVel        ; Reset movement API variables
	; Move forward at angle 0 and velocity 350
	;STORE   DTheta	    ; Desired angle 0
	LOAD	FMid		; Defined below as 350
	STORE	DVel		; Desired forward velocity
	JUMP	TestOdForward1
	
TestOdForward1:
	IN		XPOS
	OUT		LCD
	JPOS	TestOdForward1
	
	; once you get here, you've travelewd 2m straught forward,
	; so stop and turn left 180 degrees
	LOADI   0
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	STORE   DVel
	
	LOADI   -135		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadCompareValsA45
	
	LOADI   -90		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadCompareValsA90
	
	LOADI   -45		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadCompareValsA135
	
	LOADI   0		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed

	LOAD	FMid		; Defined below as 350
	STORE	DVel		; Desired forward velocity

TestOdForward2:	
	IN      XPOS        ; X position from odometry
	OUT     LCD         ; Display X position for debugging
	SUB     TwoMeters    ; Defined below as the robot units for 1 m
	JNEG    TestOdForward2       ; Not there yet, keep checking
	
	; stop and turn right 180 degrees
	LOADI   0
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	STORE   DVel
	
	LOADI   -45		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadCompareValsB135
	
	LOADI   -90		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadCompareValsB90
	
	LOADI   -135		; this is the desired turn amount
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL    TurnVariableSpeed
	CALL    ReadCompareValsB45
	
	LOADI   180
	STORE   DManTheta
	LOAD    FSlow	; this is the desired turn speed
	STORE   DManTurnVel
	CALL	TurnVariableSpeed
	LOAD	FMid		; Defined below as 350
	STORE	DVel		; Desired forward velocity
	JUMP	TestOdometryError

;function to perform sonar reading using front four sensors
;assumes that the robot is facing the correct direction
;it will store the value in an array 
ReadStoreValsA45:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half
	
	IN    Dist1        ;get the reading from sonar 1
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore0       ;store the first sensor reading in AStore0
	
	IN    Dist2        ;get the reading from sonar 2
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore1     ;store the first sensor reading in AStore1
	
	IN    Dist3        ;get the reading from sonar 3
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore2       ;store the first sensor reading in Astore2
	
	IN    Dist4        ;get the reading from sonar 4
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore3       ;store the first sensor reading in AStore3
	
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	
	RETURN            ;return to caller
	
	
;function to perform sonar reading using front four sensors
;assumes that the robot is facing the correct direction
;it will store the value in an array 
ReadStoreValsA90:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half

	IN    Dist1        ;get the reading from sonar 1
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore4       ;store the first sensor reading in AStore0
	
	IN    Dist2        ;get the reading from sonar 2
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore5     ;store the first sensor reading in AStore1
	
	IN    Dist3        ;get the reading from sonar 3
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore6       ;store the first sensor reading in Astore2
	
	IN    Dist4        ;get the reading from sonar 4
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore7       ;store the first sensor reading in AStore3
	
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	
	RETURN            ;return to caller 
	
	
;function to perform sonar reading using front four sensors
;assumes that the robot is facing the correct direction
;it will store the value in an array 
ReadStoreValsA135:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half

	
	IN    Dist1        ;get the reading from sonar 1
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore8       ;store the first sensor reading in AStore0
	
	IN    Dist2        ;get the reading from sonar 2
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore9     ;store the first sensor reading in AStore1
	
	IN    Dist3        ;get the reading from sonar 3
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore10       ;store the first sensor reading in Astore2
	
	IN    Dist4        ;get the reading from sonar 4
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later 
	STORE AStore11      ;store the first sensor reading in AStore3
	
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	
	RETURN            ;return to caller
	

	
		
	
;function to perform sonar reading using front four sensors
;assumes that the robot is facing the correct direction
;it will store the value in an array 
ReadStoreValsB45:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half
	
	IN    Dist1        ;get the reading from sonar 1
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later   
	STORE BStore0       ;store the first sensor reading in AStore0
	
	IN    Dist2        ;get the reading from sonar 2
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore1     ;store the first sensor reading in BStore1
	
	IN    Dist3        ;get the reading from sonar 3
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore2       ;store the first sensor reading in BStore2
	
	IN    Dist4        ;get the reading from sonar 4
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore3       ;store the first sensor reading in BStore3
	
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	
	RETURN            ;return to caller  
	
	
	 
	
	
;function to perform sonar reading using front four sensors
;assumes that the robot is facing the correct direction
;it will store the value in an array 
ReadStoreValsB90:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half
	
	IN    Dist1        ;get the reading from sonar 1
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later   
	STORE BStore4       ;store the first sensor reading in AStore0
	
	IN    Dist2        ;get the reading from sonar 2
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore5     ;store the first sensor reading in BStore1
	
	IN    Dist3        ;get the reading from sonar 3
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore6       ;store the first sensor reading in BStore2
	
	IN    Dist4        ;get the reading from sonar 4
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore7       ;store the first sensor reading in BStore3
	
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	
	RETURN            ;return to caller  
	
	
	
	
;function to perform sonar reading using front four sensors
;assumes that the robot is facing the correct direction
;it will store the value in an array 
ReadStoreValsB135:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half
	
	IN    Dist1        ;get the reading from sonar 1
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later   
	STORE BStore8       ;store the first sensor reading in AStore0
	
	IN    Dist2        ;get the reading from sonar 2
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore9     ;store the first sensor reading in BStore1
	
	IN    Dist3        ;get the reading from sonar 3
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore10       ;store the first sensor reading in BStore2
	
	IN    Dist4        ;get the reading from sonar 4
	ADDI  -304			;subtract one foot from this measurement to use in checking for object later
	STORE BStore11      ;store the first sensor reading in BStore3
	
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	
	RETURN            ;return to caller  
	

;function to fire the front four sonars and detect if something has changed
;assumes the robot is facing the correct direction
;it will beep if something is detected whithin a threshold of 1 foot
ReadCompareValsA45:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half   ;tell robot to wait in order to give sonar time to setup
	
	LOADI 1
	OUT   LCD
	IN    Dist1       ;get the value from sonar sensor 1
	SUB   AStore0     ;subtract the previous value from new value 
	JNEG  FOUNDA1       ;if the distance is too close the intruder is there
	
	LOADI 2
	OUT   LCD
	IN    Dist2       ;get the value from sonar sensor 2
	SUB   AStore1     ;subtract the previous value from new value 
	JNEG  FOUNDA1       ;if the distance is too close the intruder is there
	
	LOADI 3
	OUT   LCD
	IN    Dist3       ;get the value from sonar sensor 3
	SUB   AStore0     ;subtract the previous value from new value 
	JNEG  FOUNDA1       ;if the distance is too close the intruder is there
	
	LOADI 4
	OUT   LCD
	IN    Dist4       ;get the value from sonar sensor 4
	SUB   AStore0     ;subtract the previous value from new value 
	JNEG  FOUNDA1       ;if the distance is too close the intruder is there
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	RETURN            ;if not found return to caller
	
FOUNDA1:
    CALL  FoundIntruder ;if there is something there then beep!
    LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
    RETURN             ;return to caller
    
    
;function to fire the front four sonars and detect if something has changed
;assumes the robot is facing the correct direction
;it will beep if something is detected whithin a threshold of 1 foot
ReadCompareValsA90:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half   ;tell robot to wait in order to give sonar time to setup
	
	LOADI 1
	OUT   LCD
	IN    Dist1       ;get the value from sonar sensor 1
	SUB   AStore4     ;subtract the previous value from new value 
	JNEG  FOUNDA2       ;if the distance is too close the intruder is there
	
	LOADI 2
	OUT   LCD
	IN    Dist2       ;get the value from sonar sensor 2
	SUB   AStore5     ;subtract the previous value from new value 
	JNEG  FOUNDA2       ;if the distance is too close the intruder is there
	
	LOADI 3
	OUT   LCD
	IN    Dist3       ;get the value from sonar sensor 3
	SUB   AStore6     ;subtract the previous value from new value 
	JNEG  FOUNDA2       ;if the distance is too close the intruder is there
	
	LOADI 4
	OUT   LCD
	IN    Dist4       ;get the value from sonar sensor 4
	SUB   AStore7     ;subtract the previous value from new value 
	JNEG  FOUNDA2       ;if the distance is too close the intruder is there
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	RETURN            ;if not found return to caller
	
FOUNDA2:
    CALL  FoundIntruder ;if there is something there then beep!
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
    RETURN             ;return to caller
    

    
    
    
    
;function to fire the front four sonars and detect if something has changed
;assumes the robot is facing the correct direction
;it will beep if something is detected whithin a threshold of 1 foot
ReadCompareValsA135:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half   ;tell robot to wait in order to give sonar time to setup
	
	LOADI 1
	OUT   LCD
	IN    Dist1       ;get the value from sonar sensor 1
	SUB   AStore8     ;subtract the previous value from new value 
	JNEG  FOUNDA3       ;if the distance is too close the intruder is there
	
	LOADI 2
	OUT   LCD
	IN    Dist2       ;get the value from sonar sensor 2
	SUB   AStore9     ;subtract the previous value from new value 
	JNEG  FOUNDA3       ;if the distance is too close the intruder is there
	
	LOADI 3
	OUT   LCD
	IN    Dist3       ;get the value from sonar sensor 3
	SUB   AStore10     ;subtract the previous value from new value 
	JNEG  FOUNDA3       ;if the distance is too close the intruder is there
	
	LOADI 4
	OUT   LCD
	IN    Dist4       ;get the value from sonar sensor 4
	SUB   AStore11    ;subtract the previous value from new value 
	JNEG  FOUNDA3     ;if the distance is too close the intruder is there
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	RETURN            ;if not found return to caller
	
FOUNDA3:
    CALL  FoundIntruder ;if there is something there then beep!
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
    RETURN             ;return to caller
    
    
    
    
;function to fire the front four sonars and detect if something has changed
;assumes the robot is facing the correct direction
;it will beep if something is detected whithin a threshold of 1 foot
ReadCompareValsB45:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half   ;tell robot to wait in order to give sonar time to setup
	
	IN    Dist1       ;get the value from sonar sensor 1
	SUB   BStore0     ;subtract the previous value from new value 
	JNEG  FOUNDB1       ;if the distance is too close the intruder is there
	
	IN    Dist2       ;get the value from sonar sensor 2
	SUB   BStore1     ;subtract the previous value from new value 
	JNEG  FOUNDB1       ;if the distance is too close the intruder is there
	
	IN    Dist3       ;get the value from sonar sensor 3
	SUB   BStore0     ;subtract the previous value from new value 
	JNEG  FOUNDB1      ;if the distance is too close the intruder is there
	
	IN    Dist4       ;get the value from sonar sensor 4
	SUB   BStore0     ;subtract the previous value from new value 
	JNEG  FOUNDB1      ;if the distance is too close the intruder is there
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	RETURN            ;if not found return to caller
	
	
FOUNDB1:
    CALL  FoundIntruder ;if there is something there then beep!
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
    RETURN             ;return to caller
    
    
    
;function to fire the front four sonars and detect if something has changed
;assumes the robot is facing the correct direction
;it will beep if something is detected whithin a threshold of 1 foot
ReadCompareValsB90:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half   ;tell robot to wait in order to give sonar time to setup
	
	IN    Dist1       ;get the value from sonar sensor 1
	SUB   BStore4     ;subtract the previous value from new value 
	JNEG  FOUNDB2       ;if the distance is too close the intruder is there
	
	IN    Dist2       ;get the value from sonar sensor 2
	SUB   BStore5     ;subtract the previous value from new value 
	JNEG  FOUNDB2       ;if the distance is too close the intruder is there
	
	IN    Dist3       ;get the value from sonar sensor 3
	SUB   BStore6     ;subtract the previous value from new value 
	JNEG  FOUNDB2      ;if the distance is too close the intruder is there
	
	IN    Dist4       ;get the value from sonar sensor 4
	SUB   BStore7     ;subtract the previous value from new value 
	JNEG  FOUNDB2      ;if the distance is too close the intruder is there
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	RETURN            ;if not found return to caller
	
	
FOUNDB2:
    CALL  FoundIntruder ;if there is something there then beep!
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
    RETURN             ;return to caller

    

    
;function to fire the front four sonars and detect if something has changed
;assumes the robot is facing the correct direction
;it will beep if something is detected whithin a threshold of 1 foot
ReadCompareValsB135:
	LOAD  mask1        ;load the mask for sensor 1
	OR    mask2		  ;or the masks tgether to enable multiple sonars
	OR 	  mask3		  ;or the masks tgether to enable multiple sonars
	OR    mask4	 	  ;or the masks tgether to enable multiple sonars
	OUT   SONAREN 	  ;enable the sonar sensors
	
	CALL  Wait1Half   ;tell robot to wait in order to give sonar time to setup
	
	IN    Dist1       ;get the value from sonar sensor 1
	SUB   BStore8     ;subtract the previous value from new value 
	JNEG  FOUNDB3       ;if the distance is too close the intruder is there
	
	IN    Dist2       ;get the value from sonar sensor 2
	SUB   BStore9     ;subtract the previous value from new value 
	JNEG  FOUNDB3       ;if the distance is too close the intruder is there
	
	IN    Dist3       ;get the value from sonar sensor 3
	SUB   BStore10     ;subtract the previous value from new value 
	JNEG  FOUNDB3      ;if the distance is too close the intruder is there
	
	IN    Dist4       ;get the value from sonar sensor 4
	SUB   BStore11     ;subtract the previous value from new value 
	JNEG  FOUNDB3     ;if the distance is too close the intruder is there
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
	RETURN            ;if not found return to caller
	
	
FOUNDB3:
    CALL  FoundIntruder ;if there is something there then beep!
	LOAD  mask2       ;load mask2 into the AC
	OR    mask3       ;or it with mask3 to enable only front two sensors
	OUT   SONAREN     ;turn off sonar
    RETURN             ;return to caller
	
	
;function to sound a beep when an intruder is located in the area
FoundIntruder:
	LOADI &H40        ;load in the frequency to make it beep
	OUT   BEEP 		  ;tell the robot to beep
	CALL  Wait1       ;tell robot to wait one second in order to let it beep
	LOADI &H00	      ;Load in new value to make beep stop
	OUT   BEEP        ;tell beep to stop 
	RETURN            ;return to caller
	
	
;Sonar Interrupt Routine to monitor for objects in front of the robot
;it will stop the robot, beep, then check if the obstacle is still there, 
;if it is, then it will wait, otherwise, it will return to the main code
;with the same value for velocity it had before 


SIR:
   CLI   &B0001       ;temporarily turn off interrupts
   LOAD  DVel         ;load the current velocity of the robot
   STORE SonarVel     ;store the old velocity to restore later
   LOAD  Zero         ;load zero in the AC
   STORE DVel         ;stop the robot
   CALL  FoundIntruder ;beep because there must be an intruder here
IntruderDist:
   IN    Dist2        ;grab the distance from sensor 2
   ADDI  -304         ;subtract 6 inches from the distance
   JNEG  IntruderDist ;if intruder still within 6 inches then keep waiting
   JZERO IntruderDist ;do the same thing if exactly 6 inches away
   IN    Dist3        ;grab the distance from sensor 3
   ADDI  -304         ;subtract 6 inches from the distance
   JNEG  IntruderDist ;if intruder still within 6 inches then keep waiting
   JZERO IntruderDist ;if the intruder still present then keep waiting 
   
   LOAD  SonarVel     ;load the original velocity
   STORE DVel         ;tell the robot to go that speed
   SEI   &B0001       ;restart interrupts
   
   RETI			      ;return to where interrupted
	

;*************************************************************************************
; Allows the robot to turn in place at a given speed.
; Turning at a slow speed results in less slippage and odometry error.
; 
; To use, store values for these before calling:
; 	DManTheta - the desired theta value to be facing when the call is returned
; 	DManTurnVal - the velocity to turn at; recommend 100 (ie FSlow)
;*************************************************************************************
TurnVariableSpeed:
	LOADI	1			; enable manual turning and disable movement API
	STORE	ManTurnEn
	CALL    Wait1Fifth  ; wait and let robot stabilize
	
	CALL	DetermineTurnDir  ; if this sets IsTurnLeft = 1, turn left; else turn right
	LOAD	IsTurnLeft
	JZERO	TurnRightVarSpeedHelper
	; otherwise, turn left
	LOAD	DManTurnVel	; set the velocity for the turn speed
	OUT		RVELCMD		; just turn right motor forward
	CALL	Neg			; make left wheel turn opposite velocity
	OUT		LVELCMD
LoopTurnLeftVariableSpeed:
	LOAD	DManTurnVel	; set the velocity for the turn speed
	OUT		RVELCMD		; just turn right motor forward
	CALL	Neg			; make left wheel turn opposite velocity
	OUT		LVELCMD
	CALL	GetManThetaErr	; get the heading error
	CALL	Abs
	OUT		LCD
	ADDI	-2			; this is desired accuracy
	JPOS	LoopTurnLeftVariableSpeed ; keep turning until error is <= 2 degrees
	JUMP	DoneTurnVariableSpeed
TurnRightVarSpeedHelper:
	LOAD	DManTurnVel	; set the velocity for the turn speed
	OUT		LVELCMD		; just turn left motor forward
	CALL	Neg			; make right wheel turn opposite velocity
	OUT		RVELCMD
LoopTurnRightVariableSpeed:
	LOAD	DManTurnVel	; set the velocity for the turn speed
	OUT		LVELCMD		; just turn left motor
	CALL	Neg			; make right wheel turn opposite velocity
	OUT		RVELCMD
	CALL	GetManThetaErr	; get the heading error
	CALL	Abs
	OUT		LCD
	ADDI	-2			; this is desired accuracy
	JPOS	LoopTurnRightVariableSpeed ; keep turning until error is <= 2 degrees
DoneTurnVariableSpeed:
	IN		THETA
	STORE	DTheta	; want the movement API not to try and turn it once control resumes
	LOADI	0		; after the turn, stop the motors
	OUT		LVELCMD
	OUT		RVELCMD
	LOADI	0		; disable manual turning and re-enable movement API
	STORE	ManTurnEn
	CALL	Wait1Fifth
	RETURN
DManTheta:	 DW	0		; desired theta; the robot will be facing here +-2 degrees when finished
DManTurnVel: DW 0		; desired turn speed; 100 is slowest, 500 is fastest; faster speed = more slipping
ManTurnEn:	 DW &H0000	; set to 1 to enable manual turning and disable movement API

;***************************************************************
; Determines the direction for the manual turn.
; If abs(THETA - DManTheta)>=180, then turn right,
; else turn left.
;
; This function doesn't actually turn; it sets an indicator bit
; IsTurnLeft = 1 means left turn; = 0 means right turn
;***************************************************************
DetermineTurnDir:
	IN		THETA
	SUB		DManTheta
	CALL	Abs
	SUB		Pos180
	JNEG	SetTurnLeft		; if abs(THETA - DManTheta) >= 180, turn right
	LOADI	0
	STORE	IsTurnLeft
	JUMP	DoneDetermineTurnDir
SetTurnLeft:
	LOADI	1
	STORE	IsTurnLeft
DoneDetermineTurnDir:	
	RETURN
IsTurnLeft:	DW	0
Pos180:		DW 180


; Returns the current angular error wrapped to +/-180,
; when using manual control (not using movement API)
GetManThetaErr:
	; convenient way to get angle error in +/-180 range is
	; ((error + 180) % 360 ) - 180
	IN     THETA
	SUB    DManTheta    ; actual - desired angle
	CALL   Neg         ; desired - actual angle
	ADDI   180
	CALL   Mod360
	ADDI   -180
	RETURN
	
	
	
	
	; Subroutine to wait (block) for 1/5 second
Wait1Fifth:
	OUT    TIMER
WFifthLoop:
	IN     TIMER
	OUT    XLEDS       ; User-feedback that a pause is occurring.
	ADDI   -2          ; 0.2 second at 10Hz.
	JNEG   WHalfLoop
	RETURN
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;CODE ADDED BY TEAM BAFFLED TO IMPLEMENT THE WATCHDOG PROJECT ALGORITHM ABOVE;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	

; Function to turn on the right sonar
OnSonar:
	LOADI  &B00100000  ; Loading the bit for the right sonar
	OUT  SONAREN	   ; Turning on that sonar

; This function detects when the right sonar measures a distance
; less than two feet
Detect: 
	LOADI  0
	STORE  DTheta      ; Desired angle 0
	LOAD   FMid        ; Defined below as 350.
	STORE  DVel        ; Desired forward velocity
	IN     DIST5	   ; Reads in the sonar value
	OUT    LCD         ; Outsputs the value to lcd to read
	SUB    TwoFeet     ; Subtracts 2 feet to make desired value 0
	JPOS   Detect      ; If value is positive, go back to detect.

; Function to turn right, beep and die
StopSequence:
	LOADI   0		   ; Loads 0
	STORE   DVel       ; Stops the robot from moving forward
	LOADI   -90        ; Loads -90, the angled needed to turn right
	STORE   DTheta     ; Makes the robot turn the angle specified
	LOADI   &H40       ; Loads the frequency wanted for the beep
	OUT 	BEEP       ; Makes the robot beep at that frequency
	CALL	Wait1      ; Calls Wait1 to wait 1 second to let the robot beep
	LOADI   &H0        ; Loads 0
	OUT	    BEEP       ; Outputs 0 to beep to turn it off
	JUMP    DIE        ; Jumps to die to turn off the robot

	
	
Test1:  ; P.S. "Test1" is a terrible, non-descriptive label
	IN     XPOS        ; X position from odometry
	OUT    LCD         ; Display X position for debugging
	SUB    OneMeter    ; Defined below as the robot units for 1 m
	JNEG   Test1       ; Not there yet, keep checking

	; turn left 90 degrees
	LOADI  0
	STORE  DVel
	LOADI  90
	STORE  DTheta
	; Note that we waited until *at* 1 m to do anything, and we
	; didn't let the robot stop moving forward before telling it to turn,
	; so it will likely move well past 1 m.  This code isn't
	; meant to be precise.
Test2:
	CALL   GetThetaErr ; get the heading error
	CALL   Abs         ; absolute value subroutine
	OUT    LCD         ; Display |angle error| for debugging
	ADDI   -5          ; check if within 5 degrees of target angle
	JPOS   Test2       ; if not, keep testing
	; the robot is now within 5 degrees of 90
	
	LOAD   FSlow       ; defined below as 100
	STORE  DVel

Test3: ; Did I mention that "Test3" is a terrible label?
	IN     YPOS        ; get the Y position from odometry
	SUB    OneMeter
	OUT    LCD         ; Display distance error for debugging
	JNEG   Test3       ; if not there, keep testing
	; the robot is now past 1 m in Y.

	LOAD   FFast       ; defined below as 500
	STORE  DVel

GoTo00: ; slightly better label than "test"
; This routine uses the provided ATAN2 subroutine to calculate
; the angle needed to reach (0,0).  The origin is a degenerative
; case, but you can use a little more math to use ATAN2 to point to
; any coordinate.
	IN     XPOS        ; get the X position from odometry
	CALL   Neg         ; negate
	STORE  AtanX
	IN     YPOS        ; get the X position from odometry
	CALL   Neg         ; negate
	STORE  AtanY
	CALL   Atan2       ; Gets the angle from (0,0) to (AtanX,AtanY)
	STORE  DTheta
	OUT    SSEG1       ; Display angle for debugging
	
	; The following bit of code uses another provided subroutine,
	; L2Estimate, the calculate the distance to (0,0).  Once again,
	; the origin is a degenerative case, but adding a bit more math can
	; extend this to any coordinate.
	IN     XPOS
	STORE  L2X
	IN     YPOS
	STORE  L2Y
	CALL   L2Estimate
	OUT    SSEG2       ; Display distance for debugging
	SUB    OneFoot
	JPOS   GoTo00      ; If >1 ft from destination, continue
	; robot is now near the origin

	; done
	LOADI  0
	STORE  DVel
	JUMP   Die



	
Die:
; Sometimes it's useful to permanently stop execution.
; This will also catch the execution if it accidentally
; falls through from above.
	CLI    &B1111      ; disable all interrupts
	LOAD   Zero        ; Stop everything.
	OUT    LVELCMD
	OUT    RVELCMD
	OUT    SONAREN
	LOAD   DEAD        ; An indication that we are dead
	OUT    SSEG2       ; "dEAd" on the sseg
Forever:
	JUMP   Forever     ; Do this forever.
	DEAD:  DW &HDEAD   ; Example of a "local" variable


; Timer ISR.  Currently just calls the movement control code.
; You could, however, do additional tasks here if desired.
CTimer_ISR:
	CALL   ControlMovement
	RETI   ; return from ISR
	
	
; Control code.  If called repeatedly, this code will attempt
; to control the robot to face the angle specified in DTheta
; and match the speed specified in DVel
DTheta:    DW 0
DVel:      DW 0
ControlMovement:
	LOADI  50          ; used for the CapValue subroutine
	STORE  MaxVal
	CALL   GetThetaErr ; get the heading error
	; A simple way to get a decent velocity value
	; for turning is to multiply the angular error by 4
	; and add ~50.
	SHIFT  2
	STORE  CMAErr      ; hold temporarily
	SHIFT  2           ; multiply by another 4
	CALL   CapValue    ; get a +/- max of 50
	ADD    CMAErr
	STORE  CMAErr      ; now contains a desired differential

	
	; For this basic control method, simply take the
	; desired forward velocity and add the differential
	; velocity for each wheel when turning is needed.
	LOADI  510
	STORE  MaxVal
	LOAD   DVel
	CALL   CapValue    ; ensure velocity is valid
	STORE  DVel        ; overwrite any invalid input
	ADD    CMAErr
	CALL   CapValue    ; ensure velocity is valid
	STORE  CMAR
	LOAD   CMAErr
	CALL   Neg         ; left wheel gets negative differential
	ADD    DVel
	CALL   CapValue
	STORE  CMAL

	; ensure enough differential is applied
	LOAD   CMAErr
	SHIFT  1           ; double the differential
	STORE  CMAErr
	LOAD   CMAR
	SUB    CMAL        ; calculate the actual differential
	SUB    CMAErr      ; should be 0 if nothing got capped
	JZERO  CMADone
	; re-apply any missing differential
	STORE  CMAErr      ; the missing part
	ADD    CMAL
	CALL   CapValue
	STORE  CMAL
	LOAD   CMAR
	SUB    CMAErr
	CALL   CapValue
	STORE  CMAR

CMADone:
	LOAD   CMAL
	OUT    LVELCMD
	LOAD   CMAR
	OUT    RVELCMD

	RETURN
	CMAErr: DW 0       ; holds angle error velocity
	CMAL:    DW 0      ; holds temp left velocity
	CMAR:    DW 0      ; holds temp right velocity

; Returns the current angular error wrapped to +/-180
GetThetaErr:
	; convenient way to get angle error in +/-180 range is
	; ((error + 180) % 360 ) - 180
	IN     THETA
	SUB    DTheta      ; actual - desired angle
	CALL   Neg         ; desired - actual angle
	ADDI   180
	CALL   Mod360
	ADDI   -180
	RETURN

; caps a value to +/-MaxVal
CapValue:
	SUB     MaxVal
	JPOS    CapVelHigh
	ADD     MaxVal
	ADD     MaxVal
	JNEG    CapVelLow
	SUB     MaxVal
	RETURN
CapVelHigh:
	LOAD    MaxVal
	RETURN
CapVelLow:
	LOAD    MaxVal
	CALL    Neg
	RETURN
	MaxVal: DW 510

;***************************************************************
;* Subroutines
;***************************************************************


;*******************************************************************************
; Mod360: modulo 360
; Returns AC%360 in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Mod360:
	; easy modulo: subtract 360 until negative then add 360 until not negative
	JNEG   M360N
	ADDI   -360
	JUMP   Mod360
M360N:
	ADDI   360
	JNEG   M360N
	RETURN

;*******************************************************************************
; Abs: 2's complement absolute value
; Returns abs(AC) in AC
; Neg: 2's complement negation
; Returns -AC in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Abs:
	JPOS   Abs_r
Neg:
	XOR    NegOne       ; Flip all bits
	ADDI   1            ; Add one (i.e. negate number)
Abs_r:
	RETURN

;******************************************************************************;
; Atan2: 4-quadrant arctangent calculation                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Original code by Team AKKA, Spring 2015.                                     ;
; Based on methods by Richard Lyons                                            ;
; Code updated by Kevin Johnson to use software mult and div                   ;
; No license or copyright applied.                                             ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; To use: store dX and dY in global variables AtanX and AtanY.                 ;
; Call Atan2                                                                   ;
; Result (angle [0,359]) is returned in AC                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Requires additional subroutines:                                             ;
; - Mult16s: 16x16->32bit signed multiplication                                ;
; - Div16s: 16/16->16R16 signed division                                       ;
; - Abs: Absolute value                                                        ;
; Requires additional constants:                                               ;
; - One:     DW 1                                                              ;
; - NegOne:  DW 0                                                              ;
; - LowByte: DW &HFF                                                           ;
;******************************************************************************;
Atan2:
	LOAD   AtanY
	CALL   Abs          ; abs(y)
	STORE  AtanT
	LOAD   AtanX        ; abs(x)
	CALL   Abs
	SUB    AtanT        ; abs(x) - abs(y)
	JNEG   A2_sw        ; if abs(y) > abs(x), switch arguments.
	LOAD   AtanX        ; Octants 1, 4, 5, 8
	JNEG   A2_R3
	CALL   A2_calc      ; Octants 1, 8
	JNEG   A2_R1n
	RETURN              ; Return raw value if in octant 1
A2_R1n: ; region 1 negative
	ADDI   360          ; Add 360 if we are in octant 8
	RETURN
A2_R3: ; region 3
	CALL   A2_calc      ; Octants 4, 5            
	ADDI   180          ; theta' = theta + 180
	RETURN
A2_sw: ; switch arguments; octants 2, 3, 6, 7 
	LOAD   AtanY        ; Swap input arguments
	STORE  AtanT
	LOAD   AtanX
	STORE  AtanY
	LOAD   AtanT
	STORE  AtanX
	JPOS   A2_R2        ; If Y positive, octants 2,3
	CALL   A2_calc      ; else octants 6, 7
	CALL   Neg          ; Negatge the number
	ADDI   270          ; theta' = 270 - theta
	RETURN
A2_R2: ; region 2
	CALL   A2_calc      ; Octants 2, 3
	CALL   Neg          ; negate the angle
	ADDI   90           ; theta' = 90 - theta
	RETURN
A2_calc:
	; calculates R/(1 + 0.28125*R^2)
	LOAD   AtanY
	STORE  d16sN        ; Y in numerator
	LOAD   AtanX
	STORE  d16sD        ; X in denominator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  AtanRatio
	STORE  m16sA
	STORE  m16sB
	CALL   A2_mult      ; X^2
	STORE  m16sA
	LOAD   A2c
	STORE  m16sB
	CALL   A2_mult
	ADDI   256          ; 256/256+0.28125X^2
	STORE  d16sD
	LOAD   AtanRatio
	STORE  d16sN        ; Ratio in numerator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  m16sA        ; <= result in radians
	LOAD   A2cd         ; degree conversion factor
	STORE  m16sB
	CALL   A2_mult      ; convert to degrees
	STORE  AtanT
	SHIFT  -7           ; check 7th bit
	AND    One
	JZERO  A2_rdwn      ; round down
	LOAD   AtanT
	SHIFT  -8
	ADDI   1            ; round up
	RETURN
A2_rdwn:
	LOAD   AtanT
	SHIFT  -8           ; round down
	RETURN
A2_mult: ; multiply, and return bits 23..8 of result
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8            ; move high word of result up 8 bits
	STORE  mres16sH
	LOAD   mres16sL
	SHIFT  -8           ; move low word of result down 8 bits
	AND    LowByte
	OR     mres16sH     ; combine high and low words of result
	RETURN
A2_div: ; 16-bit division scaled by 256, minimizing error
	LOADI  9            ; loop 8 times (256 = 2^8)
	STORE  AtanT
A2_DL:
	LOAD   AtanT
	ADDI   -1
	JPOS   A2_DN        ; not done; continue shifting
	CALL   Div16s       ; do the standard division
	RETURN
A2_DN:
	STORE  AtanT
	LOAD   d16sN        ; start by trying to scale the numerator
	SHIFT  1
	XOR    d16sN        ; if the sign changed,
	JNEG   A2_DD        ; switch to scaling the denominator
	XOR    d16sN        ; get back shifted version
	STORE  d16sN
	JUMP   A2_DL
A2_DD:
	LOAD   d16sD
	SHIFT  -1           ; have to scale denominator
	STORE  d16sD
	JUMP   A2_DL
AtanX:      DW 0
AtanY:      DW 0
AtanRatio:  DW 0        ; =y/x
AtanT:      DW 0        ; temporary value
A2c:        DW 72       ; 72/256=0.28125, with 8 fractional bits
A2cd:       DW 14668    ; = 180/pi with 8 fractional bits

;*******************************************************************************
; Mult16s:  16x16 -> 32-bit signed multiplication
; Based on Booth's algorithm.
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: does not work with factor B = -32768 (most-negative number).
; To use:
; - Store factors in m16sA and m16sB.
; - Call Mult16s
; - Result is stored in mres16sH and mres16sL (high and low words).
;*******************************************************************************
Mult16s:
	LOADI  0
	STORE  m16sc        ; clear carry
	STORE  mres16sH     ; clear result
	LOADI  16           ; load 16 to counter
Mult16s_loop:
	STORE  mcnt16s      
	LOAD   m16sc        ; check the carry (from previous iteration)
	JZERO  Mult16s_noc  ; if no carry, move on
	LOAD   mres16sH     ; if a carry, 
	ADD    m16sA        ;  add multiplicand to result H
	STORE  mres16sH
Mult16s_noc: ; no carry
	LOAD   m16sB
	AND    One          ; check bit 0 of multiplier
	STORE  m16sc        ; save as next carry
	JZERO  Mult16s_sh   ; if no carry, move on to shift
	LOAD   mres16sH     ; if bit 0 set,
	SUB    m16sA        ;  subtract multiplicand from result H
	STORE  mres16sH
Mult16s_sh:
	LOAD   m16sB
	SHIFT  -1           ; shift result L >>1
	AND    c7FFF        ; clear msb
	STORE  m16sB
	LOAD   mres16sH     ; load result H
	SHIFT  15           ; move lsb to msb
	OR     m16sB
	STORE  m16sB        ; result L now includes carry out from H
	LOAD   mres16sH
	SHIFT  -1
	STORE  mres16sH     ; shift result H >>1
	LOAD   mcnt16s
	ADDI   -1           ; check counter
	JPOS   Mult16s_loop ; need to iterate 16 times
	LOAD   m16sB
	STORE  mres16sL     ; multiplier and result L shared a word
	RETURN              ; Done
c7FFF: DW &H7FFF
m16sA: DW 0 ; multiplicand
m16sB: DW 0 ; multipler
m16sc: DW 0 ; carry
mcnt16s: DW 0 ; counter
mres16sL: DW 0 ; result low
mres16sH: DW 0 ; result high

;*******************************************************************************
; Div16s:  16/16 -> 16 R16 signed division
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: results undefined if denominator = 0.
; To use:
; - Store numerator in d16sN and denominator in d16sD.
; - Call Div16s
; - Result is stored in dres16sQ and dres16sR (quotient and remainder).
; Requires Abs subroutine
;*******************************************************************************
Div16s:
	LOADI  0
	STORE  dres16sR     ; clear remainder result
	STORE  d16sC1       ; clear carry
	LOAD   d16sN
	XOR    d16sD
	STORE  d16sS        ; sign determination = N XOR D
	LOADI  17
	STORE  d16sT        ; preload counter with 17 (16+1)
	LOAD   d16sD
	CALL   Abs          ; take absolute value of denominator
	STORE  d16sD
	LOAD   d16sN
	CALL   Abs          ; take absolute value of numerator
	STORE  d16sN
Div16s_loop:
	LOAD   d16sN
	SHIFT  -15          ; get msb
	AND    One          ; only msb (because shift is arithmetic)
	STORE  d16sC2       ; store as carry
	LOAD   d16sN
	SHIFT  1            ; shift <<1
	OR     d16sC1       ; with carry
	STORE  d16sN
	LOAD   d16sT
	ADDI   -1           ; decrement counter
	JZERO  Div16s_sign  ; if finished looping, finalize result
	STORE  d16sT
	LOAD   dres16sR
	SHIFT  1            ; shift remainder
	OR     d16sC2       ; with carry from other shift
	SUB    d16sD        ; subtract denominator from remainder
	JNEG   Div16s_add   ; if negative, need to add it back
	STORE  dres16sR
	LOADI  1
	STORE  d16sC1       ; set carry
	JUMP   Div16s_loop
Div16s_add:
	ADD    d16sD        ; add denominator back in
	STORE  dres16sR
	LOADI  0
	STORE  d16sC1       ; clear carry
	JUMP   Div16s_loop
Div16s_sign:
	LOAD   d16sN
	STORE  dres16sQ     ; numerator was used to hold quotient result
	LOAD   d16sS        ; check the sign indicator
	JNEG   Div16s_neg
	RETURN
Div16s_neg:
	LOAD   dres16sQ     ; need to negate the result
	CALL   Neg
	STORE  dres16sQ
	RETURN	
d16sN: DW 0 ; numerator
d16sD: DW 0 ; denominator
d16sS: DW 0 ; sign value
d16sT: DW 0 ; temp counter
d16sC1: DW 0 ; carry value
d16sC2: DW 0 ; carry value
dres16sQ: DW 0 ; quotient result
dres16sR: DW 0 ; remainder result

;*******************************************************************************
; L2Estimate:  Pythagorean distance estimation
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: this is *not* an exact function.  I think it's most wrong
; on the axes, and maybe at 45 degrees.
; To use:
; - Store X and Y offset in L2X and L2Y.
; - Call L2Estimate
; - Result is returned in AC.
; Result will be in same units as inputs.
; Requires Abs and Mult16s subroutines.
;*******************************************************************************
L2Estimate:
	; take abs() of each value, and find the largest one
	LOAD   L2X
	CALL   Abs
	STORE  L2T1
	LOAD   L2Y
	CALL   Abs
	SUB    L2T1
	JNEG   GDSwap    ; swap if needed to get largest value in X
	ADD    L2T1
CalcDist:
	; Calculation is max(X,Y)*0.961+min(X,Y)*0.406
	STORE  m16sa
	LOADI  246       ; max * 246
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	STORE  L2T3
	LOAD   L2T1
	STORE  m16sa
	LOADI  104       ; min * 104
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	ADD    L2T3     ; sum
	RETURN
GDSwap: ; swaps the incoming X and Y
	ADD    L2T1
	STORE  L2T2
	LOAD   L2T1
	STORE  L2T3
	LOAD   L2T2
	STORE  L2T1
	LOAD   L2T3
	JUMP   CalcDist
L2X:  DW 0
L2Y:  DW 0
L2T1: DW 0
L2T2: DW 0
L2T3: DW 0


; Subroutine to wait (block) for 1 second
Wait1:
	OUT    TIMER
Wloop:
	IN     TIMER
	OUT    XLEDS       ; User-feedback that a pause is occurring.
	ADDI   -10         ; 1 second at 10Hz.
	JNEG   Wloop
	RETURN
	
; Subroutine to wait (block) for 1/2 second
Wait1Half:
	OUT    TIMER
WHalfLoop:
	IN     TIMER
	OUT    XLEDS       ; User-feedback that a pause is occurring.
	ADDI   -5          ; 1/2 second at 10Hz.
	JNEG   WHalfLoop
	RETURN

; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL   GetBattLvl
	JZERO  BattCheck   ; A/D hasn't had time to initialize
	SUB    MinBatt
	JNEG   DeadBatt
	ADD    MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOADI  &H20
	OUT    BEEP        ; start beep sound
	CALL   GetBattLvl  ; get the battery level
	OUT    SSEG1       ; display it everywhere
	OUT    SSEG2
	OUT    LCD
	LOAD   Zero
	ADDI   -1          ; 0xFFFF
	OUT    LEDS        ; all LEDs on
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	LOADI  &H140       ; short, high-pitched beep
	OUT    BEEP        ; stop beeping
	LOAD   Zero
	OUT    LEDS        ; LEDs off
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	JUMP   DeadBatt    ; repeat forever
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD   I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_DATA    ; get the returned data
	RETURN

; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   Zero        ; 0x0000 (A/D port 0, no increment)
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to block until I2C device is idle
BlockI2C:
	LOAD   Zero
	STORE  Temp        ; Used to check for timeout
BI2CL:
	LOAD   Temp
	ADDI   1           ; this will result in ~0.1s timeout
	STORE  Temp
	JZERO  I2CError    ; Timeout occurred; error
	IN     I2C_RDY     ; Read busy signal
	JPOS   BI2CL       ; If not 0, try again
	RETURN             ; Else return
I2CError:
	LOAD   Zero
	ADDI   &H12C       ; "I2C"
	OUT    SSEG1
	OUT    SSEG2       ; display error message
	JUMP   I2CError

;***************************************************************
;* Variables
;***************************************************************
Temp:     DW 0 ; "Temp" is not a great name, but can be useful

;***************************************************************
;* Constants
;* (though there is nothing stopping you from writing to these)
;***************************************************************
NegOne:   DW -1
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10

; Some bit masks.
; Masks of multiple bits can be constructed by ORing these
; 1-bit masks together.
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
LowByte:  DW &HFF      ; binary 00000000 1111111
LowNibl:  DW &HF       ; 0000 0000 0000 1111

; some useful movement values
DistanceA: DW 2133
OneMeter: DW 961       ; ~1m in 1.04mm units
TwoMeters: DW 1922	   ; ~2m in 1.04mm units
ThreeMeter: DW 2883	   ; ~3m in 1.04mm units
HalfMeter: DW 481      ; ~0.5m in 1.04mm units
FiveFeet: DW 1465	   ; ~4ft in 1.04mm units
FourFeet: DW 1172	   ; ~4ft in 1.04mm units
TwoFeet:  DW 586       ; ~2ft in 1.04mm units
OneFoot:  DW 293       ; ~1ft in 1.04mm units
Deg90:    DW 90        ; 90 degrees in odometer units
Deg180:   DW 180       ; 180
Deg270:   DW 270       ; 270
Deg360:   DW 360       ; can never actually happen; for math only
FSlow:    DW 100       ; 100 is about the lowest velocity value that will move
RSlow:    DW -100
FMid:     DW 350       ; 350 is a medium speed
RMid:     DW -350
FFast:    DW 500       ; 500 is almost max speed (511 is max)
RFast:    DW -500

MinBatt:  DW 140       ; 14.0V - minimum safe battery voltage
I2CWCmd:  DW &H1190    ; write one i2c byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190    ; write nothing, read one byte, addr 0x90


;***************************************************************
;* IO address space map
;***************************************************************
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
XLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
CTIMER:   EQU &H0C  ; Configurable timer for interrupts
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART_DAT: EQU &H98  ; UART data
UART_RDY: EQU &H98  ; UART status
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONALARM: EQU &HB0  ; Write alarm distance; read alarm register
SONARINT: EQU &HB1  ; Write mask for sonar interrupts
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-359)
RESETPOS: EQU &HC3  ; write anything here to reset odometry to 0
RIN:      EQU &HC8
LIN:      EQU &HC9
IR_HI:    EQU &HD0  ; read the high word of the IR receiver (OUT will clear both words)
IR_LO:    EQU &HD1  ; read the low word of the IR receiver (OUT will clear both words)

     
;variables to store sonar sweep at point A known values - TYLER
;this is essentially an array that can be accessed through its base address which is ASAdd
;this will help to shorten code above

;SweepVar: DW 12     ;variable to use when trying to rotate in sweep

ASAdd:    EQU Astore0 ;address of the first element in Asweep values(basically a poointer)

Astore0:  DW  0 	;sensor reading from sensor 1 for 45 deg
Astore1:  DW  0 	;sensor reading from sensor 2 for 45 deg
Astore2:  DW  0	    ;sensor reading from sensor 3 for 45 deg
Astore3:  DW  0	    ;sensro reading from sensor 4 for 45 deg 
Astore4:  DW  0     ;sensor reading from sensor 1 for 90 deg
Astore5:  DW  0     ;sensor reading from sensor 2 for 90 deg
Astore6:  DW  0     ;sensor reading from sensor 3 for 90 deg
Astore7:  DW  0     ;sensor reading from sensor 4 for 90 deg
Astore8:  DW  0     ;sensor reading from sensor 1 for 135 deg
Astore9:  DW  0     ;sensor reading from sensor 2 for 135 deg
Astore10:  DW  0    ;sensor reading from sensor 3 for 135 deg
Astore11:  DW  0    ;sensor reading from sensor 4 for 135 deg




;variables to store sonar sweep at point B known values - TYLER
;this is essentially an array that can be accessed through its base address which is BSAdd
;this will help to shorten code above



BSAdd:    EQU Bstore0 ;address of the first element in Asweep values(basically a poointer)

Bstore0:  DW  0 	;sensor reading from sensor 1
Bstore1:  DW  0 	;sensor reading from sensor 2
Bstore2:  DW  0	    ;sensor reading from sensor 3
Bstore3:  DW  0	    ;sensro reading from sensor 4
Bstore4:  DW  0     ;sensor reading from sensor 1 for 90 deg
Bstore5:  DW  0     ;sensor reading from sensor 2 for 90 deg
Bstore6:  DW  0     ;sensor reading from sensor 3 for 90 deg
Bstore7:  DW  0     ;sensor reading from sensor 4 for 90 deg
Bstore8:  DW  0     ;sensor reading from sensor 1 for 135 deg
Bstore9:  DW  0     ;sensor reading from sensor 2 for 135 deg
Bstore10:  DW  0    ;sensor reading from sensor 3 for 135 deg
Bstore11:  DW  0    ;sensor reading from sensor 4 for 135 deg


SonarVel:  DW  0    ;temp variable to store the velocity during
					;sonar software interupt




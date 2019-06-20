.model small
.stack 100h

.data
; VARIABLES

; buffer for itos subroutine
; used to store result
itos_buf: dw 6 dup(0)
; user input buffer
input_buf: db 5,?,5 dup(0)
; stores the number that the player has to guess
secret: db 4 dup(0)
; reset input buffer
; used in "you won! restart?" prompt
reset_buf: db 2,?,2 dup(0)

; CONSTANTS
; DOS strings (terminated by $)
newline:
    db 0Dh,0Ah,'$'
splash:
    ; logo created using https://www.kammerl.de/ascii/AsciiSignature.php
    ; using font "doom" with kerning enabled
    db 0Dh,0Ah
    db ' +-----------------------------------------------------------------+',0Dh,0Ah
    db ' | ______         _  _                 _____                       |',0Dh,0Ah
    db ' | | ___ \       | || |        ___    /  __ \                      |',0Dh,0Ah
    db ' | | |_/ / _   _ | || | ___   ( _ )   | /  \/  ___ __      __ ___  |',0Dh,0Ah
    db ' | | ___ \| | | || || |/ __|  / _ \/\ | |     / _ \\ \ /\ / // __| |',0Dh,0Ah
    db ' | | |_/ /| |_| || || |\__ \ | (_>  < | \__/\| (_) |\ V  V / \__ \ |',0Dh,0Ah
    db ' | \____/  \__,_||_||_||___/  \___/\/  \____/ \___/  \_/\_/  |___/ |',0Dh,0Ah
    db ' |                                                                 |',0Dh,0Ah
    db ' +-----------------------------------------------------------------+',0Dh,0Ah
    db 0Dh,0Ah
    db ' Programmed by Kfir Awad',0Dh,0Ah
    db ' for Cyber 2019 project',0Dh,0Ah
    db ' using emu8086',0Dh,0Ah
    db 0Dh,0Ah,'$'
splash_2:
    db 'Press any key to start...$'
secret_prompt:
    db 'Enter your secret number (4 digits): $'
number_bad:
    db 0Dh,0Ah,'Follow the instructions!',0Dh,0Ah,'$'
secret_ok:
    db 0Dh,0Ah,'Secret set! Starting game in 3...',0Dh,0Ah,'$'
secret_ok_2:
    db '2...',0Dh,0Ah,'$'
secret_ok_3:
    db '1!$'
guess_prompt:
    db 'Guess the secret number (4 digits): $'
guess_bulls: db ' bulls, $'
guess_cows: db ' cows',0Dh,0Ah,'$'
guess_correct: db 0Dh,0Ah,'Congratulations! You guessed the secret!$'
guess_correct_2: db 0Dh,0Ah,'Want to try again? (Y)es/(N)o: $'

; - NOTES -
; wait (ah=86h,int=21h):
; wait amount (microseconds) is DWORD, cx is upper 8 bytes and dx is lower 8 bytes
; cx=0Fh,dx=4240h (0F4240h) = 1 second

.code
prog_start:
    lea ax,data
    mov ds,ax

    ; set video mode
    mov al,3
    mov ah,0
    int 10h
    ; display splash screen
    lea dx,splash
    mov ah,9
    int 21h
    ; wait a second
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    ; display "press button" message
    lea dx,splash_2
    mov ah,9
    int 21h
    ; wait for key press
    mov ah,7
    int 21h
input_secret:
    mov al,3
    mov ah,0
    int 10h
    ; display secret prompt
    lea dx,secret_prompt
    mov ah,9
    int 21h
    ; get secret 
    lea dx,input_buf
    mov ah,0Ah
    int 21h
    ; make sure we got a number
    lea dx,input_buf
    add dx,2 ; actual text starts 2 bytes after input_buf
    push dx
    push 4
    call is_number
    cmp dl,0
    jne chksec_ok
;chksec_bad:
    ; show error
    lea dx,number_bad
    mov ah,9
    int 21h
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    ; try again
    jmp input_secret
chksec_ok:
    ; copy secret to memory
    lea bx,input_buf
    add bx,2
    lea di,secret
    mov cl,4
.cpyloop:
    mov ax,[bx]
    mov [di],ax
    inc bx
    inc di
    dec cl
    jnz .cpyloop
    ; countdown
    lea dx,secret_ok
    mov ah,9
    int 21h
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    lea dx,secret_ok_2
    mov ah,9
    int 21h
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    lea dx,secret_ok_3
    mov ah,9
    int 21h
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    mov al,3
    mov ah,0
    int 10h
guess_input:
    ; display guess prompt
    lea dx,guess_prompt
    mov ah,9
    int 21h
    ; get guess
    lea dx,input_buf
    mov ah,0Ah
    int 21h
chkguess:
    ; check that a number was entered
    lea dx,input_buf
    add dx,2 ; actual text starts 2 bytes after input_buf
    push dx
    push 4
    call is_number
    cmp dl,0
    jne chkguess_ok
;chkguess_bad:
    ; show error
    lea dx,number_bad
    mov ah,9
    int 21h
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    jmp guess_input
chkguess_ok:
    lea di,input_buf
    add di,2
    mov ax,0 ; al - number of bulls, ah - number of cows
    mov dx,0 ; dl - position in secret, dh - position in guess
.check_loop:
    lea bx,secret ; bx - points to number at position (dl) in secret
    mov ch,b.[di] ; ch - number at position (dh) in guess
    mov cl,4 ; cl - loop counter
    ; this loop checks if the number at position (dh) in guess is found in the secret
.contain_chk:
    cmp ch,b.[bx] ; compare secret with guess
    je .is_here ; if they're the same, we either have a cow or a bull
    inc bx
    inc dl
    dec cl
    jnz .contain_chk
    jmp .check_loop_2
.is_here:
    cmp dl,dh ; compare position in secret with position in guess
    je .bull ; if they're the same, it's a bull
    inc ah ; if not, it's a cow - increment cow counter
    jmp .check_loop_2 ; skip incrementing bull counter
.bull:
    inc al ; increment bull counter
.check_loop_2:
    inc di ; increment pointer to number in secret
    inc dh ; increment position in guess
    xor dl,dl ; dl = 0
    cmp dh,4
    jl .check_loop
    ; if bulls == 4, guesser guessed correctly
    cmp al,4
    jne .incorrect
    ; show "you won!" message
    lea dx,guess_correct
    mov ah,9
    int 21h
    mov cx,0Fh
    mov dx,4240h
    mov ah,86h
    int 15h
    ; show restart prompt
    lea dx,guess_correct_2
    mov ah,9
    int 21h
    ; get choice
    lea dx,reset_buf
    mov ah,0Ah
    int 21h
    ; check choice
    lea bx,reset_buf
    add bx,2 ; actual text starts 2 bytes after reset_buf
    mov al,[bx] ; get choice
    cmp al,'Y' ; if choice is Y, go to start of program
    je input_secret 
    cmp al,'y' ; if choice is y, go to start of program
    je input_secret
    ; clear screen
    mov al,3
    mov ah,0
    int 10h
    ; exit program
    mov ah,4Ch
    int 21h
.incorrect:
    ; print bulls
    push ax
    xor ah,ah
    call itos
    mov ah,9
    lea dx,newline
    int 21h
    lea dx,itos_buf
    int 21h
    lea dx,guess_bulls
    int 21h
    pop ax
    ; print cows
    mov al,ah
    xor ah,ah
    call itos
    mov ah,9
    lea dx,itos_buf
    int 21h
    lea dx,guess_cows
    int 21h
    jmp guess_input

; inputs:
;   AX - number to convert
; converts number to unsigned string, stored in itos_buf
PROC itos
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    mov si,10
    ; clear string buffer
    lea di,itos_buf
    mov cx,6
.clrbuf:
    mov b.[di],0
    inc di
    loop .clrbuf
    
    lea di,itos_buf
    mov cx,1 ; flag to prevent printing 0s before number
    mov bx,10000 ; divider
    cmp ax,0
    je .numzero
.nextdgt:
    ; if divider is 0, we're done
    cmp bx,0
    je .itosdone
    ; prevent leading zeroes
    cmp cx,0
    je .calcdgt
    ; if AX < BX, division result will be 0
    cmp ax,bx
    jb .skipdgt
.calcdgt:
    mov cx,0 ; set flag
    mov dx,0
    div bx ; AX = DX:AX / BX, DX = remainder
    ; add last digit to buffer
    ; AH is always 0, so it's ignored
    add al,30h ; convert to ASCII code
    mov b.[di],al
    inc di
    mov ax,dx ; get remainder from last DIV 
.skipdgt:
    ; calculate BX = BX / 10
    push ax
    mov dx,0
    mov ax,bx
    div si ; AX = DX:AX / 10, DX = remainder
    mov bx,ax
    pop ax
    jmp .nextdgt
.numzero:
    mov b.[di],'0'
    inc di
.itosdone:
    mov b.[di],'$'
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ENDP itos

; push string_offset
; push string_length
; outputs:
;    DL - 1 if string is number, 0 otherwise
PROC is_number
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    mov bx,[bp+6]
    mov cx,[bp+4]
    mov dl,0
.chkloop:
    mov al,[bx]
    cmp al,'0'
    jb .chkdone
    cmp al,'9'
    ja .chkdone
    inc bx
    dec cx
    jnz .chkloop
    mov dl,1
.chkdone:
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4 ; sp += 4, removes parameters from stack
ENDP is_number

END prog_start

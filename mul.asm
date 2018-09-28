                section         .text

                global          _start
_start:

                sub             rsp, 2 * 128 * 8       
                lea             rdi, [rsp + 128 * 8]   
                mov             rcx, 128			   ; rcx = 128
                call            read_long			   ; first long of length 128 is placed in csf - 128 to csf
                mov             rdi, rsp			   ; rdi = csf - 2*128
                call            read_long			   ; second long is placed in csf - 2*128 to csf - 128
                lea             rsi, [rsp + 128 * 8]   ; rsi now points to the first long
                call            multiply_long_long	   ; product begins at rdi

                call            write_long

                mov             al, 0x0a
                call            write_char

                jmp             exit


; multiplies two long numbers
;	 rdi -- address of multiplier (long number)
;	 rsi -- address of multiplicand (long number)
;	 rcx -- length of long numbers in qwords
; result:
;    product is written to rdi
multiply_long_long:
                push 			rbx
                push			rax
                push 			r9
                push 			r10
                push 			r11
                push			r12
                push			r13

                lea 			rax, [rcx * 8]
                lea				r13, [3*rax]
                sub 			rsp, rax
                mov				r9, rsp
                xchg			r9, rdi
                call			set_zero
                xchg			r9, rdi				; r9 is set to zero

                sub				rsp, rax
                sub				rsp, rax
                mov				r10, rsp
                xchg 			rdi, r10			; r10 is set to multiplier
                call			set_zero
                add				rdi, rax			; rdi for intermediate products, rcx qwords before are zero

                xchg			rsi, r10			; multiplier in rsi, mulitplicand in r10

                xor				r11, r11			; r11 is zero
                xor				r12, r12

; result is kept in r9, initially zero
; multiplier in rsi
; multiplicand in r10
; intermediate products in rdi, rcx qwords before rdi are zero
; current iteration index in r11, initially zero
; number of zeroes to prepend is stored in r12, initially zero
.loop:
                mov				rbx, [r10 + r12]
                call			multiply_long_short	; rdi = rsi * r10[i]
                sub				rdi, r12            ; prepend r11 zeroes to rdi
                xchg			rdi, r9				; temporarily, rdi = result
                xchg			r9, rsi				; temporarily, rsi = intermediate
                call			add_long_long		; add temporary product to result
                xchg			r9, rsi
                xchg			rdi, r9
                add				rdi, r12
                call			set_zero

                add				r12, 8
                inc				r11
                cmp 			r11, rcx
                jnz				.loop

                mov				rdi, rsi
                mov				rsi, r9
                call			copy_long_long
                mov 			rsi, r10

                add				rsp, r13

                pop				r13
                pop 			r12
                pop				r11
                pop				r10
                pop             r9
                pop				rax
                pop				rbx
                ret


; copies one long number to another
;	 rsi -- address of source
;	 rdi -- address of destination
;	 rcx -- lenght of long numbers in qwords
; result:
;	 long number at rsi is written to rdi
copy_long_long:
                push 			rdi
                push 			rsi
                push			rcx
.loop:
                mov				rax, [rsi]
                mov				[rdi], rax
                lea				rsi, [rsi + 8]
                lea				rdi, [rdi + 8]
                dec				rcx
                jnz				.loop

                pop				rcx
                pop				rsi
                pop				rdi
                ret


; multiplies long number by a short
;    rsi -- address of multiplier #1 (long number)
;    rbx -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to rdi
multiply_long_short:
                push            rax
                push            rsi
                push			rdi
                push            rcx

                xor             r8, r8
.loop:
                mov             rax, [rsi]
                mul             rbx
                add             rax, r8
                adc             rdx, 0
                mov             [rdi], rax
                add             rdi, 8
                add				rsi, 8
                mov             r8, rdx
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rdi
                pop				rsi
                pop             rax
                ret


; adds two long number
;    rdi -- address of summand #1 (long number)
;    rsi -- address of summand #2 (long number)
;    rcx -- length of long numbers in qwords
; result:
;    sum is written to rdi
add_long_long:
                push            rdi
                push            rsi
                push            rcx

                clc									; clear carry flag
.loop:
                mov             rax, [rsi]
                lea             rsi, [rsi + 8]
                adc             [rdi], rax
                lea             rdi, [rdi + 8]
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rsi
                pop             rdi
                ret

; adds 64-bit number to long number
;    rdi -- address of summand #1 (long number)
;    rax -- summand #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    sum is written to rdi
add_long_short:
                push            rdi
                push            rcx
                push            rdx

                xor             rdx,rdx
.loop:
                add             [rdi], rax
                adc             rdx, 0
                mov             rax, rdx
                xor             rdx, rdx
                add             rdi, 8
                dec             rcx
                jnz             .loop

                pop             rdx
                pop             rcx
                pop             rdi
                ret

; multiplies long number by a short
;    rdi -- address of multiplier #1 (long number)
;    rbx -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to rdi
mul_long_short:
                push            rax
                push            rdi
                push            rcx

                xor             rsi, rsi
.loop:
                mov             rax, [rdi]
                mul             rbx
                add             rax, rsi
                adc             rdx, 0
                mov             [rdi], rax
                add             rdi, 8
                mov             rsi, rdx
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rdi
                pop             rax
                ret

; divides long number by a short
;    rdi -- address of dividend (long number)
;    rbx -- divisor (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    quotient is written to rdi
;    rdx -- remainder
div_long_short:
                push            rdi
                push            rax
                push            rcx

                lea             rdi, [rdi + 8 * rcx - 8]
                xor             rdx, rdx

.loop:
                mov             rax, [rdi]
                div             rbx
                mov             [rdi], rax
                sub             rdi, 8
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rax
                pop             rdi
                ret

; assigns a zero to long number
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
set_zero:
                push            rax
                push            rdi
                push            rcx

                xor             rax, rax
                rep stosq

                pop             rcx
                pop             rdi
                pop             rax
                ret

; checks if a long number is a zero
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
; result:
;    ZF=1 if zero
is_zero:
                push            rax
                push            rdi
                push            rcx

                xor             rax, rax
                rep scasq

                pop             rcx
                pop             rdi
                pop             rax
                ret

; read long number from stdin
;    rdi -- location for output (long number)
;    rcx -- length of long number in qwords
read_long:
                push            rcx
                push            rdi

                call            set_zero
.loop:
                call            read_char
                or              rax, rax
                js              exit
                cmp             rax, 0x0a
                je              .done
                cmp             rax, '0'
                jb              .invalid_char
                cmp             rax, '9'
                ja              .invalid_char

                sub             rax, '0'
                mov             rbx, 10
                call            mul_long_short
                call            add_long_short
                jmp             .loop

.done:
                pop             rdi
                pop             rcx
                ret

.invalid_char:
                mov             rsi, invalid_char_msg
                mov             rdx, invalid_char_msg_size
                call            print_string
                call            write_char
                mov             al, 0x0a
                call            write_char

.skip_loop:
                call            read_char
                or              rax, rax
                js              exit
                cmp             rax, 0x0a
                je              exit
                jmp             .skip_loop

; write long number to stdout
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
write_long:
                push            rax
                push            rcx				; stack: rax, rcx

                mov             rax, 20			; rax = 20
                mul             rcx
                mov             rbp, rsp
                sub             rsp, rax

                mov             rsi, rbp

.loop:
                mov             rbx, 10
                call            div_long_short
                add             rdx, '0'
                dec             rsi
                mov             [rsi], dl
                call            is_zero
                jnz             .loop

                mov             rdx, rbp
                sub             rdx, rsi
                call            print_string

                mov             rsp, rbp
                pop             rcx
                pop             rax
                ret

; read one char from stdin
; result:
;    rax == -1 if error occurs
;    rax \in [0; 255] if OK
read_char:
                push            rcx
                push            rdi

                sub             rsp, 1
                xor             rax, rax
                xor             rdi, rdi
                mov             rsi, rsp
                mov             rdx, 1
                syscall

                cmp             rax, 1
                jne             .error
                xor             rax, rax
                mov             al, [rsp]
                add             rsp, 1

                pop             rdi
                pop             rcx
                ret
.error:
                mov             rax, -1
                add             rsp, 1
                pop             rdi
                pop             rcx
                ret

; write one char to stdout, errors are ignored
;    al -- char
write_char:
                sub             rsp, 1
                mov             [rsp], al

                mov             rax, 1
                mov             rdi, 1
                mov             rsi, rsp
                mov             rdx, 1
                syscall
                add             rsp, 1
                ret

exit:
                mov             rax, 60
                xor             rdi, rdi
                syscall

; print string to stdout
;    rsi -- string
;    rdx -- size
print_string:
                push            rax

                mov             rax, 1
                mov             rdi, 1
                syscall

                pop             rax
                ret


                section         .rodata
invalid_char_msg:
                db              "Invalid character: "
invalid_char_msg_size: equ             $ - invalid_char_msg

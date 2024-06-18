# Assembly program that interprets a single line of postfix expression involving decimal quantities and outputs the equivalent RISC-V 32-bit machine language instructions
/*
General registers used:

%r8 : Storage of the first number popped from the stack after encountering an operator. Used as an operand to perform the operation.
%r9 : Storage of the second number popped from the stack after encountering an operator. Used as an operand to perform the operation and as a storage for the result to push it to the stack.
%r10 : Temporary storage for a number to get its 12-bit binary representation. This register is shifted right in a loop in the conversion function to get the next bit.
%r11 : Temporary storage for the number in %r10. This register is "and"ed with 1 to get the least significant bit.
%r12 : Storage of the current character of the input line that is being read during input processing. Used for comparisons.
%r13 : Used for reading multi-digit numbers. Every time after a new succesive digit is read, %r13 is multiplied by 10 and added with that digit to build the number.
%r14 : Stores the input line since %rsi changes during outputs.
*/
.section .bss
input_buffer: .space 256            # Allocate 256 bytes for input buffer


.section .data
# predetermined output lines for operations since they don't change
add_operation_output: .string "0000000 00010 00001 000 00001 0110011\n"
subs_operation_output: .string "0100000 00010 00001 000 00001 0110011\n"
mult_operation_output: .string "0000001 00010 00001 000 00001 0110011\n"
xor_operation_output: .string "0000100 00010 00001 000 00001 0110011\n"
and_operation_output: .string "0000111 00010 00001 000 00001 0110011\n"
or_operation_output: .string "0000110 00010 00001 000 00001 0110011\n"


# 12-bit string representation of the integer popped from the stack and moved to a register
binary_buffer: .asciz "000000000000"
# predetermined output lines for immediate loading. They come after the 12-bit representation of the immediate. There 2 different outputs for 2 different registers
x1_reg_move_output: .string " 00000 000 00001 0010011\n"
x2_reg_move_output: .string " 00000 000 00010 0010011\n"

.section .text
.global _start

_start:
    # Read input from standard input
    mov $0, %eax                    # syscall number for sys_read
    mov $0, %edi                    # file descriptor 0 (stdin)
    lea input_buffer(%rip), %rsi    # pointer to the input buffer
    mov $256, %edx                  # maximum number of bytes to read
    syscall                         # perform the syscall

    mov %rsi, %r14 # input line is moved to %r14
    main:
        movzx (%r14), %r12 # current char is moved to %r12
        add $1, %r14 # increment the input line pointer
        
        # checking if the char is an operator first, jump to the corresponding operation block to process
        cmp $43, %r12 # +
        je addition

        cmp $45, %r12 # -
        je substraction

        cmp $42, %r12 # *
        je multiplication

        cmp $94, %r12 # ^
        je xor_label

        cmp $38, %r12 # &
        je and_label

        cmp $124, %r12 # |
        je or_label


        # char is not an operator, then it is either a digit or a whitespace that comes after a number (it cannot be \n or a whitespace that comes after an operator because there cases are handled in operation blocks)
        cmp $32, %r12 # comparison with whitespcae
        jne digit # jump to digit block if char is a digit

        # %r13 holds the temporary number that is used to build the multi-digit number, so char being whitespace means all the digits of the number is read
        push %r13 # push the number to the stack
        mov $0, %r13 # reset the temporary number holder
        jmp main # continue with the next char
 

digit:
    imul $10, %r13 # multiply the temporary number in %r13 with 10
    sub $'0', %r12 # ascii to decimal conversion
    add %r12, %r13 # add the read digit
    jmp main # continue with the next char



print_func:
    # Assumes edx has size and rsi has address (popped from stack)
    mov $1, %eax              # syscall number for sys_write
    mov $1, %edi              # file descriptor 1 (stdout)
    syscall
    ret

exit_program:
    # Exit the program
    mov $60, %eax               # syscall number for sys_exit
    xor %edi, %edi              # exit code 0
    syscall

addition:
    pop %r8 # pop the first number into %r8 (which is the x2 register)
    mov %r8, %r10 # copy the number to %r10 because %r10 will be modified during the binary conversion. Decimal value of the number must be preserved in %r8 to perform the addition later on
    lea binary_buffer(%rip), %rsi # pass the buffer's effective address to %rsi
    call int_to_12bit_binary
    mov $12, %edx # set the output length for the binary representation
    call print_func 
    lea x2_reg_move_output(%rip), %rsi
    mov $25, %edx # set the output length for the rest of the output line
    call print_func
    

    pop %r9 # pop the second number into %r8 (which is the x1 register)
    # same procedure for the second number
    mov %r9, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x1_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func

    # perform the addition and push the result into the stack
    add %r8, %r9
    push %r9

    mov $38, %edx # set the length of the output for addition operation
    lea add_operation_output(%rip), %rsi
    call print_func

    
    movzx (%r14), %r12 # move the next char to %r12
    cmp $10, %r12    # check if the next char is '\n' to terminate
    je exit_program
    # the next char is a whitespace that comes after an operator
    add $1, %r14 # increment the input line pointer
    jmp main # continue with the next char

substraction:
    #same procedure with addition
    pop %r8
    mov %r8, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x2_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func
    

    pop %r9
    mov %r9, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x1_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func

    sub %r8, %r9
    push %r9

    mov $38, %edx
    lea subs_operation_output(%rip), %rsi
    call print_func


    movzx (%r14), %r12
    cmp $10, %r12
    je exit_program
    add $1, %r14
    jmp main


multiplication:
    #same procedure with addition
    pop %r8
    mov %r8, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x2_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func
    

    pop %r9
    mov %r9, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x1_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func

    imul %r8, %r9
    push %r9

    mov $38, %edx
    lea mult_operation_output(%rip), %rsi
    call print_func
    

    movzx (%r14), %r12
    cmp $10, %r12
    je exit_program
    add $1, %r14
    jmp main

xor_label:
    #same procedure with addition
    pop %r8
    mov %r8, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x2_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func
    

    pop %r9
    mov %r9, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x1_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func

    xor %r8, %r9
    push %r9

    mov $38, %edx 
    lea xor_operation_output(%rip), %rsi 
    call print_func
    

    movzx (%r14), %r12 
    cmp $10, %r12   
    je exit_program
    add $1, %r14 
    jmp main

and_label:
    #same procedure with addition
    pop %r8
    mov %r8, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x2_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func
    

    pop %r9
    mov %r9, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x1_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func

    and %r8, %r9
    push %r9

    mov $38, %edx
    lea and_operation_output(%rip), %rsi
    call print_func
    

    movzx (%r14), %r12 
    cmp $10, %r12    
    je exit_program
    add $1, %r14 
    jmp main

or_label:
    #same procedure with addition
    pop %r8 
    mov %r8, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x2_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func
    

    pop %r9
    mov %r9, %r10
    lea binary_buffer(%rip), %rsi
    call int_to_12bit_binary
    mov $12, %edx
    call print_func 
    lea x1_reg_move_output(%rip), %rsi
    mov $25, %edx
    call print_func

    or %r8, %r9
    push %r9

    mov $38, %edx 
    lea or_operation_output(%rip), %rsi 
    call print_func
    

    movzx (%r14), %r12 
    cmp $10, %r12    
    je exit_program
    add $1, %r14 
    jmp main




# function to convert an integer to a 12-bit two's complement binary representation 
int_to_12bit_binary:
    mov $12, %rcx # set the loop count
    add $11, %rsi # start at the end of the buffer

convert_loop:
    # determine the bit and set accordingly
    mov %r10, %r11 # move the number to %r11 to be able to make 2 different modifications at the same time
    and $1, %r11 # get the least significant bit
    test %r11, %r11 # check the bit
    jz is_zero # if zero, set '0'
    movb $'1', (%rsi) # otherwise, set '1'
    jmp next_bit

is_zero:
    movb $'0', (%rsi) # set '0' if it is zero

next_bit:
    shr %r10 # shift the input number to the right
    dec %rsi # move to the previous character in the buffer
    loop convert_loop # repeat for each bit
    inc %rsi # increment rsi to make it point to the beginning of the buffer again after the loop ends
    ret

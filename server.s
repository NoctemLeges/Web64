.intel_syntax noprefix

.section .data
    sockaddr_in:
        .word 0x0002          
        .word 0x5000          
        .long 0x00000000      
        .zero 8
    buffer:
        .space 1024
    contents:
        .space 1024
    filename:
         .zero 17
    response:
        .ascii "HTTP/1.0 200 OK\r\n\r\n"
    wait_msg:
        .ascii "Listening for connections\n" 

.comm sockfd, 8, 8

.section .text
    .global _start

_start:
    xor rax, rax
    mov al, 41      #Socket             
    xor edi, edi
    mov dil, 2               
    xor esi, esi
    mov sil, 1               
    xor edx, edx             
    syscall
    mov [sockfd], rax        

    mov rdi, [sockfd]        
    lea rsi, [sockaddr_in] #bind  
    mov rdx, 16              
    mov eax, 49              
    syscall    

    mov rdi, [sockfd]
    mov rsi, 0      #Listen
    mov rax, 50
    syscall          

    mov rax,1
    mov rdi,1
    lea rsi, [wait_msg]
    mov rdx,26
    syscall
accept_loop:
    mov rdi,[sockfd]
    mov rsi,0       #Accept-returns the file descriptor of the direct socket in rax. Use that as the fd for read syscall
    mov rdx,0
    mov rax,43
    syscall
    mov r9,rax
    
    mov rax,0x39    #fork
    syscall

    cmp rax,0x0
    jne parent_only

#Child Code from here
    mov rdi,[sockfd]
    mov rax,3   #close
    syscall

    mov rdi, r9
    lea rsi, [buffer] #read
    mov rdx, 1024
    mov rax,0
    syscall
#Check for type of request
    mov r15,0
    lea rsi,buffer
request_type_test_loop:
    lodsb
    cmp al,0x20
    je after_request_type_test_routine
    inc r15
    jmp request_type_test_loop
after_request_type_test_routine:
    cmp r15, 4
    jne GET_Routine
    jmp POST_Routine

GET_Routine:
    lea rsi,[buffer+4]
    lea rdi,[filename]
    test: lodsb
    cmp al,0x20         #Parse the request to get the filename
    je after_parse
    stosb
    jmp test
    
after_parse:
    lea rsi,[rdi+1]
    mov rsi,0
    mov rax,2   #Open the requested file
    lea rdi,[filename]
    mov rsi,0
    syscall
    
    mov rdi, rax
    lea rsi, [contents] #read the requested file
    mov rdx, 256
    mov rax,0
    syscall
    mov r10,rax

    mov rdi,rdi
    mov rax,3   #close
    syscall

    mov rdi,r9
    lea rsi,[response] #Write
    mov rdx,0x13
    mov rax,1
    syscall

    mov rdi,r9
    lea rsi,[contents] #Write
    mov rdx,r10
    mov rax,1
    syscall
   
    jmp exit_routine

POST_Routine:
    lea rsi,[buffer+5]
    lea rdi,[filename]
    test_1: lodsb
    cmp al,0x20
    je after_parse_filename
    stosb
    jmp test_1

    after_parse_filename:
    lea rsi,[rdi+1]
    mov rsi,0

    mov rax,2   #Open the requested file
    lea rdi,[filename]
    mov rsi,65
    mov rdx,0x1ff
    syscall
    mov r10,rax

    lea rsi,[buffer+176]
    lea rdi,[contents]
    loop_for_contents: lodsb
    cmp al,'\r'
    je after_loop_for_contents
    jmp loop_for_contents

after_loop_for_contents:
	mov r12,0
	add rsi,3
	loop_for_actual_contents: lodsb
    cmp al,0
    je after_parse_post
    inc r12
    stosb
    jmp loop_for_actual_contents


after_parse_post:
    mov rdi,r10
    lea rsi,[contents] #Write                                                                                        
    mov rdx,r12
    mov rax,1
    syscall

    mov rdi,r10
    mov rax,3   #close
    syscall

    mov rdi,r9
    lea rsi,[response] #Write                                                                                        
    mov rdx,0x13
    mov rax,1
    syscall
    
    jmp exit_routine

exit_routine:  
    mov eax, 60     #Exit         
    xor edi, edi             
    syscall

parent_only:
    mov rdi,r9
    mov rax,3   #close
    syscall
    jmp accept_loop


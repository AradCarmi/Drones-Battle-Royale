%macro backup 0
    push esp    
    push ecx    
    push edx    
    push ebx    
    push ebp    
    push esi    
    push edi    
    pushfd    
%endmacro

%macro restore 0
    popfd           ;restore Flags
    pop edi
    pop esi
    pop ebp
    pop ebx
    pop edx
    pop ecx
    pop esp
%endmacro


section .text
    align 16
    global target_func
    extern cors
    extern resume
    extern createTarget
    extern active_drone_cor
target_func:

    backup
    call createTarget
    restore
    mov ebx,[active_drone_cor]
    call resume 
    jmp target_func
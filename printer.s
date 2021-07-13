%define X 0
%define Y 4
%define SPEED 8
%define HEADING 12
%define SCORE 16
%define IS_ACTIVE 20

%macro startFunc 1 
    push ebp        ;backup EBP
    mov ebp, esp    ;set EBP to Func activation frame   
    sub esp, %1     ;allocate space for local variables (%1 bytes)
%endmacro

%macro endFunc 1
    mov esp,ebp     ; free function activation frame 
    pop dword ebp         ; restore activation frame of caller
%endmacro

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

section .data
    drone_format: db "drone_%d , x:%.2f , y:%.2f , heading:%.2f , speed:%.2f , is_active:%d score:%d",10,0
    target_format: db "target- x:%.2f   y:%.2f",10,0
    pfloat_format: db "%.2f",10,0
section .text
    align 16
    global print_func
    extern target
    extern drones
    extern printf
    extern N
    extern cors
    extern resume
print_func:

    ;--------------------print target-----------------
    mov eax,[target+Y]
    push eax
    fld dword [esp]
    pop eax
    sub esp,8
    fstp qword [esp]   
    mov eax,[target+X]
    push eax
    fld dword [esp]
    pop eax
    sub esp,8
    fstp qword [esp]
    push target_format
    call printf
    add esp,20
    ;------------------end print target-----------------
    
    ;--------------print drones-------------------------
    mov ecx,0
    print_drones_for:
        cmp ecx,[N]
        je end_print_drones_for    
        mov edx,[drones]
        shl ecx,2
        add edx,ecx
        shr ecx,2
        mov edx,[edx]

        backup 

        push dword [edx+SCORE]
        push dword [edx + IS_ACTIVE]

        mov eax,[edx+SPEED]
        push eax
        fld dword [esp]
        pop eax
        sub esp,8
        fstp qword [esp]   
        
        mov eax,[edx+HEADING]
        push eax
        fld dword [esp]
        pop eax
        sub esp,8
        fstp qword [esp]
        
        mov eax,[edx+Y]
        push eax
        fld dword [esp]
        pop eax
        sub esp,8
        fstp qword [esp]
        
        mov eax,[edx+X]
        push eax
        fld dword [esp]
        pop eax
        sub esp,8
        fstp qword [esp]  
        
        push ecx
        
        push drone_format
        call printf
        add esp,48

        restore 

        inc ecx
        jmp print_drones_for
    end_print_drones_for:
    
    mov ebx,[cors]
    mov ebx,[ebx]
    call resume 
    jmp print_func
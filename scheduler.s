%define X 0
%define Y 4
%define SPEED 8
%define HEADING 12
%define SCORE 16
%define IS_ACTIVE 20
%define DRONE_CORS 12
%define PRINTER 8

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

%macro startFunc 1 
    push ebp        ;backup EBP
    mov ebp, esp    ;set EBP to Func activation frame   
    sub esp, %1     ;allocate space for local variables (%1 bytes)
%endmacro

%macro endFunc 1
    mov esp,ebp     ; free function activation frame 
    pop ebp         ; restore activation frame of caller
%endmacro


%macro print 2
    backup
    push dword %2
    push dword %1
    call printf
    add esp,8
    restore
%endmacro

section .data
    winner_format: db "The Winner is drone:%d",10,0
section .text
    global scheduler_func
    extern active_drone
    extern drones
    extern num_of_active_drones
    extern N
    extern K
    extern R
    extern cors
    extern resume
    extern endCo
    extern printf
    extern active_drone_cor
section .bss
    i_div_N: resd 1
    i_mod_N: resd 1

section .text
scheduler_func:
    mov ecx,0
    scheduler_for:
        mov edx,0                       

        ;--------------compute i/N--------------------------
        mov eax,ecx                 ; eax = counter
        div dword [N]
        mov [i_div_N],eax                                   
        mov [i_mod_N],edx              ; edx = i

        ;--------------check relevant drone active-----------
        
        mov eax,[drones]
        shl edx,2
        mov ebx,edx                 ; ebx = i*4    (edx=i)                    
        add eax,edx                 ; eax = drones + i*4 = pointer to drone i
        shr edx,2   
        mov eax,[eax]
        mov [active_drone],eax
        mov eax,[eax+IS_ACTIVE]

        ;----------------------------------------------------
        cmp eax,1
        jne print?                  ; if active activate cor
        
        ;------------switch to drone_i_cor-------------------
        add ebx,DRONE_CORS          
        mov edi,ebx
        mov ebx,[cors]          ; ebx = pointer to DRONE_COR_i
        add ebx,edi
        mov ebx,[ebx]
        mov [active_drone_cor],ebx      
        call resume
        
        print?:
        ;--------------compute i/K--------------------------
        mov edx,0
        mov eax,ecx                 ; eax = counter
        div dword [K]
                                    ; eax = i/k     ; edx = i%k
        cmp edx,0
        jne destroy?
        ;--------------switch to printer--------------------
        mov ebx,[cors]
        add ebx,PRINTER
        mov ebx,[ebx]
        call resume
        
        destroy?:
        ;-------------compute (i/N)%R-----------------------
        cmp dword ecx,[N]
        jb scheduler_for_incr
        mov edx,0
        mov eax,[i_div_N]
        div dword [R]
        cmp edx,0
        jne scheduler_for_incr
        cmp dword [i_mod_N],0
        jne scheduler_for_incr

        ;------------destroy one drone---------------------
        backup
        call find_lowest_score
        restore
        backup
        push eax                ; push min score
        call destroy
        add esp,4               ; free space allocated for argument
        restore
        ;---------------------------------------------------

        scheduler_for_incr:
            inc ecx
            cmp dword [num_of_active_drones],1
            jne scheduler_for

        mov ecx,0
        search_winner:
            mov eax,[drones]
            shl ecx,2
            add eax,ecx                 ; now eax = pointer to drone (i)
            shr ecx,2
            mov eax,[eax]
            cmp dword [eax+IS_ACTIVE],1
            je print_winner
            inc ecx
            jmp search_winner
        print_winner:
            mov ebx,[cors]
            add ebx,PRINTER
            mov ebx,[ebx]
            call resume

            print winner_format,ecx
            jmp endCo

find_lowest_score:
    startFunc 0
    mov ecx,0
    mov eax,0xffff                               ; eax = min score
    find_lowest_score_for:
    cmp ecx,[N]
    je end_find_lowest_score_for
    mov ebx,[drones]
    shl ecx,2
    add ebx,ecx
    shr ecx,2
    mov ebx,[ebx]

    mov edx,[ebx + IS_ACTIVE]                       
    cmp edx,1
    jne  find_lowest_score_for_incr    
    mov ebx,[ebx+SCORE]
    cmp ebx,eax
    jnb find_lowest_score_for_incr                                ; if ebx < eax
    mov eax,ebx
    find_lowest_score_for_incr:
    inc ecx
    jmp find_lowest_score_for
    end_find_lowest_score_for:

    endFunc 0
    ret
    
destroy:                            ; void destroy(min_score)
    startFunc 0 
    mov eax,[ebp+8]                 ; eax = min score
    mov ecx,0
    destory_while:
        mov ebx,[drones]
        shl ecx,2
        add ebx,ecx
        shr ecx,2
        mov ebx,[ebx]
        cmp dword [ebx + IS_ACTIVE],1                                
        jne destory_while_incr                                ; if drone isnt active
        cmp eax,[ebx + SCORE]                   
        jne destory_while_incr                                ; if drone.score = min score
        add ebx,IS_ACTIVE
        mov dword [ebx],0
        dec dword [num_of_active_drones]
        jmp end_destory_while
        destory_while_incr:
        inc ecx
        jmp destory_while
    end_destory_while:

    endFunc 0
    ret
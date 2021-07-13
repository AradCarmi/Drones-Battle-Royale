%define X 0
%define Y 4
%define SPEED 8
%define HEADING 12
%define SCORE 16
%define IS_ACTIVE 20
%define DRONE_CORS 12
%define PRINTER 8
%define TARGET_COR 4
%macro scale 3
    backup
    push word %3
    push dword %2
    push dword %1
    call _scale
    add esp,10
    restore
%endmacro

%macro random_gen 0
    backup
    call _random_gen
    restore
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

%macro fpush 1
    push %1
    fld dword [esp]
    add esp,4
%endmacro

%macro fipush 1
    push %1
    fild dword [esp]
    add esp,4
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

section .text
    global drone_func
    extern cors
    extern resume
    extern _random_gen
    extern _scale
    extern active_drone
    extern target
    extern d
drone_func:
    
    ;-------generate random heading and speed------
    random_gen                      ; short random_gen()
    scale -60,60,ax                 ; float head_scaled = scale(-60,60,rand_number)
    mov esi,eax                     ; esi = head_scaled

    random_gen                      ; short random_gen()
    scale -10,10,ax                 ; float speed_scaled = scale(-60,60,rand_number)
    mov edi,eax                     ; edi = speed_scaled
    
    
    mov eax,[active_drone]
    
    ;--------------compute new x and y--------------
    mov ebx,[eax+HEADING]
    mov ecx,[eax+SPEED]

 
    ;----degrees to radiens-----
    fpush ebx
    fipush 180
    fdivp
    fldpi
    fmulp
    ;---------sin(heading)*speed-----
    fsin
    fpush ecx
    fmulp
    ;-------y= y + delta_y---------
    fpush dword [eax+Y]
    faddp

    ;---- check y in range---------
    fipush 100
    fcomip
    fstp
    jc above100y
    fipush 0
    fcomip
    fstp
    jnc below0y
    jmp in_rangey
    above100y:
        fipush 100
        fsubp
        jmp in_rangey
    below0y:
        fipush 100
        faddp
    in_rangey:
    fstp dword [eax+Y]
    fpush dword [eax+Y]

    ;----degrees to radiens-----
    fpush ebx
    fipush 180
    fdivp
    fldpi
    fmulp
    ;---------cos(heading)*speed-----
    fcos
    fpush ecx
    fmulp
    ;-------x= x + delta_x---------
    fpush dword [eax+X]
    faddp

    ;---- check x in range---------
    fipush 100
    fcomip
    fstp
    jc above100x
    fipush 0
    fcomip
    fstp
    jnc below0x
    jmp in_rangex
    above100x:
        fipush 100
        fsubp
        jmp in_rangex
    below0x:
        fipush 100
        faddp
    in_rangex:
    fstp dword [eax+X]
    

    ;------save new heading-----
    fpush esi
    fpush ebx
    faddp
    fipush 360
    fcomip
    fstp
    jc above360
    fipush 0
    fcomip
    fstp
    jnc below0heading
    jmp in_range_heading
    above360:
        fipush 360
        fsubp
        jmp in_range_heading
    below0heading:
        fipush 360
        faddp
    in_range_heading:
        fstp dword [eax+HEADING]
        

    
    ;--------------------------
    
    ;-------save new speed-----
    fpush edi
    fpush ecx
    faddp
    fipush 100
    fcomip
    fstp
    jc above100speed
    fipush 0
    fcomip
    fstp
    jnc below0speed
    jmp in_range_speed
    above100speed:
        fipush 100
        jmp in_range_speed
    below0speed:
        fipush 0
    in_range_speed:
        fstp dword [eax+SPEED]
        
    
    ;--------------------------

    backup
    call mayDestroy
    restore

    
    cmp eax,1
    je destroy_target
    jmp end_destroy_target
    destroy_target:
        mov eax,[active_drone]
        inc dword [eax+SCORE]
        mov ebx,[cors]
        add ebx,TARGET_COR
        mov ebx,[ebx]
        call resume 
    end_destroy_target:

    mov ebx,[cors]
    mov ebx,[ebx]
    
    call resume 
    jmp drone_func




mayDestroy:
    startFunc 0
    ;--------calculate distance-------
    mov eax,[active_drone]
    fpush dword [eax+X]
    fpush dword [target+X]
    fsubp
    fst st1
    fmulp                     ;(drone.x-target.x)^2
    sub esp,8
    fstp qword [esp]

    fpush dword [eax+Y]
    fpush dword [target+Y]
    fsubp
    fst st1
    fmulp                     ;(drone.y-target.y)^2

    fld qword [esp]
    add esp,8
    faddp                     ; (drone.x-target.x)^2 + (drone.y-target.y)^2
    fsqrt                     ; sqrt ((drone.x-target.x)^2 + (drone.y-target.y)^2)

    fpush dword [d]
    fcomip
    fstp
    jnc yes_destroy
    ;-------------------------------

    mov eax,0
    jmp end_mayDestroy
    yes_destroy:
        mov eax,1
    end_mayDestroy:
    endFunc 0
    ret
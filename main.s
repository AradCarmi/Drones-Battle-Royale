%define MAX_HEADING 10
%define MIN_HEADING -10
%define MAX_UNSIGNED_INT16 65535 
%define MIN_COORDINATE 0
%define MAX_COORDINATE 100
%define MIN_SPEED -10
%define MAX_SPEED 10
%define SIZE_OF_DRONE 24
%define X 0
%define Y 4
%define SPEED 8
%define HEADING 12
%define SCORE 16
%define IS_ACTIVE 20
%define SIZE_OF_COR 8
%define CODEP 0
%define SPP 4

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

%macro scan 3
    backup
    push dword %3
    push dword %2
    push dword %1
    call sscanf
    add esp,12
    restore
%endmacro

%macro print 2
    backup
    push dword %2
    push dword %1
    call printf
    add esp,8
    restore
%endmacro

%macro scale 3
    backup
    push word %3
    push dword %2
    push dword %1
    call _scale
    add esp,10
    restore
%endmacro

%macro _malloc 1
    backup
    push dword %1
    call malloc
    add esp,4
    restore
%endmacro

%macro random_gen 0
    backup
    call _random_gen
    restore
%endmacro

%macro _free 1
    backup
    push %1
    call free
    add esp,4
    restore
%endmacro

%macro makecor 1

%endmacro
section .text
    align 16
    global main
    global _random_gen
    global createTarget
    global target
    global drones
    global N
    global K
    global R
    global d
    global cors
    global resume
    global endCo
    global num_of_active_drones
    global active_drone_cor
    global _scale
    global active_drone
    extern malloc 
    extern calloc 
    extern free 
    extern sscanf
    extern printf
    extern print_func
    extern drone_func
    extern scheduler_func
    extern target_func
section .data
    short_format: db "%hi",10,0
    int_format: db "%d",10,0
    float_format: db "%f",10,0
    pfloat_format: db "%.2f",10,0

section .bss
    N : resd 1                              ; int N;
    R : resd 1                              ; int R;
    K : resd 1                              ; int K;
    d : resd 1                              ; float d;
    seed : resd 1                           ; int seed 
    lfsr :resb  2                           ; short lfsr (current lfsr value)
    target : resd 1                         ; float x
             resd 1                         ; float y
    drones : resd 1                         ; drone **
    cors :  resd  1                         ; cor**
    num_of_cors : resd 1
    num_of_active_drones : resd 1 
    active_drone_cor : resd 1
    active_drone : resd 1
    STKSZ equ 16*1024
    CURR: resd 1 
    SPT: resd 1                             ; temporary stack pointer
    SPMAIN: resd 1                          ; stack pointer of main

section .text

; scales a given number to a number in the range [min,nax]
; first we scale the number in the range [0,max + |min|]
; then we sub |min| from the value
; [-30,30] --> [0,60] --> sub 30
; assume min & max are integers
; assume max > 0
_scale:                                                 ; float scale(int min,int max,short number)
    startFunc 0

    mov eax,0
    mov ax,[ebp+16]                                    ; eax = number
    push eax                                
    fild dword [esp]                                    ; st0 = number
    pop eax
    push MAX_UNSIGNED_INT16
    fild dword [esp]                                    ; st1 = MAXINT
    pop eax
    fdivp                                               ; st0 = number/MAXINT

    mov eax,[ebp+8]                                     ; eax = min
    cmp eax,0
    jns pos
    sub eax,1
    not eax                                             ; eax = |min|
    pos:
    mov ebx,[ebp+12]                                    ; ebx =  max
    add ebx,eax                                         ; ebx =  |min| + max
    push ebx
    fild dword [esp]                                    ; st1 = |min|
    pop ebx
    fmulp                                               ; st0 in [0, |min| + max]
    push eax
    fild dword [esp]                                    ; st = |min|
    pop eax
    fsubp                                               ; st0 in the range [min,max]
    
    sub esp,4
    fstp dword [esp]
    pop eax                                             ; eax = result

    finit
    endFunc 0 
    ret
initialize_drones:
    startFunc 0 
    mov eax, [N]
    shl eax,2                       
    _malloc eax                                         ; malloc (4*num_of_drones) --> 4 = sizeof pointer
    mov [drones],eax
    mov ebx,0                                           ; drones index
    initialize_drones_for:
        cmp ebx,[N]
        je end_initialize_drones_for
        
        mov ecx,[drones]                                ; ecx = pointer to drones[0]
        shl ebx,2
        add ecx,ebx                                     ; ecx = pointer to drones[i]
        shr ebx,2 
        _malloc SIZE_OF_DRONE
        mov [ecx],eax                                   ; drones[i] = pointer to drone
        mov edx,[ecx]

        random_gen                                      ; short random_gen()
        scale MIN_COORDINATE , MAX_COORDINATE , ax      ; float x_scaled = scale(MIN_COORDINATE,MAX_COORDINATE,rand_number)
        mov [edx+X],eax                                 ; drones[i].X = x_scaled
        
        random_gen                                      ; short random_gen()
        scale MIN_COORDINATE , MAX_COORDINATE , ax      ; float y_scaled = scale(MIN_COORDINATE,MAX_COORDINATE,rand_number)
        mov [edx+Y],eax                                 ; drones[i].Y = y_scaled

        random_gen                                      ; short random_gen()
        scale 0 , 100 , ax                              ; float speed_scaled = scale(MIN_SPEED,MAX_SPEED,rand_number)
        mov [edx+SPEED],eax                             ; drones[i].SPEED = speed_scaled

        random_gen                                      ; short random_gen()
        scale 0, 360 , ax                               ; float heading_scaled = scale(MIN_HEADING,MAX_HEADING,rand_number)
        mov [edx+HEADING],eax                           ; drones[i].HEADING = heading_scaled

        mov dword [edx+SCORE],0
        mov dword [edx+ IS_ACTIVE],1
        inc ebx
        jmp initialize_drones_for
    end_initialize_drones_for:
    
    endFunc 0 
    ret

initialize_cors:
    startFunc 0
        mov eax,[num_of_cors]
        shl eax,4
        _malloc eax                                     ; malloc (4*num_of_cors) --> 4 = sizeof pointer
        mov [cors],eax
        
        ;------------initialize scheduler-----------------
        mov ebx,[cors]
        _malloc SIZE_OF_COR
        mov [ebx],eax
        mov edx,[ebx]
        mov dword [edx+CODEP],scheduler_func
        _malloc STKSZ
        add eax,STKSZ
        mov [edx+SPP] , eax
        ;------------end initialize scheduler-------------

        ;------------initialize target-----------------
        mov ebx,[cors]
        add ebx,4
        _malloc SIZE_OF_COR
        mov [ebx],eax
        mov edx,[ebx]
        mov dword [edx+CODEP],target_func
        _malloc STKSZ
        add eax,STKSZ
        mov [edx+SPP] , eax
        ;------------end initialize targer-------------

        ;------------initialize printer-----------------
        mov ebx,[cors]
        add ebx,8
        _malloc SIZE_OF_COR
        mov [ebx],eax
        mov edx,[ebx]
        mov dword [edx+CODEP],print_func
        _malloc STKSZ
        add eax,STKSZ
        mov [edx+SPP] , eax
        ;------------end initialize printer-------------

        mov ecx,3                                       ; cors index 
        initialize_drone_cors_for:
            cmp ecx,[num_of_cors]
            je end_initialize_drone_cors_for
            mov ebx,[cors]                              ; ebx = pointer to cors[0]
            shl ecx,2
            add ebx,ecx                                 ; ebx = pointer to cors[i]
            shr ecx,2
            _malloc SIZE_OF_COR
            mov [ebx],eax                               ; cors[i] = pointer to cor
            mov edx,[ebx]                               
            mov dword [edx+CODEP],drone_func
            _malloc STKSZ
            add eax,STKSZ
            mov edi,edx 
            add edi,SPP 
            mov [edx+SPP] , eax
            inc ecx
            jmp initialize_drone_cors_for
        end_initialize_drone_cors_for:

    endFunc 0 
    ret

createTarget:                                           ; void createTarget()
    startFunc 0
    random_gen                                          ; short random_gen()
    scale MIN_COORDINATE , MAX_COORDINATE , ax          ; float scale(MIN_COORDINATE,MAX_COORDINATE,rand_number)
    mov [target+X],eax                                  ; target.X = x_scaled
    
    random_gen                                          ; short random_gen()
    scale  MIN_COORDINATE , MAX_COORDINATE , ax         ; float scale(MIN_COORDINATE,MAX_COORDINATE,rand_number)
    mov [target+Y],eax                                  ; target.Y = y_scaled
    
    endFunc 0
    ret

free_drones:
    startFunc 0
    mov ecx,0                                           ; counter
    free_drones_for:
        cmp ecx,[N]
        je end_free_drones_for
        mov eax,[drones]
        shl ecx,2
        add eax,ecx                                      ; eax = pointer to drones[i]
        shr ecx,2
        _free dword [eax]
        inc ecx
        jmp free_drones_for
    end_free_drones_for:
        _free dword [drones]
    endFunc 0 
    ret

free_cors:
    startFunc 0
    mov ecx,0                                           ; counter
    free_cors_for:
        cmp ecx,[num_of_cors]
        je end_free_cors_for
        mov eax,[cors]
        shl ecx,2
        add eax,ecx
        shr ecx,2
        mov ebx,[eax]
        add ebx,SPP
        mov ebx,[ebx]
        sub ebx,STKSZ
        add ebx,40                                      ; sizeof (eflags,registers and funci pushed in initCo)
        mov edx,eax
        _free ebx
        
        _free dword [edx]

        inc ecx
        jmp free_cors_for
    end_free_cors_for:
    _free dword [cors]
    endFunc 0 
    ret






_random_gen:                                 ; short _random_gen()
    startFunc 0
    mov ax,[lfsr]                            
    mov bx,0000000000000001b
    and bx,ax                               ; bx = tap 16
    mov cx,0000000000000100b                
    and cx,ax                               
    shr cx,2                                ; cx = tap 14
    xor bx,cx                               ; bx = xor tap16, tap14
    mov cx,0000000000001000b 
    and cx,ax
    shr cx,3                                ; cx = tap13
    xor bx,cx                               ; bx = xor (xor tap16,tap14) , tap13
    mov cx,0000000000100000b
    and cx,ax
    shr cx,5                                ; cx = tap11
    xor bx,cx                               ; bx = xor ((xor tap16,tap14) , tap13) , tap11
    shl bx,15                               ; put the result of all xors in the MSB
    shr ax,1                                ; shift lfsr to the right
    or ax,bx                                ; put the result of all xors in input bit
    mov [lfsr],ax
    mov ax,[lfsr]                           ; set return value
    endFunc 0 
    ret

initCo:                                     ; void initCo(i)
    startFunc 0
        mov ebx,[ebp+8]                     ; ebx = i
        shl ebx,2                           ; ebx = i*4
        mov ecx,[cors]
        add ebx,ecx
        mov ebx,[ebx]
        mov eax,[ebx+CODEP]                 ;!!!!!!!!!!!!!1
        mov [SPT],esp
        mov esp,[ebx+SPP]
        push eax
        pushfd
        pushad
        mov [ebx+SPP],esp
        mov esp,[SPT]
    endFunc 0
    ret
initCors_stack:
    startFunc 0
    mov ecx,0
    initCors_for:
        cmp ecx,[num_of_cors]
        je end_initCors_for
        backup
        push ecx
        call initCo
        add esp,4
        restore
        inc ecx
        jmp initCors_for
    end_initCors_for:
    endFunc 0
    ret
startCo:                                    ; startCo();
    pushad                                  ; save registers of main ()
    mov [SPMAIN], esp                       ; save ESP of main ()
    mov ebx, [cors]                         ; gets a pointer to a scheduler struct (scheduler is always cors[0])
    mov ebx,[ebx]
    jmp do_resume                           ; resume a scheduler co-routine

endCo:
    mov esp,[SPMAIN]
    popad   
    jmp finish
resume:                                     ; save state of current co-routine    
    pushfd
    pushad
    mov EDX, [CURR]
    mov [EDX+SPP], ESP                      ; save current ESP
do_resume:                                  ; load ESP for resumed co-routine
    mov ESP, [EBX+SPP]
    mov [CURR], EBX
    popad                                   ; restore resumed co-routine statepopfd
    popfd
    ret                                     ; "return" to resumed co-routine
    
main:
    startFunc 0
    finit
    ; ------------------ go over program arguments----------------
    mov esi,[ebp+12]     ; esi = argv
    
    add esi,4                               ; esi = argv[1]
    scan [esi],int_format,N                 ; sscanf(argv[1],"%d",N)
    mov eax,[N]
    mov [num_of_active_drones],eax
    add eax,3                               ; 3 -> printer , scheduler , target
    mov [num_of_cors],eax
    
    add esi,4                               ; esi = argv[2]
    scan [esi],int_format,R                 ; sscanf(argv[2],"%d",R)
    
    add esi,4                               ; esi = argv[3]
    scan [esi],int_format,K                 ; sscanf(argv[3],"%d",K)

    add esi,4                               ; esi = argv[4]
    scan [esi],float_format,d               ; sscanf(argv[4],"%f",d)
    
    add esi,4                               ; esi = argv[5]
    scan [esi],int_format,seed              ; sscanf(argv[5],"%d",seed)
    mov ax,[seed]
    mov [lfsr],ax
    ;----------------------------------------------------------------

    call createTarget
    call initialize_drones
    call initialize_cors
    call initCors_stack
    jmp startCo

    finish:
    call free_drones
    call free_cors
    
mov     ebx,eax
mov     eax,1
int     0x80
nop

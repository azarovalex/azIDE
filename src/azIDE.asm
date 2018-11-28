format PE GUI 4.0
entry start

include 'win32a.inc'

ID_SOURCE = 101
ID_INPUT  = 102
ID_RESULT = 103
ID_RUN    = 104
ID_CLEAR  = 105
ID_OPEN   = 106

; MARK: - Data section
section '.data' data readable writeable

szError1 db 'Syntax error at: %u',0
szError2 db 'Runtime error at: %u',0
szError  db 'Error.', 0
textbox_font  db 'Consolas', 0
file_filters  db 'Brainfuck source (*.b)', 0, '*.b;*.bf', 0, 0

szDef    db '++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++',13,10
         db '.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.',13,10
         db '------.--------.>+.>.',0

szSource rb 5000h
szInput  rb 500h
szOutput rb 500h
filename rb MAX_PATH

ofn:
    .lStructSize       dd 88
    .hwndOwner         dd NULL
    .hInstance         dd NULL
    .lpstrFilter       dd file_filters
    .lpstrCustomFilter dd NULL
    .nMaxCustFilter    dd 0
    .nFilterIndex      dd 1
    .lpstrFile         dd filename
    .nMaxFile          dd MAX_PATH
    .lpstrFileTitle    dd NULL
    .nMaxFileTitle     dd 0
    .lpstrInitialDir   dd NULL
    .lpstrTitle        dd NULL
    .Flags             dd OFN_HIDEREADONLY
    .nFileOffset       dw 0
    .nFileExtension    dw 0
    .lpstrDefExt       dd NULL
    .lCustData         dd NULL
    .lpfnHook          dd NULL
    .lpTemplateName    dd NULL
    .lpReserved        dd NULL
    .dwReserved        dd 0
    .FlagsEx           dd 0

file_data_ptr   dd ?
heap_handle     dd ?
file_handle     dd ?
file_size       dd ?
num_bytes_read  dd ?
hwnd_textbox    dd ?
hwnd_main       dd ?

; MARK: - Code section

section '.code' code readable executable

start:
        push 0
        call [GetModuleHandle]

        push 0
        push DialogProc
        push NULL
        push 42
        push eax
        call [DialogBoxParam]

        push 0
        call [ExitProcess]

proc DialogProc hwnddlg,msg,wparam,lparam
        push ebx esi edi
        cmp  [msg],WM_INITDIALOG
        je   .wminitdialog
        cmp  [msg],WM_COMMAND
        je   .wmcommand
        cmp  [msg],WM_CLOSE
        je   .wmclose
        xor  eax,eax
        jmp  .finish
.wminitdialog:
        push szDef
        push ID_SOURCE
        push [hwnddlg]
        call [SetDlgItemText]

        push textbox_font
        push DEFAULT_PITCH
        push PROOF_QUALITY
        push CLIP_DEFAULT_PRECIS
        push OUT_DEFAULT_PRECIS
        push ANSI_CHARSET

        xor ecx, ecx
        mov cl, 7
@@:
        push 0
        loop @r
        push 14
        call [CreateFont]
        push TRUE
        push eax
        push WM_SETFONT
        push ID_SOURCE
        push [hwnddlg]
        call [SendDlgItemMessage]

        jmp  .processed
.wmcommand:
        cmp  [wparam],IDCANCEL
        je   .wmclose
        cmp  [wparam],ID_RUN
        je   .wmrun
        cmp  [wparam],ID_CLEAR
        je   .wmclear
        cmp [wparam], ID_OPEN
        je .wmopen
        jmp  .processed

.wmopen:
        mov eax, [hwnddlg]
        mov [ofn.hwndOwner], eax
        push ofn
        call [GetOpenFileName]
        test eax, eax
        jz .processed

        push NULL
        push FILE_ATTRIBUTE_NORMAL
        push OPEN_EXISTING
        push NULL
        push FILE_SHARE_READ
        push GENERIC_READ
        push filename
        call [CreateFile]
        cmp eax, INVALID_HANDLE_VALUE
        jne .open_ok
        call error_msgbox
        jmp .processed
.open_ok:
        mov [file_handle], eax
        push NULL
        push eax
        call [GetFileSize]
        inc eax
        mov [file_size], eax
        call [GetProcessHeap]
        mov [heap_handle], eax
        push [file_size]
        push HEAP_ZERO_MEMORY
        push eax
        call [HeapAlloc]
        mov [file_data_ptr], eax
        push NULL
        push num_bytes_read
        push [file_size]
        push [file_data_ptr]
        push [file_handle]
        call [ReadFile]
        push [file_data_ptr]
        push ID_SOURCE
        push [hwnddlg]
        call [SetDlgItemText]
        push [file_handle]
        call [CloseHandle]
        push [file_data_ptr]
        push 0
        push [heap_handle]
        call [HeapFree]
        
        jmp .processed

.wmclear:
        push NULL
        push ID_SOURCE
        push [hwnddlg]
        call [SetDlgItemText]

        push NULL
        push ID_INPUT
        push [hwnddlg]
        call [SetDlgItemText]

        push NULL
        push ID_SOURCE
        push [hwnddlg]
        call [SetDlgItemText]
        jmp  .processed

.wmrun:
        push 5000h
        push szSource
        push ID_SOURCE
        push [hwnddlg]
        call [GetDlgItemText]

        push 5000h
        push szInput
        push ID_INPUT
        push [hwnddlg]
        call [GetDlgItemText]

        push 500h
        push szOutput
        call [RtlZeroMemory]

        stdcall Brainfuck,szSource,szInput,szOutput

        cmp     eax,-1
        jne     @f

        push edx        ; Syntax error
        push szError2
        push szOutput
        call [wsprintf]

        jmp     .set_result
@@:
        cmp     eax,-2
        jne     .set_result

        push edx        ; Runtime error
        push szError1
        push szOutput
        call [wsprintf]

.set_result:
        add  esp,12

        push szOutput
        push ID_RESULT
        push [hwnddlg]
        call [SetDlgItemText]

        jmp     .processed

.wmclose:
        push 0
        push [hwnddlg]
        call [EndDialog]
.processed:
        mov     eax,1
.finish:
        pop     edi esi ebx
        ret
endp

error_msgbox:
    push MB_OK
    push szError
    push szError
    push HWND_DESKTOP
    call [MessageBox]
    ret

;------------------------------------------------------------------
; Output:
;   EAX = 0  - success
;   EAX = -1 - syntax error   \  EDX has
;   EAX = -2 - runtime error  /  the error position
;------------------------------------------------------------------
proc Brainfuck lpSource:DWORD, lpInput:DWORD, lpOutput:DWORD
        BRAINFUCK_MEM_LENGTH=30000

        locals
                hHeap dd ?
                mem   dd ?
        endl

        call [GetProcessHeap]

        mov  [hHeap],eax
        push BRAINFUCK_MEM_LENGTH
        push HEAP_ZERO_MEMORY
        push eax
        call [HeapAlloc]
        mov  [mem],eax

        mov  esi,[lpSource]
        cld
        xor  ecx,ecx
.scan_loop:
        lodsb
        or   al,al
        jz   .scan_loop_done

        cmp  al,'['
        jne  @f
        inc  ecx
        jmp  .scan_loop
@@:
        cmp  al,']'
        jne  .scan_loop
        or   ecx,ecx
        je   .loc_syntax_error
        dec  ecx
        jmp  .scan_loop
.scan_loop_done:
        or   ecx,ecx
        jnz  .loc_syntax_error

        ; Execute the code
        mov  edi,[lpOutput]
        mov  esi,[lpInput]
        mov  edx,[lpSource]
        xor  ebx,ebx
.loc_loop:
        mov  al,[edx]
        or   al,al
        jz   .loc_success

        cmp  al,'>'
        jne  .not_increase
        inc  ebx
        cmp  ebx,BRAINFUCK_MEM_LENGTH
        je   .loc_runtime_error
        inc  edx
        jmp  .loc_loop
.not_increase:
        cmp  al,'<'
        jne  .not_lower
        cmp  ebx,0
        je   .loc_runtime_error
        dec  ebx
        inc  edx
        jmp  .loc_loop
.not_lower:
        cmp  al,'+'
        jne  .not_bigger
        mov  eax,[mem]
        inc  byte [eax+ebx]
        inc  edx
        jmp  .loc_loop
.not_bigger:
        cmp  al,'-'
        jne  .not_decrease
        mov  eax,[mem]
        dec  byte [eax+ebx]
        inc  edx
        jmp  .loc_loop
.not_decrease:
        cmp  al,'.'
        jne  .not_output
        mov  eax,[mem]
        mov  al,[eax+ebx]
        stosb
        inc  edx
        jmp  .loc_loop
.not_output:
        cmp  al,','
        jne  .not_input
        mov  al,byte [esi]
        or   al,al
        jz   @f
        inc  esi
@@:
        mov  ecx,[mem]
        mov  [ecx+ebx],al
        inc  edx
        jmp  .loc_loop
.not_input:
        cmp  al,'['
        jne  .not_cycle_start
        xor  ecx,ecx
        inc  ecx
        mov  eax,[mem]
        cmp  byte [eax+ebx],0
        je   .smth
        inc  edx
        jmp  .loc_loop
.smth:
        inc  edx
        mov  al,[edx]
        cmp  al,'['
        jne  @f
        inc  ecx
@@:
        cmp  al,']'
        jne  .smth
        dec  ecx
        or   ecx,ecx
        jnz  .smth
        inc  edx
        jmp  .loc_loop
.not_cycle_start:
        cmp  al,']'
        jne  .not_cycle_end
        xor  ecx,ecx
        inc  ecx
        mov  eax,[mem]
        cmp  byte [eax+ebx],0
        jne  .not_cycle_start_1
        inc  edx
        jmp  .loc_loop
.not_cycle_start_1:
        dec  edx
        mov  al,[edx]
        cmp  al,']'
        jne  @f
        inc  ecx
@@:
        cmp  al,'['
        jne  .not_cycle_start_1
        dec  ecx
        or   ecx,ecx
        jnz  .not_cycle_start_1
        jmp  .loc_loop
.not_cycle_end:
        inc  edx ; skip instruction
        jmp  .loc_loop

.loc_syntax_error:
        sub  esi,[lpSource]
        mov  edx,esi
        mov  eax,-2
        jmp  .loc_ret

.loc_runtime_error:
        sub  edx,[lpSource]
        inc  edx
        mov  eax,-1
        jmp  .loc_ret

.loc_success:
        xor  eax,eax
.loc_ret:
        push [mem]
        push NULL
        push [hHeap]
        call [HeapFree]
        ret
endp

; MARK: - Import section

section '.idata' import data readable

  library kernel32,'kernel32.dll',\
          user32,'user32.dll',\
          shell32,'shell32.dll',\
          Gdi32, 'Gdi32.dll',\
          Comdlg32 , 'Comdlg32.dll'

  import Gdi32, \
        CreateFont, 'CreateFontA'

  import Comdlg32, \
        GetOpenFileName, 'GetOpenFileNameA', \
        GetSaveFileName, 'GetSaveFileNameA'

  include 'api\kernel32.inc'
  include 'api\user32.inc'
  include 'api\shell32.inc'

; MARK: - Resourse section

section '.rsrc' resource data readable

  directory RT_DIALOG,dialogs

  resource dialogs,42,LANG_ENGLISH+SUBLANG_DEFAULT,demonstration

  dialog demonstration,'azIDE: Brainfuck',0,0,300,225,WS_CAPTION+WS_SYSMENU+DS_CENTER+DS_SYSMODAL
    dialogitem 'STATIC','Source',-1, 5, 2, 185, 13,WS_VISIBLE
    dialogitem 'EDIT','', ID_SOURCE,5,12,290,100,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_MULTILINE+WS_VSCROLL+WS_HSCROLL+ES_WANTRETURN
    dialogitem 'STATIC','Input',-1, 5, 115, 185, 13,WS_VISIBLE
    dialogitem 'EDIT','', ID_INPUT,5,125,290,13,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_AUTOHSCROLL
    dialogitem 'STATIC','Result',-1, 5, 140, 185, 13,WS_VISIBLE
    dialogitem 'EDIT','', ID_RESULT,5,150,290,50,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_MULTILINE+WS_VSCROLL+WS_HSCROLL+ES_READONLY+ES_WANTRETURN
    dialogitem 'BUTTON','Run',ID_RUN,5,205,50,15,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'BUTTON','Clear',ID_CLEAR,85,205,50,15,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'BUTTON','Exit',IDCANCEL,245,205,50,15,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'BUTTON','Open',ID_OPEN,170,205,50,15,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  enddialog
